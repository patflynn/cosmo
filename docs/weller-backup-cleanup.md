# Weller Backup Cleanup Instructions

**Created:** 2026-02-08
**Purpose:** Instructions for cleaning up the temporary backup after weller (NixOS) installation is complete.

## Context

Before installing NixOS on the Seagate FireCuda drive (Disk 1 / D:), the contents were backed up to classic-laddie. This backup should be deleted once:

1. NixOS (weller) is successfully installed and booting
2. Important data has been restored to the new system
3. User confirms the backup is no longer needed

## Backup Location

- **Host:** classic-laddie
- **Path:** `/mnt/personal/weller-backup/`
- **ZFS Dataset:** `tank/personal` (backup is a directory, not a child dataset)
- **Size:** ~917 GB

## Backup Contents

| Folder | Size | Restore Priority |
|--------|------|------------------|
| genes | 142 GB | **Critical** - genealogy data, must be restored |
| iracing cars tracks backup | 73 GB | **Important** - custom content |
| mb_bios_x570-aorus-pro_f35d | 0.02 GB | **Keep** - BIOS backup |
| SteamLibrary | 458 GB | Optional - can re-download |
| Epic Games | 141 GB | Optional - can re-download |
| star citizen | 103 GB | Optional - can re-download |

## Pre-Cleanup Checklist

Before deleting the backup, verify:

- [ ] NixOS (weller) boots successfully
- [ ] `/home/patrick/genes/` exists and contains genealogy data
- [ ] iRacing custom content has been restored
- [ ] BIOS backup has been copied somewhere permanent
- [ ] User has explicitly confirmed cleanup is OK

## Cleanup Commands

```bash
# SSH to classic-laddie
ssh classic-laddie

# Verify backup size before deletion
du -sh /mnt/personal/weller-backup/

# List contents one more time
ls -la /mnt/personal/weller-backup/

# Delete the backup (requires sudo)
sudo rm -rf /mnt/personal/weller-backup/

# Verify deletion
ls -la /mnt/personal/
```

## Verification

After cleanup, confirm disk space was reclaimed:

```bash
ssh classic-laddie "zfs list tank/personal"
```

The AVAIL column should show increased space (roughly +917GB).

## Notes

- This backup was created on 2026-02-08 during the weller dual-boot setup
- The backup log is at `/tmp/weller-backup.log` on makers-nix (WSL) but will be lost on reboot
- If unsure whether to delete, ask the user first
