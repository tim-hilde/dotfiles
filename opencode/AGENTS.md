# Skills

**Skills aren't optional. Before creating any file, writing any code, or running any tool, check `<available_skills>` and read every plausibly relevant SKILL.md first.**

The check is unconditional. Don't first decide whether a task "needs" a skill — the skills themselves define what they cover. Multiple skills can apply to one task; read all that might fit, not just the most obvious one.

- Read the skill before acting, even if the format feels familiar. Skills encode environment-specific constraints (available libraries, output paths, rendering quirks) that aren't in training data.
- User-uploaded skills take priority — they're almost certainly relevant to the current request.
- Skill-Mapping isn't always obvious from the name: a "create a chart" task may need the data-analysis skill, a "write a report" task the docx skill, a "build a component" task the frontend-design skill.

# Comments

Default to no comments — let naming and structure carry the meaning. Add one only when the code can't: to explain *why* something non-obvious is done, warn about a footgun, or link to external context (bug, spec, ticket).

Don't restate code, narrate decisions, or leave changelog comments ("switched from X to Y").

# Worktrees

Use a separate git worktree for every new feature, bugfix or refactor. This keeps the main branches clean and lets parallel agent sessions work without conflicts.

## When to create one

- Before the first commit of any task that will produce a PR.
- Before long-running commands (tests, migrations, builds) that could collide with parallel work in the main checkout.

## Layout & naming

- Location: `../worktrees/<branch-name>/` (sibling of the repo, never inside it).
- Branch name: `<type>/<kebab-slug>` where `<type>` ∈ `feat | fix | chore | refactor`.
- Example: `feat/oauth-login`, `fix/null-pointer-checkout`.

## Rules

- ✅ One worktree per task. Reuse only when continuing the same branch.
- ✅ Remove the worktree as soon as the PR is merged or abandoned.
- ⚠️ Ask before branching off anything other than `origin/main/staging/dev` (e.g. `release/*`, another open feature branch).
- 🚫 Never place worktrees inside the repo — they get picked up by globs, linters, and CI.
- 🚫 Never `worktree remove --force` with uncommitted changes.

# Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

# Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

# Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

# Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
