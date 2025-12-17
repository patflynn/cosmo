# Johnny Walker Setup Guide

This guide details the setup for the `johnny-walker` development environment. 
`johnny-walker` is a virtualized NixOS workstation running on the `classic-laddie` host.

## Architecture

- **Host**: `classic-laddie` (NixOS, KVM/Libvirt enabled)
- **Guest**: `johnny-walker` (NixOS, Standalone Flake Configuration)
- **Hypervisor**: QEMU/KVM via `virsh` (headless)

## Prerequisites

On `classic-laddie`, ensure that `libvirtd` is installed. Note that the service might show as "inactive" or "dead"—this is normal as it uses socket activation and will start automatically when accessed.

## Step 1: Build Disk Image (on WSL2/Dev Machine)

Instead of manually installing from ISO, we build a bootable QCOW2 image directly from the flake on your development machine (e.g., WSL2).

```bash
# Navigate to your cosmo clone on your dev machine
cd ~/hack/cosmo

# Build the image
nix build .#johnny-walker-image

# The result is a symlink 'result'.
```

## Step 2: Transfer Artifacts to classic-laddie (from WSL2/Dev Machine)

We need to copy the image to the host.
**Note**: We copy to your home directory first because `scp` cannot write directly to `/var/lib/libvirt` without root permissions, and `sudo scp` would lose your SSH keys.

```bash
# 1. Copy image to your home directory on classic-laddie
# Replace 'user' with your username (e.g., patrick)
# Note: 'result' is a directory containing the qcow2 file
scp $(readlink -f result)/nixos.qcow2 user@classic-laddie:~/johnny-walker.qcow2

# 2. Move image to the final location (requires sudo on host)
ssh user@classic-laddie "sudo mkdir -p /var/lib/libvirt/images"
ssh user@classic-laddie "sudo mv ~/johnny-walker.qcow2 /var/lib/libvirt/images/"

# 3. Set permissions
ssh user@classic-laddie "sudo chmod 644 /var/lib/libvirt/images/johnny-walker.qcow2"
# Usually owned by root:root on NixOS, which is fine for libvirt
ssh user@classic-laddie "sudo chown root:root /var/lib/libvirt/images/johnny-walker.qcow2"
```

## Step 3: Define and Start VM (on classic-laddie, via SSH)

Define and start the VM on `classic-laddie` using `virsh`. The XML definition is piped from your local machine.

```bash
# Define the VM on classic-laddie (run from your dev machine/WSL2)
# Ensure you are in the cosmo repo directory on your dev machine
cd ~/hack/cosmo
cat hosts/johnny-walker/libvirt-domain.xml | ssh user@classic-laddie "virsh define /dev/stdin"

# Start the VM on classic-laddie (run from your dev machine/WSL2)
ssh user@classic-laddie "virsh start johnny-walker"
```

The VM `johnny-walker` should now be defined and started on your `classic-laddie` host. You can connect to it via SSH (assuming the VM successfully boots and gets an IP on the bridge).

## Post-Install

- Log in as `patrick` (password is set in the config, typically `nixos` or via keys).
- Resize the disk if necessary (the generated image might be small).
    ```bash
    # On Host:
    qemu-img resize /var/lib/libvirt/images/johnny-walker.qcow2 +50G
    
    # In Guest (after reboot):
    # NixOS should auto-expand if configured, or manually expand partition.
    ```
