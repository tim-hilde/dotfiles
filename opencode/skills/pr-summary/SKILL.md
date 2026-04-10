---
name: pr-summary
description: >
  Generate a professional GitHub Pull Request summary from a git diff. Use this skill
  whenever the user wants to create, write, or generate a PR description, pull request
  summary, or PR message. The output is copy-paste ready markdown formatted for GitHub.
---

# PR Summary Skill

Generate a professional, copy-paste ready GitHub Pull Request summary from a `git diff`.

## When this skill is used

- User asks to write/create/generate a PR summary, PR description, or pull request message

---

## Workflow

### Step 1 — Get the diff

**With shell access**: Run the diff automatically, asking the user for the target branch first (default: `dev`):

```bash
git diff <target_branch> -- . ':(exclude)*.lock'
```

**With no shell access**: Ask the user to paste the output of:

```bash
git diff dev -- . ':(exclude)*.lock'
# or against main/master/their target branch
```

Lock files (`*.lock`, `package-lock.json`, `yarn.lock`, `Gemfile.lock`, etc.) should always be excluded from the diff — ignore them if present.

### Step 2 — Analyse the diff

Before writing, mentally map out:

- **What problem** does this PR solve?
- **What solution** was implemented?
- **Which files/areas** were changed, and why?
- **Any side effects**, breaking changes, or important technical details?

### Step 3 — Write the summary

Use this structure:

```
<conventional-commit-title>

## Summary
One concise paragraph: what problem was solved, what solution was implemented.

## Impact
One concise paragraph: what this changes for users/the system; any side effects,
migration notes, or breaking changes worth flagging.

## Changes

### <Logical Group / File or Feature Area>
- Bullet describing what changed and why
- Bullet for relevant technical detail

### <Next Logical Group>
- ...
```

**Title**: Use conventional commit format: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `perf:`, `ci:` — pick the one that fits best. Keep it under 72 chars.

**Grouping changes**: Group related file changes under a meaningful heading (e.g. "Authentication", "Database migrations", "CI pipeline") rather than listing every file individually.

**Depth per group**: 2–3 bullet points per group is ideal. Omit obvious/trivial changes. Prioritise *why* over *what* when the why isn't obvious from the diff.

**Tone**: Factual, professional, concise. No filler phrases like "this PR aims to..." or "we have updated...".

### Step 4 — Deliver the output

Always wrap the final summary in a markdown code block so it's copy-paste ready for GitHub:

````
```markdown
feat: add user avatar upload with S3 storage

## Summary
...

## Impact
...

## Changes
...
```
````

---

## Quality checklist (self-review before responding)

- [ ] Title follows conventional commits and is ≤72 chars
- [ ] Lock files and generated files are ignored
- [ ] Each change group has a meaningful heading
- [ ] Bullets explain *why*, not just *what*
- [ ] Output is wrapped in a markdown code block
- [ ] No empty sections
