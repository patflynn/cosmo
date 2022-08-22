{ config, ... }:

{
  baseDir = "${config.home.homeDirectory}/hack";
  repos."cosmo" = {
    url = "git@github.com/patflynn/cosmo.git";
  };
  repos."sigstore-java" = {
    url = "git@github.com/sigstore/sigstore-java.git";
   #shell = ./java.nix
  }
  repos."fulcio" = { url = "git@github.com:sigstore/fulcio.git"; };
  repos."rekor" = { url = "git@github.com:sigstore/rekor.git"; };
  repos."sigstore" = { url = "git@github.com:sigstore/sigstore.git"; };
  repos."cosign" = { url = "git@github.com:sigstore/cosign.git"; };
  repos."go-tuf" = { url = "git@github.com:theupdateframework/go-tuf.git"; };
}
