let
  # User Keys
  patrick = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc8u2oEFD+sn9vmX0gEbf62V4fmHGSvu10ENPkci3Yd" # makers-mark.ubuntu
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8B2eVhu/TpXZPyOt/6w0ELdtO6X6cTiWz3CvofxDCR" # makers-mark.nixos
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHo0Oc728AfV2EMn30DhTWSqdWhmY8xR6np/qf6U7xvn" # cloud-ssh (Chrome)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCxVUxXoyFYV40QureqqSMSA17CvK9IrFB33BA6UOip" # classic-laddie
  ];

  # Git-only keys. These reach valley git hosting and nothing else: they are
  # deliberately NOT agenix recipients (see secrets.nix, which encrypts to
  # `users ++ hosts`) and NOT shell users (see modules/common/users.nix).
  # Add a key here when it belongs to a scratch or agent machine that should
  # be able to clone and push projects without being able to decrypt any
  # secret. Removing a key here revokes that access with no re-encryption.
  gitOnly = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvpmbUKEDVsejgv2vxWaY/t4xl0JNnjFswb9SxcG9GG" # stoned-flynn (exe.dev the-valley playground)
  ];

  # Host Keys
  classic-laddie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE7/mipW9wcQwVlDmEqBZksGDO3BEG94gb6VBuyDJUgk";
  weller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICaAqTE1kznlevOxLH6QuiMHI9UUKQj+OMIp2wkLWA0K";
  johnny-walker = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALgjAYCsxF4HUoW9MmsrShmV45Y1ClM37Z7jXY4Fw+G";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICm/0RSHq33ws9IIlzJyXhL0Gh1eudUE3LZEMUOa6PHX";
  klaus-worker-0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxasgwj3CMigHPUCZ6QmnPrWbmonBKbrWq5gwofqPx/";
in
{
  users = patrick;

  inherit gitOnly;

  hosts = [
    classic-laddie
    weller
    johnny-walker
    wsl
    klaus-worker-0
  ];
}
