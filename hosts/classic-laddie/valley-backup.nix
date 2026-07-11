# Offsite restic backup of the valley git hosting data (the-valley outcome
# oc-9949561, mechanism (c) of decision dcr-db1acbb): nightly encrypted,
# deduplicated backups of the bare-repo directory to a Hetzner Storage Box
# over sftp.
#
# DISABLED BY DEFAULT: enable after the Hetzner Storage Box is provisioned;
# see dcr-db1acbb. Before flipping cosmo.valley.backup.enable to true:
#
#   1. Provision the Storage Box and enable its SSH/sftp access.
#   2. Authorize the valley mirror key on the box (append the PUBLIC half of
#      valley-git-ssh-key to the box's authorized_keys — the backup reuses
#      that identity for sftp).
#   3. Populate the secrets:
#        cd secrets && agenix -e valley-restic-repo.age
#          # single line, the restic repository URL, e.g.:
#          # sftp://u123456@u123456.your-storagebox.de:23//./backups/valley
#        cd secrets && agenix -e valley-restic-password.age
#          # single line, the restic repository encryption password
#          # (generate one and store it in the password manager — losing it
#          # loses the backups)
#   4. Pin the Storage Box host key (from Hetzner's published fingerprints,
#      not a blind ssh-keyscan) into the known-hosts file read below:
#        printf '%s\n' '[u123456.your-storagebox.de]:23 ssh-ed25519 AAAA...' \
#          | sudo tee /var/lib/valley-backup/known_hosts
#
# A restore must be performed and verified before oc-9949561 can close —
# configured is not done.
{
  config,
  lib,
  ...
}:

let
  cfg = config.cosmo.valley.backup;
in
{
  options.cosmo.valley.backup = {
    enable = lib.mkEnableOption "nightly restic backup of the valley git data to the Hetzner Storage Box";
  };

  config = lib.mkIf cfg.enable {
    age.secrets."valley-restic-repo" = {
      file = ../../secrets/valley-restic-repo.age;
      mode = "0400";
    };
    age.secrets."valley-restic-password" = {
      file = ../../secrets/valley-restic-password.age;
      mode = "0400";
    };

    # Holds the pinned Storage Box host key (step 4 above).
    systemd.tmpfiles.rules = [
      "d /var/lib/valley-backup 0700 root root - -"
    ];

    services.restic.backups.valley = {
      initialize = true;
      repositoryFile = config.age.secrets."valley-restic-repo".path;
      passwordFile = config.age.secrets."valley-restic-password".path;
      paths = [ config.services.valley.dataDir ];
      # The service runs as root; authenticate to the box with the valley
      # mirror identity and only the pinned host key.
      extraOptions = [
        "sftp.args='-i ${
          config.age.secrets."valley-git-ssh-key".path
        } -o UserKnownHostsFile=/var/lib/valley-backup/known_hosts -o IdentitiesOnly=yes'"
      ];
      timerConfig = {
        OnCalendar = "03:30";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };
  };
}
