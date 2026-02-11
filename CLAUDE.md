# Claude Code Instructions

## Git Commits and Pull Requests

- Never include "Co-Authored-By" lines referencing Claude or Anthropic
- Do not mention Claude, AI, or LLM assistance in commit messages or PR descriptions
- Keep commit messages focused on the changes themselves

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
