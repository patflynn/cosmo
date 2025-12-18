# Doom Emacs Setup

Since `doom-emacs` manages its own configuration and packages outside of Nix (imperatively), the core program must be installed manually after the NixOS environment is set up.

However, the **user configuration** (`config.el`, `init.el`, `packages.el`) is managed by Home Manager in this repository.

## Prerequisites

Ensure your NixOS/Home Manager configuration has been applied. This ensures:
1.  Dependencies are installed (defined in `home/common.nix`): `git`, `emacs`, `ripgrep`, `fd`.
2.  Config files are linked: `~/.config/doom` should already contain symlinks to the files in `home/doom/`.

## Installation

1.  **Clone Doom Emacs:**
    ```bash
    git clone --depth 1 [https://github.com/doomemacs/doomemacs](https://github.com/doomemacs/doomemacs) ~/.config/emacs
    ```

2.  **Install Doom:**
    ```bash
    ~/.config/emacs/bin/doom install
    ```
    * **Env File:** Answer 'yes' to generate an env file.
    * **Config:** If asked to generate a private config, answer **NO**. We want to use the existing config managed by Nix (in `~/.config/doom`).
    * **Fonts:** Answer 'yes' to installing fonts if asked.

## Configuration & Updates

Because `~/.config/doom` is managed by Nix (symlinked from `home/doom/`), you do not need to manually copy files.

To apply changes:

1.  **Edit Source:** Modify files in `home/doom/` inside this repository.
2.  **Apply Nix:** Run `rebuild` (or `home-manager switch`) to update the symlinks.
    * *Note: This does not instantly update Doom's packages.*
3.  **Sync Doom:** If you modified `packages.el` or `init.el`, run:
    ```bash
    ~/.config/emacs/bin/doom sync
    ```

## Usage

-   Ensure `~/.config/emacs/bin` is in your `PATH` (or use the aliases defined in `home/common.nix`).
-   Run `doom doctor` to diagnose issues.
