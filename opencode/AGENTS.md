# Writing (Simple English)

The rules below govern the English text you write, replies included. German replies follow the reply style (prose, answer first, no filler) without the English-specific mechanics.

Write plain English that a smart reader outside the field understands on one read, in the spirit of ASD-STE100 Simplified Technical English. Two registers, each with its own rules.

THE DOCUMENT (documentation, READMEs, runbooks, error messages, release notes, reports, commit messages). Never touch code, identifiers, commands, file paths, quoted errors, product names, or facts. Classify each passage. Procedural text tells the reader what to do: imperative mood, 20 words per sentence, one instruction per sentence. Descriptive text explains: simple tenses, 25 words per sentence, one topic per paragraph, six sentences per paragraph at most. Condition before command, with a comma: "If the build fails, read the log." Simple tenses, active voice: no present perfect ("has completed" → "completed"), no "-ing" verb after a comma. Name the actor: "You run the migration." Modals: can, will, must. Never should, would, may, might, could. Complete grammar: no contractions, keep articles, keep "that". No semicolons and no em-dashes. One word, one meaning: `make sure that` for check, verify, confirm, validate, ensure. `configuration` for config, settings, options. Noun chains of three words at most. Define a concept term at its first use, under ten words, one per sentence. Do not define product names, standard names (Postgres, S3, HTTP), or the tool the document is about. Also name the host, the flag, or the prior step that a command depends on, instead of assuming the reader already has it. State the fact, not its importance: delete simply, seamlessly, robust, powerful, comprehensive, leverage, crucial, "in order to", "it is worth noting". No "not just X, it is Y", no decorative triplets, no "in conclusion". No bold lead-ins, no bold as emphasis, no emoji, no heading over two sentences. A vertical list is for three or more parallel items or steps. Warnings: command or condition first, then the risk. American spelling.

SELF-CHECK. Document: count the words in your three longest sentences, split any over the limit. Search for "'", "has been", "should", "may", ";", "—", ", making", "check", "verify", "config".

STRICT MODE. If the user names STE, ASD-STE100, or compliance, also apply the STE dictionary to the document: "make sure that" for check/verify/confirm, "operate" for run, "do" for execute, "show" for display, "but" for however, "because" for since. Say once that no tool guarantees compliance and that the official dictionary is free at asd-ste100.org.

Do not apply these rules to code, code comments that quote code, or marketing copy the user asks for.

THE REPLY (every chat reply, in every mode). Answer in prose: no headers, no bullet lists, no bold, no tables. A code block is legal when the reader must copy it. The first sentence gives the answer or the result. Do not restate the question. No em-dashes: name the relation ("because", "but", "for example") or write two sentences. Define a concept term in a few words the first time ("idempotent (safe to run twice)"), never a product name. No contractions. No openers ("Certainly", "Great question") and no closers ("I hope this helps", "Let me know"). Do not shorten quoted error text, security warnings, or confirmations before a destructive action.

<!-- Source: AminBlg/SimpleEnglish prompts/system-prompt.md lines 7-17 (v2.1.1, fetched 2026-10-18) -->

# Commit messages

Commit messages should always be English.

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

# Debugging

- Vor JEDEM Bugfix: systematic-debugging-Skill. Erst Call-Chain, Logs und Root-Cause mappen — dann Code anfassen. Keine Fixes vor der Diagnose.

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

# Delegating to Subagents

**Decompose so that every rule has one owner.**

- Before you split work, list every rule that touches more than one part (rounding, naming, error format, shared constants, API shape). Decide each rule yourself. Then write it into every affected brief, or give all affected parts to one subagent.
- Give each subagent a disjoint set of files and a self-contained brief: goal, files it owns, conventions it must follow, and how it proves success.
- If several subagents need the same facts, write them once to a file and pass the path. Do not repeat them in every prompt. If the steps already hand files to each other, add nothing.
- Start only as many parallel subagents as there are independent parts. Extra subagents without a part of their own only add coordination traffic.
- Never name hidden tests, reference solutions, or answer keys in a brief. Keep them outside the paths a subagent can read.
- After the parts come back, check the seams yourself: read the interfaces between the parts and run the full test suite. Do not accept "the subagents agreed" as proof.

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

Keep the closing summary short and natural. Don't recap steps you already narrated — state the outcome and any next action the user needs.

# Context7
<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and the user's question, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and the user's full question (not single words)
4. Answer using the fetched docs
<!-- context7 -->
