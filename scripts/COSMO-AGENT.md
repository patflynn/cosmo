# cosmo-agent

Multi-agent orchestration for Claude Code. Currently in **prototyping phase**.

## Problem

Working on a NixOS flake repo often involves multiple independent tasks — adding a module to one host, fixing a waybar config, updating secrets. These tasks don't depend on each other, but Claude Code runs one conversation at a time in one working directory. If you want parallelism, you're manually opening terminals, creating branches, and babysitting each session.

cosmo-agent solves this by letting a single Claude Code session (the coordinator) fan out work to multiple autonomous worker agents, each isolated in its own git worktree, visible in its own tmux pane, and tracked from prompt to PR.

## Features

- **Parallel agent runs** — launch multiple autonomous Claude Code sessions from one command
- **Git worktree isolation** — each run gets its own branch and working directory, no conflicts
- **Tmux dashboard** — each agent runs in a visible pane with real-time streaming output
- **Run tracking** — state files record prompt, issue, branch, cost, PR URL, and timing
- **Persistent history** — full JSONL transcripts (every tool call, every response) are saved and synced to a `cosmo-agent/data` orphan branch, pushable and browsable
- **Traceability** — PRs include a `Run: <id>` footer linking back to the run; status table links runs to PRs and issues
- **Budget control** — each run has a dollar cap via `--max-budget-usd`
- **Cleanup** — one command tears down worktrees, panes, branches, and state

## Usage

```
cosmo-agent launch "<prompt>" [--issue N] [--budget N]
cosmo-agent status
cosmo-agent logs <run-id> [--live | --replay | --raw]
cosmo-agent cleanup <run-id> | --all
cosmo-agent help
```

### Coordinator workflow

Start a Claude Code session inside tmux. Ask it to do multiple things:

> "I need three things done: add bluetooth to weller (#42), fix the waybar clock, and add a scratch workspace to hyprland."

Claude (the coordinator) launches each as a separate run:

```bash
scripts/cosmo-agent launch "Add bluetooth config to weller" --issue 42 --budget 3
scripts/cosmo-agent launch "Fix waybar clock format" --budget 2
scripts/cosmo-agent launch "Add scratch workspace to hyprland" --budget 2
```

Then monitors with `status`, checks output with `logs`, and cleans up after PRs merge.

### What you see

```
┌──────────────────────────────────────────┐
│  Coordinator (your Claude Code session)  │
├──────────────┬──────────────┬────────────┤
│ Run a3f2     │ Run b7c1     │ Run d9e5   │
│ ▶ Read ...   │ ▶ Edit ...   │ ▶ Bash ... │
│ ▶ Edit ...   │ ── done ──   │ ▶ Bash ... │
└──────────────┴──────────────┴────────────┘
```

### Status output

```
RUN ID                  STATUS      COST      ISSUE   PR                              PROMPT
------                  ------      ----      -----   --                              ------
20260210-1430-a3f2      pr-created  $0.10     42      #260                            Add bluetooth config to weller...
20260210-1431-b7c1      running     <$2       -       -                               Fix waybar clock format...
```

## Design

### Architecture

Each `launch` does:

1. Generate a run ID: `YYYYMMDD-HHMM-xxxx` (timestamp + 4-char random hex)
2. `git fetch origin main`
3. `git worktree add /tmp/cosmo-agent/<id> -b agent/<id> origin/main`
4. Start `claude -p --dangerously-skip-permissions --output-format stream-json` in a new tmux pane
5. Pipe output through `tee` (to JSONL log) and a stream formatter (to the pane display)
6. Write a state file to `.git/cosmo-agent/runs/<id>.json`

When the run finishes, the finalizer:

1. Parses the JSONL log for cost, duration, and PR URL
2. Updates the local state file
3. Commits both files to the `cosmo-agent/data` orphan branch using git plumbing (temporary index, no working tree impact)
4. Pushes the data branch

### Data storage

```
.git/cosmo-agent/              Local cache (fast reads for status/logs)
├── runs/<id>.json             Run metadata: prompt, branch, cost, PR URL, etc.
└── logs/<id>.jsonl            Full Claude transcript: every tool call and response

cosmo-agent/data branch        Orphan branch (pushable, browsable, persistent)
├── runs/<id>.json
└── logs/<id>.jsonl
```

The orphan branch is committed to without touching the working tree — using `hash-object`, `update-index`, `write-tree`, and `commit-tree` against a temporary index file.

### Traceability

```
Issue #42 ←──── "Fixes #42" ──── PR #260 ←──── "Run: a3f2" ──── Run a3f2
                                                                    │
                                                      runs/a3f2.json (cost, timing)
                                                      logs/a3f2.jsonl (full transcript)
```

### Key decisions

- **Print mode** (`claude -p`): agents are fire-and-forget. Cost control via `--max-budget-usd` only works in print mode.
- **`--dangerously-skip-permissions`**: required for autonomous git/nix/gh operations. Acceptable because each agent runs in an isolated worktree with bounded budget.
- **`/tmp/cosmo-agent/`** for worktrees: ephemeral, auto-cleaned on reboot.
- **Requires tmux**: the dashboard UX depends on pane management.
- **Requires jq**: used for JSON state files and JSONL log parsing.

### Dependencies

- `claude` (Claude Code CLI)
- `tmux`
- `jq`
- `git`, `gh`
