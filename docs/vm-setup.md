# Generic VM Setup Guide

This guide details the process for deploying a NixOS virtual machine (VM) from this repository onto a KVM/Libvirt host (e.g., `classic-laddie`).

## Architecture

- **Host**: A NixOS machine with KVM/Libvirt enabled (e.g., `classic-laddie`).
- **Guest**: A virtualized NixOS system defined in `hosts/<vm-name>`.
- **Method**: We build a QCOW2 image locally (using `nixos-generators`) and push it to the host.

## Prerequisites

1.  **Target Host**: Ensure `libvirtd` is installed and running on the target host.
2.  **Dev Machine**: You need a machine with Nix enabled (e.g., WSL2, MacOS with Nix) to build the image.
3.  **SSH Access**: You must have SSH access to the target host.

## Step 1: Define the VM

Ensure your VM is defined in `flake.nix` under `nixosConfigurations` and has a corresponding image generator output.

**Example `flake.nix`:**
```nix
{
  outputs = { self, nixpkgs, nixos-generators, ... }: {
    # System Configuration
    nixosConfigurations.my-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/my-vm/default.nix ];
    };

    # Image Generator
    packages.x86_64-linux.my-vm-image = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./hosts/my-vm/default.nix ];
      format = "qcow";
    };
  };
}
```

## Step 2: Build Disk Image (Locally)

Build the bootable QCOW2 image directly from the flake on your development machine.

```bash
# Navigate to your cosmo clone
cd ~/hack/cosmo

# Build the image (replace 'my-vm-image' with your target)
nix build .#my-vm-image

# The result is a symlink 'result' containing the image.
```

## Step 3: Transfer to Host

We need to copy the image to the host.
**Note**: We copy to your home directory first because `scp` cannot write directly to `/var/lib/libvirt` without root permissions.

```bash
export VM_NAME="my-vm"
export TARGET_HOST="classic-laddie"

# 1. Copy image to your home directory on the host
scp $(readlink -f result)/nixos.qcow2 user@${TARGET_HOST}:~/${VM_NAME}.qcow2

# 2. Move image to the final location (requires sudo on host)
ssh user@${TARGET_HOST} "sudo mkdir -p /var/lib/libvirt/images"
ssh user@${TARGET_HOST} "sudo mv ~/${VM_NAME}.qcow2 /var/lib/libvirt/images/"

# 3. Set permissions
ssh user@${TARGET_HOST} "sudo chmod 644 /var/lib/libvirt/images/${VM_NAME}.qcow2"
ssh user@${TARGET_HOST} "sudo chown root:root /var/lib/libvirt/images/${VM_NAME}.qcow2"
```

## Step 4: Define and Start VM

You need a generic Libvirt XML definition for the VM. A sample is provided in `hosts/johnny-walker/libvirt-domain.xml`, but you should adapt it (UUID, Memory, CPU, MAC address).

```bash
# Define the VM on the host
# Ensure you have a 'libvirt-domain.xml' ready for your VM
cat hosts/${VM_NAME}/libvirt-domain.xml | ssh user@${TARGET_HOST} "virsh -c qemu:///system define /dev/stdin"

# Start the VM
ssh user@${TARGET_HOST} "virsh -c qemu:///system start ${VM_NAME}"
```

## Post-Install

- **Resize Disk**: The generated image is minimal.
    ```bash
    # On Host:
    ssh user@${TARGET_HOST} "sudo qemu-img resize /var/lib/libvirt/images/${VM_NAME}.qcow2 +50G"
    ```
- **Connect**: 
    - Use `virt-manager` (if you have GUI access to host).
    - Or SSH into the VM if networking is configured (check your router/DHCP).