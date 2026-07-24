# TEMPORARY forward-pin of claude-code.
#
# cosmo installs claude-code from nixpkgs (see home/dev.nix). Upstream packages
# it as a prebuilt per-platform binary (pkgs/by-name/cl/claude-code): a fetchurl
# of the release binary from downloads.claude.ai, NOT a buildNpmPackage. There
# is therefore no npmDepsHash — just a `version` plus a per-system `src`
# (url + hash). Overriding a version means supplying the version and the matching
# per-platform url + hash ourselves.
#
# As of this pin cosmo's locked nixpkgs ships claude-code 2.1.214 and
# nixpkgs-unstable HEAD is only at 2.1.217, so `nix flake update` cannot reach
# 2.1.219. We forward-pin to 2.1.219 here — the first release carrying the
# claude-opus-5 model id.
#
# REMOVAL CONDITION: delete this overlay once nixpkgs provides
# claude-code >= 2.1.219. The `versionAtLeast` guard below keeps nixpkgs' own
# package whenever it is already at or beyond 2.1.219, so this override can never
# silently DOWNGRADE claude-code once nixpkgs catches up to or surpasses it — but
# the now-dead override should still be removed at that point.
final: prev:
let
  version = "2.1.219";
  baseUrl = "https://downloads.claude.ai/claude-code-releases";

  # nixpkgs system -> claude release platform key + prefetched SRI hash of
  # "${baseUrl}/${version}/${platform}/claude".
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-Is/W9bMGHAORuoTpz4yd6qN3g6rBiwBNQuwGHpjwBpE=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-H4NLMiup0Skcx//v8WpnlaWRRb2iedvVnNfs68e38Vo=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-qOgG+q76xTx6DyZSPYpFxg2+80B7FO+ZDHV2XQj+vII=";
    };
    x86_64-darwin = {
      platform = "darwin-x64";
      hash = "sha256-A76fmI7Yg5G0pfCOTF3DF84v/6Sp3GbAEQYybnaY7nY=";
    };
  };

  inherit (prev.stdenv.hostPlatform) system;
  entry = sources.${system} or (throw "claude-code forward-pin: unsupported system ${system}");
in
{
  claude-code =
    # Never downgrade: if nixpkgs is already at or ahead of the pin, keep its
    # build untouched (see REMOVAL CONDITION above).
    if prev.lib.versionAtLeast prev.claude-code.version version then
      prev.claude-code
    else
      prev.claude-code.overrideAttrs (_: {
        inherit version;
        src = prev.fetchurl {
          url = "${baseUrl}/${version}/${entry.platform}/claude";
          inherit (entry) hash;
        };
      });
}
