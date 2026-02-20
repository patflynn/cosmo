# Claude Code Instructions

## Git Commits and Pull Requests

- Never include "Co-Authored-By" lines referencing Claude or Anthropic
- Do not mention Claude, AI, or LLM assistance in commit messages or PR descriptions
- Keep commit messages focused on the changes themselves

## Secrets (Agenix)

- Secrets are managed with [agenix](https://github.com/ryantm/agenix) in the `secrets/` directory
- `secrets/keys.nix` defines which SSH public keys can decrypt secrets (users and hosts)
- `secrets/secrets.nix` maps `.age` files to their authorized keys
- **Any change to `secrets/keys.nix` requires rekeying**: `cd secrets && agenix --rekey`
- Rekeying decrypts and re-encrypts all `.age` files with the updated key set
- This requires access to a private key that is already a recipient (typically the host key at `/etc/ssh/ssh_host_ed25519_key`, which needs sudo)
- If you cannot rekey (e.g., no sudo access), note it in the PR so the change can be completed manually
