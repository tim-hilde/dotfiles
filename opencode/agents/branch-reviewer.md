---
description: Review branch. Will automatically use a skill for reviewing so no instructions necessary. Only say something like "review branch xyz".
mode: subagent
model: anthropic/claude-opus-5-5#xhigh
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: subagent
    resource: "*"
    effect: allow
---
