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

# context-mode — MANDATORY routing rules

context-mode MCP tools available. Rules protect context window from flooding. One unrouted command dumps 56 KB into context.

## Think in Code — MANDATORY

Analyze/count/filter/compare/search/parse/transform data: **write code** via `context-mode_ctx_execute(language, code)`, `console.log()` only the answer. Do NOT read raw data into context. PROGRAM the analysis, not COMPUTE it. Pure JavaScript — Node.js built-ins only (`fs`, `path`, `child_process`). `try/catch`, handle `null`/`undefined`. One script replaces ten tool calls.

## BLOCKED — do NOT attempt

### curl / wget — BLOCKED

Shell `curl`/`wget` intercepted and blocked. Do NOT retry.
Use: `context-mode_ctx_fetch_and_index(url, source)` or `context-mode_ctx_execute(language: "javascript", code: "const r = await fetch(...)")`

### Inline HTTP — BLOCKED

`fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(` — intercepted. Do NOT retry.
Use: `context-mode_ctx_execute(language, code)` — only stdout enters context

### Direct web fetching — BLOCKED

Use: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)`

## REDIRECTED — use sandbox

### Shell (>20 lines output)

Shell ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`.
Otherwise: `context-mode_ctx_batch_execute(commands, queries)` or `context-mode_ctx_execute(language: "javascript", code: "...")`. Use `language: "shell"` only when code matches the host shell.

### File reading (for analysis)

Reading to **edit** → reading correct. Reading to **analyze/explore/summarize** → `context-mode_ctx_execute_file(path, language, code)`.

### grep / search (large results)

Use `context-mode_ctx_execute(language: "javascript", code: "...")` in sandbox for portable filtering/counting.

## Tool selection

0. **MEMORY**: `context-mode_ctx_search(sort: "timeline")` — after resume, check prior context before asking user.
1. **GATHER**: `context-mode_ctx_batch_execute(commands, queries)` — runs all commands, auto-indexes, returns search. ONE call replaces 30+. Each command: `{label: "header", command: "..."}`.
2. **FOLLOW-UP**: `context-mode_ctx_search(queries: ["q1", "q2", ...])` — all questions as array, ONE call (default relevance mode).
3. **PROCESSING**: `context-mode_ctx_execute(language, code)` | `context-mode_ctx_execute_file(path, language, code)` — sandbox, only stdout enters context.
4. **WEB**: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` — raw HTML never enters context.
5. **INDEX**: `context-mode_ctx_index(content, source)` — store in FTS5 for later search.

## Parallel I/O batches

For multi-URL fetches or multi-API calls, **always** include `concurrency: N` (1-8):

- `context-mode_ctx_batch_execute(commands: [3+ network commands], concurrency: 5)` — gh, curl, dig, docker inspect, multi-region cloud queries
- `context-mode_ctx_fetch_and_index(requests: [{url, source}, ...], concurrency: 5)` — multi-URL batch fetch

**Use concurrency 4-8** for I/O-bound work (network calls, API queries). **Keep concurrency 1** for CPU-bound (npm test, build, lint) or commands sharing state (ports, lock files, same-repo writes).

GitHub API rate-limit: cap at 4 for `gh` calls.

## Output

Write artifacts to FILES — never inline. Return: file path + 1-line description.
Descriptive source labels for `search(source: "label")`.

## Session Continuity

Skills, roles, and decisions persist for the entire session. Do not abandon them as the conversation grows.

## Memory

Session history is persistent and searchable. On resume, search BEFORE asking the user:

| Need | Command |
|------|---------|
| What did we decide? | `context-mode_ctx_search(queries: ["decision"], source: "decision", sort: "timeline")` |
| What constraints exist? | `context-mode_ctx_search(queries: ["constraint"], source: "constraint")` |

DO NOT ask "what were we working on?" — SEARCH FIRST.
If search returns 0 results, proceed as a fresh session.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call `stats` MCP tool, display full output verbatim |
| `ctx doctor` | Call `doctor` MCP tool, run returned shell command, display as checklist |
| `ctx upgrade` | Call `upgrade` MCP tool, run returned shell command, display as checklist |
| `ctx purge` | Call `purge` MCP tool with confirm: true. Warns before wiping knowledge base. |

After /clear or /compact: knowledge base and session stats preserved. Use `ctx purge` to start fresh.
