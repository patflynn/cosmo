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

    SONARR_API_KEY=$(cat "${rcfg.sonarrApiKeyPath}")
    RADARR_API_KEY=$(cat "${rcfg.radarrApiKeyPath}")
    PROWLARR_API_KEY=$(cat "${rcfg.prowlarrApiKeyPath}")

    SONARR_URL="http://localhost:8989"
    RADARR_URL="http://localhost:7878"
    PROWLARR_URL="http://localhost:9696"

    STATE_DIR="/var/lib/recyclarr"

    curl="${pkgs.curl}/bin/curl"
    jq="${pkgs.jq}/bin/jq"

    # Helper: call curl with API key passed via stdin (avoids leaking key in /proc/cmdline)
    curl_api() {
      local api_key="$1"; shift
      printf 'header = "X-Api-Key: %s"\n' "$api_key" | $curl -sf -K - "$@"
    }

    # Wait for a service API to become responsive
    wait_for_api() {
      local url="$1" api_key="$2" name="$3"
      local attempt=0 max=30

      # Sonarr/Radarr use /api/v3, Prowlarr uses /api/v1
      while [ $attempt -lt $max ]; do
        if curl_api "$api_key" "$url/api/v3/system/status" > /dev/null 2>&1 ||
           curl_api "$api_key" "$url/api/v1/system/status" > /dev/null 2>&1; then
          echo "$name is ready."
          return 0
        fi
        attempt=$((attempt + 1))
        echo "Waiting for $name... ($attempt/$max)"
        sleep 5
      done
      echo "ERROR: $name did not become ready in time. Exiting."
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

    cp "${recyclarrConfig}" "$STATE_DIR/recyclarr.yml"

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
      vvc_count=$(curl_api "$api_key" "$url/api/$api_ver/customformat" | \
        $jq '[.[] | select(.name == "Reject VVC/H.266")] | length')

      if [ "$vvc_count" != "0" ]; then
        echo "VVC/H.266 rejection already exists in $name."
        return 0
      fi

      echo "Creating VVC/H.266 rejection custom format in $name..."
      local cf_id
      cf_id=$(curl_api "$api_key" -X POST "$url/api/$api_ver/customformat" \
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
      curl_api "$api_key" "$url/api/$api_ver/qualityprofile" | \
        $jq -c '.[]' | while IFS= read -r profile; do
          local pid
          pid=$(echo "$profile" | $jq '.id')
          local updated
          updated=$(echo "$profile" | $jq --argjson cf_id "$cf_id" \
            '.formatItems += [{"format": $cf_id, "name": "Reject VVC/H.266", "score": -10000}]')
          curl_api "$api_key" -X PUT "$url/api/$api_ver/qualityprofile/$pid" \
            -H "Content-Type: application/json" \
            -d "$updated" > /dev/null
          echo "  Assigned VVC rejection (score -10000) to profile $pid in $name"
        done
    }

    ensure_vvc_custom_format "$SONARR_URL" "$SONARR_API_KEY" "Sonarr" "v3"

    # ---------------------------------------------------------------
    # 3. Prowlarr application connections
    # ---------------------------------------------------------------
    echo "=== Configuring Prowlarr connections ==="

    PROWLARR_APPS=$(curl_api "$PROWLARR_API_KEY" "$PROWLARR_URL/api/v1/applications")

    # Helper: add a Prowlarr application connection if it doesn't already exist
    add_prowlarr_connection() {
      local app_name="$1" impl="$2" contract="$3" base_url="$4" api_key="$5"
      local categories="$6"  # JSON array string, e.g. "[5000,5010]"

      if [ "$(echo "$PROWLARR_APPS" | $jq --arg n "$app_name" '[.[] | select(.name == $n)] | length')" != "0" ]; then
        echo "$app_name connection already exists in Prowlarr."
        return 0
      fi

      echo "Adding $app_name connection to Prowlarr..."
      local payload
      payload=$($jq -n \
        --arg name "$app_name" \
        --arg impl "$impl" \
        --arg contract "$contract" \
        --arg prowlarr_url "http://localhost:9696" \
        --arg base_url "$base_url" \
        --arg api_key "$api_key" \
        --argjson categories "$categories" \
        '{
          syncLevel: "addOnly",
          name: $name,
          implementation: $impl,
          configContract: $contract,
          fields: [
            {name: "prowlarrUrl", value: $prowlarr_url},
            {name: "baseUrl", value: $base_url},
            {name: "apiKey", value: $api_key},
            {name: "syncCategories", value: $categories}
          ],
          tags: []
        }')

      curl_api "$PROWLARR_API_KEY" -X POST "$PROWLARR_URL/api/v1/applications" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null
      echo "$app_name connection added."
    }

    add_prowlarr_connection "Sonarr" "Sonarr" "SonarrSettings" \
      "http://localhost:8989" "$SONARR_API_KEY" "[5000,5010,5020,5030,5040,5045,5050]"

    add_prowlarr_connection "Radarr" "Radarr" "RadarrSettings" \
      "http://localhost:7878" "$RADARR_API_KEY" "[2000,2010,2020,2030,2040,2045,2050,2060]"

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
      description = "Sync media stack configuration (Recyclarr + VVC rejection + Prowlarr connections)";
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
