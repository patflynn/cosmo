# Copied from original gitsign.nix
{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gitsign";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "sigstore";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Q8sYH4h8/pTQ6RKhsQykYoQd6T4osqrC4/vTIxUYoBM=";
  };

  vendorSha256 = "sha256-3LZ0mRVZpxjCd8a4kXinnaQA4c+jEbnRIHmOeqo/+9k=";

  # subPackages = [
  #   "cmd/gitsign-credential-cache"
  # ];
}