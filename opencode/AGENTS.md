# Commit messages

Write commit messages in English, in the Conventional Commits format: `<type>(<scope>): <summary>`, for example `fix(tmux): keep pane state after restart`. The scope is optional. Use one of these types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`. If a change breaks a public interface, write `!` after the type and add a `BREAKING CHANGE:` footer.

# Comments

Default to no comments. Names and structure carry the meaning. Add a comment only when the code cannot: to explain why the code does something non-obvious, to warn about a trap, or to link to external context (bug, specification, ticket).

Do not restate the code, narrate decisions, or write changelog comments ("switched from X to Y").

# Worktrees

The `using-git-worktrees` skill owns the worktree workflow. These conventions apply on top of it:

- Location: `../worktrees/<branch-name>/`, next to the repository. Never put a worktree inside the repository (for example `.worktrees/`), because globs, linters, and CI pick it up.
- Create worktrees with `git worktree add`. Do not use the native `worktree_create` tool, because it ignores this location.
- Branch name: `<type>/<kebab-slug>`, with `<type>` one of `feat`, `fix`, `chore`, `refactor`.
- Branch off `origin/main`, `staging`, or `dev`. If the task needs another base (`release/*`, another open feature branch), ask first.

# Debugging

Before every bug fix, use the `systematic-debugging` skill. Map the call chain, the logs, and the root cause first, then change the code. Do not write a fix before the diagnosis.

# Think Before Coding

Do not assume. Do not hide confusion. Name the tradeoffs.

Before you implement:

- State your assumptions. If you are not sure, ask.
- If a request has more than one meaning, show the meanings. Do not pick one silently.
- If a simpler approach exists, say so. If you disagree with the request, say so and give the reason.
- If something is unclear, stop, name what is unclear, and ask.
- When you ask, give the options and mark the one that you recommend.

# Simplicity First

Write the minimum code that solves the problem. Add nothing speculative.

- No features beyond the request.
- No abstractions for code with one use.
- No flexibility or configuration that nobody requested.
- No error handling for impossible cases.
- If you write 200 lines and 50 lines can do the job, rewrite it.

Ask yourself: "Will a senior engineer call this overcomplicated?" If yes, simplify.

# Surgical Changes

Change only what the task needs. Clean up only the mess that you made.

When you edit existing code:

- Do not improve adjacent code, comments, or formatting.
- Do not refactor code that works.
- Match the existing style, even if you prefer a different one.
- If you find unrelated dead code, mention it. Do not delete it.

If your changes leave imports, variables, or functions unused, remove them. Do not remove dead code that existed before, unless the user asks.

The test: every changed line traces directly to the request.

# Goal-Driven Execution

Define success criteria. Work in a loop until you can show that the criteria are met.

Turn each task into a goal that you can test:

- "Add validation" → "Write tests for invalid inputs, then make them pass."
- "Fix the bug" → "Write a test that reproduces the bug, then make it pass."
- "Refactor X" → "Make sure that the tests pass before and after."

Clear, observable criteria let you work in a loop without help. Weak criteria ("make it work") need constant clarification. For the structure of a plan, use the `writing-plans` skill.

# Delegating to Subagents

Decompose so that every rule has one owner.

- Before you split work, list every rule that touches more than one part (rounding, naming, error format, shared constants, API shape). Decide each rule yourself. Then write it into every affected brief, or give all affected parts to one subagent.
- Give each subagent a disjoint set of files and a self-contained brief: goal, files it owns, conventions it must follow, and how it proves success.
- If several subagents need the same facts, write them once to a file and pass the path. Do not repeat them in every prompt. If the steps already hand files to each other, add nothing.
- Start only as many parallel subagents as there are independent parts. Extra subagents without a part of their own only add coordination traffic.
- After the parts come back, make sure that the seams fit: read the interfaces between the parts and run the tests that cover them (see Tests). Do not accept "the subagents agreed" as proof.

# Tests

Do not run a full test suite on this machine. Several sessions share it, and two full suites at once overload CPU and RAM. CI runs the full suite on every pull request.

Locally, run only the tests that cover your change:

- Vitest: `npx vitest run <test files>` or `npx vitest related <changed files> --run`.
- Database tests: only the `*.db.test.ts` and pgTAP files of the changed area.
- pytest: only the test files of the changed modules, without `-n auto`.

This rule applies to every agent: subagents, the `reviewer`, and the test command of `review-loop`. If CI fails, reproduce only the failing files locally. If the user asks for a full run, run it.

# Large Files

Every line that you read stays in your context. If you must understand code, read it with `read`, and use `offset` and `limit` for the part that you need. Some files are large, for example logs, data files, or generated output. If you need only a derived result from such a file, process it with a shell script that prints only that result.

# Progress Updates

Before a group of related tool calls, write one short sentence of 8 to 12 words that names the next action. Write one sentence per group, not one per tool call. If the action has only one step, skip the sentence. Do not announce a full plan in prose. State the success criteria once, then act.

# Final Answers

Do not repeat the steps that you already narrated. Give the result and the next action that the user must take.

# On Finishing

Before claiming you have finished an implementation, make sure to have run a successful `review-loop` using the respective command.

# Merlin pull requests

For every pull request in a Merlin-Digital-Solutions repository, follow merlin-ci `PR-WORKFLOW.md`: `gh api repos/Merlin-Digital-Solutions/merlin-ci/contents/PR-WORKFLOW.md --jq .content | base64 -d`.
