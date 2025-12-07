# Doom Emacs Setup

Since `doom-emacs` manages its own configuration and packages outside of Nix (imperatively), it must be installed manually after the NixOS environment is set up.

## Prerequisites

Ensure your NixOS configuration has the following packages installed (already present in `home/core.nix`):
- `git`
- `emacs`
- `ripgrep`
- `fd`

## Installation

1.  **Clone Doom Emacs:**
    ```bash
    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
    ```

2.  **Install Doom:**
    ```bash
    ~/.config/emacs/bin/doom install
    ```
    *   Answer 'yes' to generating an env file.
    *   Answer 'yes' to installing fonts if asked (though Nix likely manages fonts, it doesn't hurt).

## Configuration

To restore or use the configuration from this repository:

1.  **Create/Clear the config directory:**
    ```bash
    mkdir -p ~/.config/doom
    ```

2.  **Copy config from the repository:**
    *   *Note: Adjust the source path if your repo location differs.*
    ```bash
    # Example: Copying from the legacy folder for now
    cp -r ~/hack/cosmo/old-mess/home/common/doom.d/* ~/.config/doom/
    ```

3.  **Sync changes:**
    ```bash
    ~/.config/emacs/bin/doom sync
    ```

## Usage

-   Ensure `~/.config/emacs/bin` is in your `PATH` for convenience.
-   Run `doom doctor` to diagnose issues.
