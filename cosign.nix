{ lib,  buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "cosign";
  version = "1.11.1";

  src = fetchFromGitHub {
    owner = "sigstore";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-LKnv/+6R/RaVdRYYdp+EqVQZtUn8SnYLCr5rqgGrq68=";
  };

  vendorSha256 = "sha256-ao1WI8M3T/oSxYM0OrW1L3/JQf9S2C7AzE4HA6VIx5w=";
}
