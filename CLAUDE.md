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

## Multi-Agent Orchestration

When the user asks you to do multiple independent tasks in parallel, use `scripts/cosmo-agent` to launch worker agents. You act as the coordinator.

### Workflow

1. Break the user's request into independent tasks
2. Launch each task as a separate agent:
   ```bash
   scripts/cosmo-agent launch "<task description>" --issue N --budget 3
   ```
3. Monitor progress with `scripts/cosmo-agent status`
4. Check individual agent output with `scripts/cosmo-agent logs <agent-id>`
5. Report results back to the user
6. Clean up after PRs are merged with `scripts/cosmo-agent cleanup --all`

### Requirements

- Must be running inside tmux (each agent gets its own pane)
- Each agent runs in an isolated git worktree and opens its own PR
- Default budget is $5 per agent; use `--budget N` to adjust
- Use `--issue N` to link an agent's PR to a GitHub issue
