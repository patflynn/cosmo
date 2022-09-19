{ lib,  buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "go-tuf";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "theupdateframework";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-x/nb4D6U25JNDw6AII/fCpMT6hlFwBX2aZla23zFUoY="; # calculated using lib.fakeSha256
  };

  vendorSha256 = "sha256-eIYkwVEtKo2gbXOofGfO+ptNMujn6ROBlPlBBwV1ojw=";

}
