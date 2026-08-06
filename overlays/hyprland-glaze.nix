# TEMPORARY build fix for hyprland.
#
# The locked nixpkgs (nixos-unstable e72e4f2) bumped glaze 7.9.1 -> 8.0.0
# without the companion hyprland fix, so hyprland's
# `find_package(glaze 7...<8)` misses and CMake falls back to a network
# FetchContent that cannot work in the sandbox ("could not find git for clone
# of glaze", nixpkgs issue #549246). Upstream fixed this on master in commit
# e0832b87 ("hyprland: fix build by relaxing glaze dependency") by relaxing
# the version range in postPatch; this overlay replicates that exact change.
#
# REMOVAL CONDITION: delete this overlay once the locked nixpkgs contains
# e0832b87. Verify with
#   git -C <nixpkgs> merge-base --is-ancestor e0832b87 <locked rev>
# or simply: nixpkgs' hyprland postPatch already mentions glaze. The guard
# below keeps nixpkgs' own package untouched in that case, so a stale overlay
# cannot re-break the build — but remove the dead code anyway.
final: prev: {
  hyprland =
    # No-op once nixpkgs' own postPatch handles glaze (see REMOVAL CONDITION).
    if prev.lib.hasInfix "glaze" (prev.hyprland.postPatch or "") then
      prev.hyprland
    else
      prev.hyprland.overrideAttrs (old: {
        postPatch = ''
          # Relax glaze dependency (nixpkgs e0832b87)
          substituteInPlace CMakeLists.txt start/CMakeLists.txt hyprpm/CMakeLists.txt \
            --replace-fail "glaze 7...<8" "glaze"
        ''
        + (old.postPatch or "");
      });
}
