# Project Workflow: Cosmo

## Guiding Principles

1. **The Plan is the Source of Truth:** All work must be tracked in `plan.md`.
2. **The Tech Stack is Deliberate:** Changes to the tech stack must be documented in `tech-stack.md` *before* implementation.
3. **Verification-Driven Development:** Define how to verify a change (e.g., VM build, dry-run, or NixOS test) *before* implementing.
4. **Reproducibility:** All configurations must be declarative and reproducible via Flakes.
5. **Clean Code:** All Nix code must be formatted with `nixfmt` (via `nix fmt`).

## Task Workflow

All tasks follow a strict lifecycle:

### Standard Task Workflow

1. **Select Task:** Choose the next available task from `plan.md` in sequential order.

2. **Mark In Progress:** Before beginning work, edit `plan.md` and change the task from `[ ]` to `[~]`.

3. **Define Verification Strategy (Red Phase):**
   - Identify the specific command or check that will validate the change.
   - *Examples:*
     - "Run `nixos-rebuild build --flake .#classic-laddie --dry-run` to ensure syntax is valid."
     - "Run `nix flake check` to verify module structure."
     - "Build a VM image to test boot: `nixos-rebuild build-vm --flake .#host`."

4. **Implement (Green Phase):**
   - Write the minimum amount of Nix configuration necessary.
   - Run the defined verification command to confirm success.

5. **Refactor (Optional but Recommended):**
   - Refactor module structure for clarity and reusability.
   - Ensure `nix fmt` is run.

6. **Verify Integrity:**
   - Run global checks: `nix flake check`.
   - Ensure no "dirty" hacks or uncommitted secrets.

7. **Document Deviations:** If implementation differs from tech stack:
   - **STOP** implementation
   - Update `tech-stack.md`
   - Resume implementation

8. **Commit Code Changes:**
   - Stage all code changes.
   - Commit with a clear message: `feat(hyprland): Add waybar config`.
   - **Note:** Ensure no `.age` secrets are committed in plaintext.

9. **Attach Task Summary with Git Notes:**
   - Get hash: `git log -1 --format="%H"`
   - Draft summary.
   - Attach: `git notes add -m "<summary>" <hash>`

10. **Push and Create Pull Request:**
    - **Action:** Push to origin: `git push origin <branch_name>`
    - **Action:** Create PR targeting `main`.

11. **Get and Record Task Commit SHA:**
    - Update `plan.md` task to `[x]` with commit SHA.

12. **Commit Plan Update:**
    - Commit the plan update: `conductor(plan): Mark task '...' as complete`.

### Phase Completion Verification and Checkpointing Protocol

**Trigger:** Executed immediately after a task completion that concludes a phase.

1.  **Announce Protocol Start:** Inform user.
2.  **Verify Phase Scope:** List changed files.
3.  **Execute Automated Checks:**
    -   Command: `nix flake check`
    -   Command: `nix fmt -- --check`
    -   Command: `nixos-rebuild build --flake .#<relevant_host> --dry-run`
4.  **Propose Manual Verification Plan:**
    -   If applicable, propose spinning up a VM (`build-vm`) or specific manual checks.
5.  **Await Feedback:** Wait for user confirmation.
6.  **Create Checkpoint Commit:** `conductor(checkpoint): Checkpoint end of Phase X`.
7.  **Attach Report:** Attach verification report via `git notes`.
8.  **Record Checkpoint SHA:** Update `plan.md` with `[checkpoint: <sha>]`.
9.  **Commit Plan Update:** `conductor(plan): Mark phase '...' as complete`.

## Git & Branching Protocol (CRITICAL)
1.  **Protected Main:** NEVER commit directly to or push to the `main` branch. All changes must go through a Pull Request.
2.  **Fresh State:** Before creating a new branch, ALWAYS checkout `main` and run `git pull origin main` to ensure you are building on the latest code.
3.  **Branch Isolation:** Create a NEW branch for every single task or feature.
    *   Naming convention: `feat/description`, `fix/issue`, or `chore/task`.
    *   NEVER reuse a branch that has already been merged.
    *   NEVER start a new task on an existing feature branch unless it is strictly related.
4.  **Cleanup:** After a branch is merged, delete it locally to avoid confusion.

## Quality Gates

Before marking any task complete, verify:

- [ ] `nix flake check` passes.
- [ ] Code is formatted (`nix fmt`).
- [ ] Targeted host configuration builds successfully.
- [ ] New modules follow the project directory structure.
- [ ] No plaintext secrets in `/nix/store` or git (use Agenix).

## Development Commands

### Setup
```bash
# Update flake lock file
nix flake update
```

### Daily Development
```bash
# Check syntax and flake integrity
nix flake check

# Format code
nix fmt

# Build a specific host (dry run)
nixos-rebuild build --flake .#classic-laddie --dry-run

# Build a VM for testing a host configuration safeley
nixos-rebuild build-vm --flake .#classic-laddie
# Run the VM
./result/bin/run-classic-laddie-vm
```

### Deployment
```bash
# Apply configuration to the current machine
sudo nixos-rebuild switch --flake .

# Apply to a remote machine
nixos-rebuild switch --flake .#remote-host --target-host user@ip
```

## Definition of Done

A task is complete when:
1.  Configuration implemented.
2.  Verification (Build/VM) successful.
3.  Formatted with `nix fmt`.
4.  Committed with proper message.
5.  PR created.
6.  `plan.md` updated.