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
cosmo-agent session
cosmo-agent launch "<prompt>" [--issue N] [--budget N]
cosmo-agent status
cosmo-agent logs <run-id> [--live | --replay | --raw]
cosmo-agent cleanup <run-id> | --all
cosmo-agent help
```

### Coordinator workflow

Start a coordinator session from your repo root inside tmux:

```bash
scripts/cosmo-agent session
```

This creates an isolated worktree and launches an interactive Claude Code session in it. The base repo stays clean on `main` — no dirty tree, no stale branch checkouts.

From inside the session, ask Claude to do multiple things:

> "I need three things done: add bluetooth to weller (#42), fix the waybar clock, and add a scratch workspace to hyprland."

Claude (the coordinator) launches each as a separate worker:

```bash
scripts/cosmo-agent launch "Add bluetooth config to weller" --issue 42 --budget 3
scripts/cosmo-agent launch "Fix waybar clock format" --budget 2
scripts/cosmo-agent launch "Add scratch workspace to hyprland" --budget 2
```

Then monitors with `status`, checks output with `logs`, and cleans up after PRs merge.

When done, `/exit` from Claude to return to your shell. The worktree is preserved for inspection — clean it up with `cosmo-agent cleanup <session-id>`.

### What you see

```
┌─────────────────────────────────────────────────┐
│  Coordinator session (interactive, in worktree)  │
├──────────────┬──────────────┬───────────────────┤
│ Worker a3f2  │ Worker b7c1  │ Worker d9e5       │
│ ▶ Read ...   │ ▶ Edit ...   │ ▶ Bash ...        │
│ ▶ Edit ...   │ ── done ──   │ ▶ Bash ...        │
└──────────────┴──────────────┴───────────────────┘
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

#### Session (coordinator)

`cosmo-agent session` does:

1. Generate a session ID: `session-YYYYMMDD-HHMM-xxxx`
2. `git fetch origin main`
3. `git worktree add /tmp/cosmo-agent/session-<id> -b session/<id> origin/main`
4. Write a state file with `"type": "session"` (no tmux pane, no budget, no log)
5. Run `claude` interactively in the worktree (foreground, normal permission prompts)
6. On exit: print cleanup instructions, preserve worktree

The session runs interactively — no `--dangerously-skip-permissions`, no `--output-format`. The user approves actions normally. Workers launched from inside the session inherit the worktree's git state and can see the shared `.git/cosmo-agent/` data.

#### Workers

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
3. Commits both files to `refs/cosmo-agent/data` using git plumbing (temporary index, no working tree impact)
4. Pushes the data ref

### Data storage

```
.git/cosmo-agent/              Local cache (fast reads for status/logs)
├── runs/<id>.json             Run metadata: prompt, branch, cost, PR URL, etc.
└── logs/<id>.jsonl            Full Claude transcript: every tool call and response

refs/cosmo-agent/data          Custom git ref (pushable, persistent, not a branch)
├── runs/<id>.json
└── logs/<id>.jsonl
```

Run data is stored under a custom git ref (`refs/cosmo-agent/data`) rather than a branch (`refs/heads/*`). This keeps it out of GitHub's branch list and avoids "recent pushes" banners. The ref is committed to without touching the working tree — using `hash-object`, `update-index`, `write-tree`, and `commit-tree` against a temporary index file.

To inspect the data locally: `git log refs/cosmo-agent/data` or `git ls-tree -r refs/cosmo-agent/data`.

### Traceability

```
Issue #42 ←──── "Fixes #42" ──── PR #260 ←──── "Run: a3f2" ──── Run a3f2
                                                                    │
                                                      runs/a3f2.json (cost, timing)
                                                      logs/a3f2.jsonl (full transcript)
```

### Key decisions

- **Session isolation**: the coordinator runs in a worktree too, so the base repo stays clean on `main`. No `--dangerously-skip-permissions` for sessions — the user approves actions normally.
- **No auto-cleanup on session exit**: the worktree is preserved so the user can inspect it, resume, or continue manually.
- **Print mode** (`claude -p`): worker agents are fire-and-forget. Cost control via `--max-budget-usd` only works in print mode.
- **`--dangerously-skip-permissions`**: required for autonomous git/nix/gh operations in workers. Acceptable because each worker runs in an isolated worktree with bounded budget.
- **`/tmp/cosmo-agent/`** for worktrees: ephemeral, auto-cleaned on reboot.
- **Requires tmux**: the dashboard UX depends on pane management; sessions require it because their purpose is to coordinate workers which need tmux panes.
- **Requires jq**: used for JSON state files and JSONL log parsing.

### Dependencies

- `claude` (Claude Code CLI)
- `tmux`
- `jq`
- `git`, `gh`
