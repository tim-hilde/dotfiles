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

The `using-git-worktrees` skill owns the worktree workflow. Project-specific conventions on top of it:

- Location: `../worktrees/<branch-name>/`, sibling of the repo — never inside it (globs/linters/CI pick it up).
- Branch name: `<type>/<kebab-slug>`, `<type>` ∈ `feat | fix | chore | refactor`.
- Branch off `origin/main`, `staging`, or `dev` — ask before branching off anything else (`release/*`, another open feature branch).

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

Strong, observable success criteria let you loop independently. Weak criteria ("make it work") require constant clarification. The `writing-plans` skill owns plan structure — don't reinvent it here.

# Read to Edit, Code to Analyze

**Reading a file loads every byte into context. Only read what you will edit.**

- Reading to **edit** → use `Read`. The edit tool needs the exact bytes in context to match against.
- Reading to **analyze, count, search, summarize, or extract** → run code over it (e.g. `ctx_execute_file` if available, otherwise a sandboxed script). Print only the derived answer; the raw bytes stay out of context.
- **Multiple related reads** → batch them in one script (`ctx_batch_execute`/`ctx_execute`) instead of N sequential `Read` calls.

The test: if you will not edit the lines you are about to read, you are analyzing — process it in code.

# Progress Updates

Before a group of related tool calls, write one short sentence (≈8–12 words) naming what you're about to do. Group logically — don't narrate every single call or turn the transcript into a tool-call log.

Skip it for trivial one-step actions. Don't pre-announce a full plan in prose before starting — state success criteria once, then act.

# Tool Hierarchy

Prefer the dedicated tools over shell commands — faster, safer, cleaner output:

- Search content → `grep` tool, not `grep`/`cat` via `bash`.
- Find files → `glob`, not `find`.
- Read files → `read`/`list`, not `cat`/`head`/`tail`.
- Edit files → `edit`, not `sed`/`echo >`.

Reserve `bash` for what only a shell can do (tests, git, builds). Make independent tool calls in parallel, not one after another.

# Final Answers

Keep the closing summary short and natural. Reserve headings, tables, and bullets for genuinely complex results. Don't recap steps you already narrated — state the outcome and any next action the user needs.
