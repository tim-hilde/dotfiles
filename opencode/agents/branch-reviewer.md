---
description: Read-only code reviewer for a branch. Invoked programmatically by the /review-loop flow via Task with just a branch name — behaves exactly like an unscoped "Code review <branch>" chat.
hidden: true
model: anthropic/claude-opus-4-8
reasoningEffort: xhigh
permission:
  edit: deny
  write: deny
  task: allow
---
