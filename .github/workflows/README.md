# GitHub Workflows

This directory contains GitHub Actions workflows for the Cosmo repository.

## Claude Issue Responder

The `claude-issue-responder.yml` workflow uses Claude AI to automatically respond to GitHub issues and attempt to fix them by creating pull requests.

### How it Works

1. When an issue is created or edited, the workflow checks if it has the `claude-autofix` label
2. If the label is present, Claude analyzes the issue and generates code changes to fix it
3. The workflow creates a new branch, commits the changes, and opens a pull request
4. A comment is added to the original issue linking to the PR

### Configuration Requirements

To use this workflow, you need to:

1. Add the `ANTHROPIC_API_KEY` secret to your GitHub repository settings
2. Ensure the workflow has proper permissions to create branches and PRs
3. Label issues that should be automatically addressed with the `claude-autofix` label

### Usage

To have Claude automatically try to fix an issue:

1. Create a new issue describing the problem
2. Add the `claude-autofix` label to the issue
3. Claude will analyze the issue and create a PR if it can find a solution

You can also manually trigger the workflow for a specific issue:

```bash
gh workflow run claude-issue-responder --field issue_number=123
```

### Limitations

- The workflow works best for issues that are clearly defined and have a straightforward solution
- Complex refactoring or design decisions may require human intervention
- Claude may not be able to address all issues, especially those requiring deep contextual understanding

## Other Workflows

- `daily-update.yml`: Runs daily package updates
- `nix-fmt.yml`: Formats Nix code
- `nixos-test.yml`: Tests NixOS configurations