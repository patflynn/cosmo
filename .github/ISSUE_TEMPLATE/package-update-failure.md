---
title: "Package Update Failure: {{ env.failure_type }}"
assignees: patflynn
labels: bug, dependencies
---

## Failure Details

The daily package update workflow failed on {{ date | date('YYYY-MM-DD') }}.

Type: {{ env.failure_type }}

## Affected Components
{{ env.flake_status }}
{{ env.desktop_status }}
{{ env.server_status }}
{{ env.home_status }}

## Error Messages
```
{{ env.error_details }}
```

## Possible Solutions
Any suggestions for resolving the issue.

This issue was created automatically by the daily update workflow.
