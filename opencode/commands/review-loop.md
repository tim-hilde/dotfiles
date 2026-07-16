---
description: Review the current branch with the branch-reviewer subagent, fix blockers, and re-review until clean; then triage remaining Important/Nit findings and surface anything left open. Best-effort review loop — not a hard merge gate.
agent: build
---

Run a review-fix-reverify loop on the branch `$ARGUMENTS` (default: the current branch). This is a best-effort loop driven by you, the agent — it is NOT a deterministic gate. Be honest in the summary about anything left unresolved.

The `branch-reviewer` subagent is dispatched with nothing but a branch name — it determines the target branch, diff, worktree, and tests itself, the same as an unscoped "Code review `<branch>`" chat would. All interpretation of its reply — whether it's blocking, what to fix, what to leave open — is your job as the dispatching agent, not something the subagent signals for you.

## Setup

1. Determine the branch name: `$ARGUMENTS` if given, else the current branch (`git branch --show-current`). If detached HEAD and no `$ARGUMENTS`, ask the user for the branch name.

## Detect the test command (generic)

Find how this project runs its tests, in this order:

1. A "Commands" / "Test" section in the project's `AGENTS.md` or `CLAUDE.md`.
2. Common markers: `package.json` (`scripts.test`), `Makefile` (`test` target), `pyproject.toml` / `pytest.ini` (pytest), `Cargo.toml` (`cargo test`), `go.mod` (`go test ./...`).
3. If nothing is unambiguous, ask the user for the test command.

Preserve any required prefix/wrapper exactly as documented (env loaders, runners, etc.). This is for verifying your own fixes below — it is never passed to the reviewer.

## Loop (max 5 rounds)

Repeat until a round comes back clean, or stop after 5 rounds:

1. Dispatch the `branch-reviewer` subagent via the Task tool with exactly this prompt: `Code review <branch-name>`. Nothing else — no diff, no test results, no target ref, no worktree path. Do not instruct it how to review or what to focus on.
2. Read its reply yourself. Treat the round as blocked if it contains any 🔴 Blocking finding, its Verdict is 🔄 Request Changes, or it reports a failing test run.
3. Add this round's 🟡 Important / 🟢 Nit findings to a running backlog, deduped by file:line + issue (do this every round, blocked or not — a later round's fresh review has no memory of earlier rounds and may not resurface the same non-blocking findings).
4. If blocked: fix the 🔴 Blocking findings yourself (follow `receiving-code-review` and `verification-before-completion`), best-effort fixing straightforward 🟡 Important findings too. Verify with the detected test command. Start the next round with a fresh dispatch.
5. If round 5 ends still blocked, stop the loop and report the remaining blockers as unresolved — do not loop forever, but still run Triage below on the accumulated backlog before reporting.

## Triage

Once a round comes back non-blocked (or round 5 is exhausted):

1. Take the accumulated 🟡 Important / 🟢 Nit backlog from every round.
2. Decide independently, per item: fix now (quick, localized, low-risk) or leave open (broad refactor, risky, subjective/style, out of scope) — one-line reason for anything left open.
3. Apply the chosen fixes (`receiving-code-review` + `verification-before-completion`), then re-run the detected test command once to confirm nothing broke.

## Report

Output a short summary:

- final status (clean / stopped with N blockers remaining)
- rounds used
- Triage outcome: Fixed (what changed) / Left Open (with reasons)
- the test command and its last result

This loop is best-effort, not a guarantee. After a clean result you can run `/pr <branch>` to produce the PR description.
