{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.media-server;
  rcfg = cfg.recyclarr;

  recyclarrConfig = ./recyclarr.yml;

  syncScript = pkgs.writeShellScript "media-stack-sync" ''
    set -euo pipefail

    # Secrets may be KEY=VALUE (for EnvironmentFile) or raw values; strip prefix if present
    SONARR_API_KEY=$(sed 's/^SONARR_API_KEY=//' "${rcfg.sonarrApiKeyPath}")
    RADARR_API_KEY=$(sed 's/^RADARR_API_KEY=//' "${rcfg.radarrApiKeyPath}")
    PROWLARR_API_KEY=$(sed 's/^PROWLARR_API_KEY=//' "${rcfg.prowlarrApiKeyPath}")

    SONARR_URL="http://localhost:8989"
    RADARR_URL="http://localhost:7878"
    PROWLARR_URL="http://localhost:9696"

    STATE_DIR="/var/lib/recyclarr"

    curl="${pkgs.curl}/bin/curl"
    jq="${pkgs.jq}/bin/jq"

    # Wait for a service API to become responsive
    wait_for_api() {
      local url="$1" api_key="$2" name="$3"
      local attempt=0 max=30

      # Sonarr/Radarr use /api/v3, Prowlarr uses /api/v1
      while [ $attempt -lt $max ]; do
        if $curl -sf "$url/api/v3/system/status" -H "X-Api-Key: $api_key" > /dev/null 2>&1 ||
           $curl -sf "$url/api/v1/system/status" -H "X-Api-Key: $api_key" > /dev/null 2>&1; then
          echo "$name is ready."
          return 0
        fi
        attempt=$((attempt + 1))
        echo "Waiting for $name... ($attempt/$max)"
        sleep 5
      done
      echo "WARNING: $name did not become ready in time, skipping."
      return 1
    }

    wait_for_api "$SONARR_URL" "$SONARR_API_KEY" "Sonarr"
    wait_for_api "$RADARR_URL" "$RADARR_API_KEY" "Radarr"
    wait_for_api "$PROWLARR_URL" "$PROWLARR_API_KEY" "Prowlarr"

    # ---------------------------------------------------------------
    # 1. Recyclarr sync (TRaSH Guides custom formats & quality defs)
    # ---------------------------------------------------------------
    echo "=== Running Recyclarr sync ==="

    printf 'sonarr_api_key: %s\nradarr_api_key: %s\n' \
      "$SONARR_API_KEY" "$RADARR_API_KEY" > "$STATE_DIR/secrets.yml"
    chmod 600 "$STATE_DIR/secrets.yml"

    cp ${recyclarrConfig} "$STATE_DIR/recyclarr.yml"

    ${pkgs.recyclarr}/bin/recyclarr sync \
      --config "$STATE_DIR/recyclarr.yml" \
      --app-data "$STATE_DIR" || echo "WARNING: Recyclarr sync had errors (non-fatal)"

    # ---------------------------------------------------------------
    # 2. VVC/H.266 rejection custom format (not in TRaSH Guides for Sonarr)
    # ---------------------------------------------------------------
    echo "=== Ensuring VVC/H.266 rejection custom format ==="

    ensure_vvc_custom_format() {
      local url="$1" api_key="$2" name="$3" api_ver="$4"

      local vvc_count
      vvc_count=$($curl -sf "$url/api/$api_ver/customformat" \
        -H "X-Api-Key: $api_key" | \
        $jq '[.[] | select(.name == "Reject VVC/H.266")] | length')

      if [ "$vvc_count" != "0" ]; then
        echo "VVC/H.266 rejection already exists in $name."
        return 0
      fi

      echo "Creating VVC/H.266 rejection custom format in $name..."
      local cf_id
      cf_id=$($curl -sf -X POST "$url/api/$api_ver/customformat" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Reject VVC/H.266",
          "includeCustomFormatWhenRenaming": false,
          "specifications": [{
            "name": "VVC/H.266 Codec",
            "implementation": "ReleaseTitleSpecification",
            "negate": false,
            "required": false,
            "fields": [{"name": "value", "value": "\\b(vvc|[hx][. ]?266)\\b"}]
          }]
        }' | $jq '.id')

      # Assign -10000 score to every quality profile so it is rejected everywhere
      $curl -sf "$url/api/$api_ver/qualityprofile" \
        -H "X-Api-Key: $api_key" | \
        $jq -c '.[]' | while IFS= read -r profile; do
          local pid
          pid=$(echo "$profile" | $jq '.id')
          local updated
          updated=$(echo "$profile" | $jq --argjson cf_id "$cf_id" \
            '.formatItems += [{"format": $cf_id, "name": "Reject VVC/H.266", "score": -10000}]')
          $curl -sf -X PUT "$url/api/$api_ver/qualityprofile/$pid" \
            -H "X-Api-Key: $api_key" \
            -H "Content-Type: application/json" \
            -d "$updated" > /dev/null
          echo "  Assigned VVC rejection (score -10000) to profile $pid in $name"
        done
    }

    ensure_vvc_custom_format "$SONARR_URL" "$SONARR_API_KEY" "Sonarr" "v3"
    ensure_vvc_custom_format "$RADARR_URL" "$RADARR_API_KEY" "Radarr" "v3"

    # ---------------------------------------------------------------
    # 3. Dubbed release rejection custom format
    # ---------------------------------------------------------------
    # Rejects dubbed releases (e.g. German.DL.1080p) without filtering out
    # original-language foreign films. Two specs (OR logic):
    #   - \b(DUBBED|DUB)\b     — explicit dub tags
    #   - \b\w+\.DL\b          — scene 'Language.DL' (Dual Language) convention
    echo "=== Ensuring dubbed release rejection custom format ==="

    ensure_dubbed_custom_format() {
      local url="$1" api_key="$2" name="$3" api_ver="$4"
      local cf_name="Reject Dubbed Releases"

      local existing_count
      existing_count=$($curl -sf "$url/api/$api_ver/customformat" \
        -H "X-Api-Key: $api_key" | \
        $jq --arg n "$cf_name" '[.[] | select(.name == $n)] | length')

      if [ "$existing_count" != "0" ]; then
        echo "Dubbed release rejection already exists in $name."
        return 0
      fi

      echo "Creating dubbed release rejection custom format in $name..."
      local cf_id
      local json_payload
      json_payload=$(printf '{
          "name": "%s",
          "includeCustomFormatWhenRenaming": false,
          "specifications": [
            {
              "name": "DUBBED/DUB tag",
              "implementation": "ReleaseTitleSpecification",
              "negate": false,
              "required": false,
              "fields": [{"name": "value", "value": "\\b(DUBBED|DUB)\\b"}]
            },
            {
              "name": "Language.DL (Dual Language)",
              "implementation": "ReleaseTitleSpecification",
              "negate": false,
              "required": false,
              "fields": [{"name": "value", "value": "\\b\\w+\\.DL\\b"}]
            }
          ]
        }' "$cf_name")
      cf_id=$($curl -sf -X POST "$url/api/$api_ver/customformat" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload" | $jq '.id')

      # Assign -10000 score to every quality profile so it is rejected everywhere
      $curl -sf "$url/api/$api_ver/qualityprofile" \
        -H "X-Api-Key: $api_key" | \
        $jq -c '.[]' | while IFS= read -r profile; do
          local pid
          pid=$(echo "$profile" | $jq '.id')
          local updated
          updated=$(echo "$profile" | $jq --argjson cf_id "$cf_id" --arg cf_name "$cf_name" \
            '.formatItems += [{"format": $cf_id, "name": $cf_name, "score": -10000}]')
          $curl -sf -X PUT "$url/api/$api_ver/qualityprofile/$pid" \
            -H "X-Api-Key: $api_key" \
            -H "Content-Type: application/json" \
            -d "$updated" > /dev/null
          echo "  Assigned dubbed rejection (score -10000) to profile $pid in $name"
        done
    }

    ensure_dubbed_custom_format "$SONARR_URL" "$SONARR_API_KEY" "Sonarr" "v3"
    ensure_dubbed_custom_format "$RADARR_URL" "$RADARR_API_KEY" "Radarr" "v3"

    # ---------------------------------------------------------------
    # 4. Prowlarr application connections
    # ---------------------------------------------------------------
    echo "=== Configuring Prowlarr connections ==="

    PROWLARR_APPS=$($curl -sf "$PROWLARR_URL/api/v1/applications" \
      -H "X-Api-Key: $PROWLARR_API_KEY")

    # Sonarr connection
    if [ "$(echo "$PROWLARR_APPS" | $jq '[.[] | select(.name == "Sonarr")] | length')" = "0" ]; then
      echo "Adding Sonarr connection to Prowlarr..."
      $curl -sf -X POST "$PROWLARR_URL/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"syncLevel\": \"addOnly\",
          \"name\": \"Sonarr\",
          \"implementation\": \"Sonarr\",
          \"configContract\": \"SonarrSettings\",
          \"fields\": [
            {\"name\": \"prowlarrUrl\", \"value\": \"http://localhost:9696\"},
            {\"name\": \"baseUrl\", \"value\": \"http://localhost:8989\"},
            {\"name\": \"apiKey\", \"value\": \"$SONARR_API_KEY\"},
            {\"name\": \"syncCategories\", \"value\": [5000, 5010, 5020, 5030, 5040, 5045, 5050]}
          ],
          \"tags\": []
        }" > /dev/null
      echo "Sonarr connection added."
    else
      echo "Sonarr connection already exists in Prowlarr."
    fi

    # Radarr connection
    if [ "$(echo "$PROWLARR_APPS" | $jq '[.[] | select(.name == "Radarr")] | length')" = "0" ]; then
      echo "Adding Radarr connection to Prowlarr..."
      $curl -sf -X POST "$PROWLARR_URL/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"syncLevel\": \"addOnly\",
          \"name\": \"Radarr\",
          \"implementation\": \"Radarr\",
          \"configContract\": \"RadarrSettings\",
          \"fields\": [
            {\"name\": \"prowlarrUrl\", \"value\": \"http://localhost:9696\"},
            {\"name\": \"baseUrl\", \"value\": \"http://localhost:7878\"},
            {\"name\": \"apiKey\", \"value\": \"$RADARR_API_KEY\"},
            {\"name\": \"syncCategories\", \"value\": [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]}
          ],
          \"tags\": []
        }" > /dev/null
      echo "Radarr connection added."
    else
      echo "Radarr connection already exists in Prowlarr."
    fi

    echo "=== Media stack sync complete ==="
  '';
in
{
  options.modules.media-server.recyclarr = {
    enable = lib.mkEnableOption "Recyclarr declarative media stack config sync";

    sonarrApiKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/sonarr-api-key";
      description = "Path to the agenix-decrypted file containing Sonarr's API key";
    };

    radarrApiKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/radarr-api-key";
      description = "Path to the agenix-decrypted file containing Radarr's API key";
    };

    prowlarrApiKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/prowlarr-api-key";
      description = "Path to the agenix-decrypted file containing Prowlarr's API key";
    };
  };

  config = lib.mkIf (cfg.enable && rcfg.enable) {
    systemd.services.media-stack-sync = {
      description = "Sync media stack configuration (Recyclarr + VVC/dubbed rejection + Prowlarr connections)";
      after = [
        "network-online.target"
        "sonarr.service"
        "radarr.service"
        "prowlarr.service"
      ];
      wants = [
        "network-online.target"
        "sonarr.service"
        "radarr.service"
        "prowlarr.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "recyclarr";
        ExecStart = syncScript;
        TimeoutStartSec = "10m";
      };
    };

    systemd.timers.media-stack-sync = {
      description = "Periodic media stack configuration sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
