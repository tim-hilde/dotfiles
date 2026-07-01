---
description: Review the current branch against staging/dev with the branch-reviewer subagent, fix blockers, and re-review until clean. Best-effort review loop — not a hard merge gate.
agent: build
---

Run a review-fix-reverify loop on the branch `$ARGUMENTS` (default: the current `HEAD`). This is a best-effort loop driven by you, the agent — it is NOT a deterministic gate. Be honest in the summary about anything left unresolved.

## Setup

1. `git fetch origin`.
2. Determine the target branch: use `origin/staging` if it exists, else `origin/dev`. If neither exists, ask the user.
3. Determine the source ref: `$ARGUMENTS` if given, else current `HEAD`.
4. Resolve `SOURCE_SHA=$(git rev-parse <source>)` and `HEAD_SHA=$(git rev-parse HEAD)`. If they differ, run `git worktree list` and look for a worktree already checked out at `<source>` / `SOURCE_SHA`.
   - Found → stop and tell the user to re-run `/review-branch` from that worktree path. The reviewer reads file context from the current working tree, so it must match the branch under review.
   - Not found → warn the user that context reads (beyond the diff itself) will reflect the currently checked-out branch, not `<source>`, before proceeding.

## Detect the test command (generic)

Find how this project runs its tests, in this order:

1. A "Commands" / "Test" section in the project's `AGENTS.md` or `CLAUDE.md`.
2. Common markers: `package.json` (`scripts.test`), `Makefile` (`test` target), `pyproject.toml` / `pytest.ini` (pytest), `Cargo.toml` (`cargo test`), `go.mod` (`go test ./...`).
3. If nothing is unambiguous, ask the user for the test command.

Preserve any required prefix/wrapper exactly as documented (env loaders, runners, etc.).

## Loop (max 5 rounds)

Repeat until `STATUS: CLEAN`, or stop after 5 rounds:

1. Build the diff once: `git diff origin/<target>..<source> -- . ':(exclude)*.lock'`. Capture the output as text.
2. Run the detected test command. Capture pass/fail and the relevant output.
3. Dispatch the `branch-reviewer` subagent via the Task tool, passing it: the target/source refs, the resolved source SHA, the diff **text** (not the diff command), and the test result. Not more. Do not instruct the reviewer how do review or what to focus on and give no additional context. The reviewer will not what to do.
4. Read the subagent's reply and the final `STATUS:` line.
   - `STATUS: CLEAN` → stop the loop, go to Report.
   - `STATUS: BLOCKERS` → fix the listed 🔴 Blocking findings yourself (follow `receiving-code-review` and `verification-before-completion`). Best-effort fix any 🟡 Important findings too if straightforward. Then start the next round with a fresh diff and a fresh test run.
5. If round 5 ends still on `STATUS: BLOCKERS`, stop and report the remaining blockers — do not loop forever.

## Report

Output a short summary:

- final status (clean / stopped with N blockers remaining)
- rounds used
- the latest findings in full: 🔴 Blocking / 🟡 Important / 🟢 Nit — include 🟡 and 🟢 even when the status is clean, they may still be relevant
- the test command and its last result

This loop is best-effort, not a guarantee. After a clean result you can run `/pr <branch>` to produce the PR description.
