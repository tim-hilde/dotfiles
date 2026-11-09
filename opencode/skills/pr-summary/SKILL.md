---
name: pr-summary
description: >
  Generate a professional GitHub Pull Request summary from a git diff. Use this skill
  whenever the user wants to create, write, or generate a PR description, pull request
  summary, or PR message. The output is copy-paste ready markdown formatted for GitHub.
  Also use it when the user wants to wait for, check, or fetch the automated Codex
  review of a pull request in the Merlin-Digital-Solutions GitHub organization, or
  asks to check PR comments until the PR is approved.
---

# PR Summary Skill

Generate a professional, copy-paste ready GitHub Pull Request summary from a `git diff`.

## When this skill is used

- User asks to write/create/generate a PR summary, PR description, or pull request message
- User asks to wait for or check the Codex review of a PR, or to check PR comments until the PR is approved (Merlin-Digital-Solutions repositories only, see Step 5)

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
One concise paragraph: what this changes for users/the system; any side effects, migration notes, or breaking changes worth flagging.

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

**Formatting**: Write every paragraph and bullet as a single continuous line — no manual line breaks within paragraphs or bullets. Let GitHub's renderer wrap text. The only allowed newlines are between sections, between paragraphs, and between list items.

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

### Step 5 — Wait for the Codex review (Merlin-Digital-Solutions only)

Repositories of the GitHub organization `Merlin-Digital-Solutions` run the workflow `codex-review.yml` (merlin-spricht, merlin-schreibt, merlin-dashboard, merlin-cluster, scraping-infrastructure). After every push to a PR, it posts a comment that starts with `<!-- codex-review -->`, about 10 to 15 minutes later. The comment has the sections `Required Changes` (🔴 blocking findings), `Important Suggestions`, `Minor Suggestions` and `Verdict`.

If the PR is in another organization, skip this step: there is no such comment, and the script waits for nothing.

If the user wants the review of a push, or wants the PR checked until it is approved, run the bundled script from a checkout of the repository. Run it in every case, also when the review is probably already there: then it returns at once. Do not read the comments by hand and do not map workflow runs to commits. The script is the match.

```bash
bash ~/.config/opencode/skills/pr-summary/scripts/wait-review.sh <PR-NUMBER> [MAX-MINUTES] [SHA]
```

The script waits until the PR head is the pushed commit or a later one, for example the commit of the migration bot. Then it waits for a `<!-- codex-review -->` comment that is newer than the head commit and newer than the last `codex-review.yml` run for that head, and prints it. `PR-NUMBER` defaults to the PR of the current branch, and `MAX-MINUTES` to 30. `SHA` defaults to the local HEAD when the current branch is the head branch of the PR. If you run the script from another checkout, pass the pushed commit as `SHA`, or the script can return the review of the push before.

Exit codes:

- 0: the review is on stdout.
- 1: no review came in time. Read `gh pr checks <PR-NUMBER>`: the job `review` shows whether the workflow ran.
- 2: the PR is a draft. `codex-review.yml` skips drafts, so no review comes. Run `gh pr ready <PR-NUMBER>` only when the user agreed that the PR leaves draft, then run the script again.

Run the script in the foreground, with a shell timeout above `MAX-MINUTES` (for example 2,700,000 ms for 40 minutes). A background run only helps when the same session stays active until the notification arrives. If a subagent ends its turn while the script still runs in the background, nobody reads the review.

Loop until the PR is approved:

1. Run the script and read the printed review.
2. If `Required Changes` is not `None.`, fix the blocking findings with the `receiving-code-review` skill, run the tests, commit, and push.
3. Run the script again. Each push gets a new review, and the script only accepts a review of the pushed commit or a later one.
4. Stop when `Required Changes` is `None.` and the `Verdict` is Approve. Report the verdict and anything the review left open.

---

## Quality checklist (self-review before responding)

- [ ] Title follows conventional commits and is ≤72 chars
- [ ] Lock files and generated files are ignored
- [ ] Each change group has a meaningful heading
- [ ] Bullets explain *why*, not just *what*
- [ ] Output is wrapped in a markdown code block
- [ ] No empty sections
- [ ] No manual line breaks within paragraphs or bullets (each is a single continuous line)
