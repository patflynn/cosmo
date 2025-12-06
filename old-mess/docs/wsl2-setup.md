# NixOS on WSL2 Setup Guide

This guide provides step-by-step instructions for setting up NixOS on Windows Subsystem for Linux 2 (WSL2).

## Prerequisites

1. Windows 10 version 2004 or higher / Windows 11
2. WSL2 installed and enabled
3. At least 8GB of RAM recommended
4. At least 60GB of free disk space

## Step 1: Install WSL2 on Windows

If you haven't already installed WSL2, open PowerShell as Administrator and run:

```powershell
wsl --install
```

This will install Ubuntu as the default distribution. We'll replace this with NixOS.

## Step 2: Download NixOS-WSL

1. Download the latest NixOS-WSL tarball from the official repository:
   https://github.com/nix-community/NixOS-WSL/releases

2. Create a directory for NixOS:
   ```powershell
   mkdir C:\NixOS
   ```

3. Import the tarball into WSL:
   ```powershell
   wsl --import NixOS C:\NixOS path\to\nixos-wsl.tar.gz --version 2
   ```

## Step 3: Start NixOS

Launch NixOS from PowerShell:

```powershell
wsl -d NixOS
```

You should now have a root shell in NixOS.

## Step 4: Set Up User Account

1. Create a new user (replace `username` with your desired username):
   ```bash
   nix-shell -p cryptsetup
   useradd -m -G wheel -s /bin/sh username
   passwd username
   ```

2. Edit the sudoers file to allow the wheel group to use sudo:
   ```bash
   visudo
   ```
   Uncomment the line: `%wheel ALL=(ALL) ALL`

## Step 5: Clone and Configure Cosmo

1. Install Git:
   ```bash
   nix-env -iA nixpkgs.git
   ```

2. Clone the repository (as your user, not root):
   ```bash
   su - username
   mkdir -p ~/hack
   cd ~/hack
   git clone https://github.com/patflynn/cosmo.git
   cd cosmo
   ```

3. Modify the username in the WSL2 configuration file if needed:
   ```bash
   # Edit modules/hosts/wsl2/default.nix to change the defaultUser
   # from "patrick" to your username
   ```

## Step 6: Apply NixOS Configuration

1. Build and switch to the new configuration:
   ```bash
   sudo nixos-rebuild switch --flake ~/hack/cosmo#wsl2
   ```

2. Reboot NixOS WSL (from PowerShell):
   ```powershell
   wsl --shutdown NixOS
   wsl -d NixOS
   ```

## Step 7: Verify Installation

1. Check NixOS version:
   ```bash
   nixos-version
   ```

2. Verify that home-manager configurations are applied:
   ```bash
   ls -la ~/.config
   ```

## Advanced Configuration

### Graphics Support (X11)

The default configuration disables X11 services since they're typically not needed in WSL. If you need GUI applications:

1. Install an X server on Windows, such as [VcXsrv](https://sourceforge.net/projects/vcxsrv/).

2. Enable X11 forwarding by modifying the WSL2 configuration:
   ```nix
   # In modules/hosts/wsl2/default.nix
   services.xserver = {
     enable = true;
     displayManager.startx.enable = true;
   };
   ```

3. Add to your .bashrc or .zshrc:
   ```bash
   export DISPLAY=$(grep -m 1 nameserver /etc/resolv.conf | awk '{print $2}'):0
   ```

### Windows Integration

1. File system access:
   - Windows drives are mounted at `/mnt/c`, `/mnt/d`, etc.
   - Create symlinks to frequently used Windows locations:
     ```bash
     ln -sf /mnt/c/Users/YourWindowsUser/Documents ~/win-documents
     ```

2. Windows PATH integration:
   - Already enabled in the configuration with `interop.appendWindowsPath = true;`
   - You can call Windows executables like `notepad.exe`

### Troubleshooting

1. **Networking issues**: If you have connectivity problems:
   ```bash
   sudo ip addr show
   sudo ip route show
   ```

2. **Memory/performance issues**: WSL2 by default may use too much memory. Create a `.wslconfig` file in your Windows user directory:
   ```
   [wsl2]
   memory=4GB
   processors=4
   ```

3. **File permission issues**: WSL and Windows handle permissions differently. Use:
   ```bash
   sudo chmod -R 755 /path/to/directory
   ```

## Updating NixOS

Regular updates can be performed with:

```bash
sudo nixos-rebuild switch --flake ~/hack/cosmo#wsl2 --upgrade
```

## Uninstalling

If you need to remove the NixOS WSL distribution:

```powershell
wsl --unregister NixOS
rmdir C:\NixOS
```