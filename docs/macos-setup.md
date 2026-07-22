# macOS Workstation Setup Guide

This guide describes how to install and bootstrap your Home Manager developer profile on macOS (`aarch64-darwin`) using the standalone target `"paflynn@paflynn-mac"`.

---

## 1. Install Nix

The recommended way to install Nix on macOS is using the **Determinate Systems Nix Installer**, which is secure, fast, and handles macOS-specific details (like APFS volumes) perfectly.

Open a terminal and run:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

After installation, restart your terminal or source your shell environment to make the `nix` command available.

---

## 2. Verify Flakes & Nix Commands

Ensure experimental Nix features are enabled (the Determinate Systems installer does this by default). Verify by checking that `~/.config/nix/nix.conf` or `/etc/nix/nix.conf` contains:

```text
experimental-features = nix-command flakes
```

---

## 3. Bootstrap Home Manager

Once Nix is installed, you can apply your `cosmo` configuration directly.

If you are inside your local clone of the `cosmo` repository, run:

```bash
nix run home-manager -- switch --flake '.#paflynn@paflynn-mac'
```

Alternatively, if you haven't cloned `cosmo` yet or want to rebuild directly from your remote repository:

```bash
nix run home-manager -- switch --flake 'github:patflynn/cosmo#paflynn@paflynn-mac'
```

---

## 4. Direnv & Zsh Integration

Since the configuration enables Zsh and Direnv, make sure your terminal uses Zsh as the default shell (macOS default).

The flake configures Zsh with modern ergonomics, Git aliases, and integration with `direnv`. To hook `direnv` into your environment, add the following to the end of your shell initialization if it's not loaded automatically:

```bash
eval "$(direnv hook zsh)"
```

Then reload your shell:

```bash
exec zsh
```

---

## 5. Daily Auto-Upgrade

Since your profile uses the **work identity** (`work.nix`), **automatic daily updates are enabled by default**.

Home Manager on macOS will configure a native **Launchd Agent** (`org.nix-community.home-manager.cosmo-home-autoupgrade` / `cosmo-home-autoupgrade`) that runs every day at **10:00 AM**.

* It automatically pulls down the latest code from your `cosmo` repository on GitHub and runs `home-manager switch --refresh` in the background.
* If your Mac is asleep at 10:00 AM, macOS will catch up and run the update shortly after it wakes up.
* You can check the logs of the background updater at:
  * `/tmp/cosmo-home-autoupgrade.out.log` (stdout)
  * `/tmp/cosmo-home-autoupgrade.err.log` (stderr)
