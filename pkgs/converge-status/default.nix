# The rebuild machinery's status tool: `set` at each transition, `render` /
# `watch` for the bar. See main.go for the schema and render.go for precedence.
#
# fsnotify is the only third-party dependency and it is vendored in-tree
# (vendorHash = null), so a build needs nothing from the network and the whole
# dependency set is reviewable in this repo.
{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "converge-status";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./vendor
      (lib.fileset.fileFilter (f: f.hasExt "go") ./.)
    ];
  };

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Status file authored by cosmo-rebuild, rendered for waybar";
    mainProgram = "converge-status";
  };
}
