---
name: langfuse-trace-debug
description: Drive a single Langfuse trace to a root cause without flooding context. Use when debugging one specific call/request from a Langfuse trace or session URL — finding why a latency spike, timeout, error span, or unexpected output happened, and mapping the suspect span back to source code. Triggers include "debug this trace", "root cause", "langfuse trace", "latency debugging", "timeout debugging", "why did this call fail".
---

# Langfuse Trace Debugging

A focused workflow for taking ONE trace from a Langfuse URL to a root cause and a source-code location — without pulling raw trace JSON into context.

This skill is the **workflow**. For the *how* of authentication and API/CLI access, defer to the `langfuse` skill and the project's own docs — do not reinvent credential handling here.

## Core principle

**Raw trace JSON never enters the conversation.** A single trace can be hundreds of KB of observations. Fetch it to disk or pipe it through the sandbox, extract only the suspect spans, and reason over the summary. (Same discipline as the global "Read to Edit, Code to Analyze" rule.)

## Workflow

### 1. Extract the identifiers from the URL

A Langfuse URL carries what you need:
- `peek=<TRACE_ID>` → the trace ID
- `filter=...sessionId...contains%3B<SESSION_ID>` → the session ID

If the user pasted a URL, parse it; if they gave a bare ID, use it directly.

### 2. Fetch the trace + observations (defer to `langfuse` skill)

Use the `langfuse` skill / `langfuse-cli` (or the project's documented fetch flow) to retrieve:
- the trace metadata (start timestamp, status, total latency)
- all observations for the trace (paginated — large calls span multiple pages)

**Write the output to a file, do not print it into context.** For example, redirect the CLI/API output to a temp file under the sandbox temp dir.

### 3. Parse in the sandbox, surface only the suspects

Run code over the fetched JSON (`ctx_execute_file` / `ctx_execute`) and print ONLY:
- spans with a non-OK status or a `status_message`
- the slowest N observations (latency outliers vs. the trace median)
- any `level: ERROR`/`WARNING` events and their messages
- the observation `type` breakdown (GENERATION / TOOL / SPAN) so you know the call shape

Example shape (adapt field names to the actual schema you fetched):

```javascript
const obs = JSON.parse(FILE_CONTENT).data ?? JSON.parse(FILE_CONTENT);
const errs = obs.filter(o => o.level === "ERROR" || o.statusMessage);
const slow = [...obs].sort((a,b) => (b.latency??0)-(a.latency??0)).slice(0,5);
console.log("errors:", errs.map(e => `${e.name}: ${e.statusMessage ?? e.level}`));
console.log("slowest:", slow.map(s => `${s.name} ${Math.round(s.latency??0)}ms`));
```

### 4. Consult the project's failure map, if one exists

Many projects document recurring infra/vendor failure signatures (timeout patterns, dependency quirks, pinned-version gotchas) in their `AGENTS.md` / `CLAUDE.md` or an ADR. If the project documents such a map, match your extracted symptom against it before guessing. Do not assume one exists — check, then proceed.

### 5. Map the suspect span to source

Take the suspect span's `name` (often a function/tool/operation name) and locate it in the codebase (`grep`, or dispatch an `explore` subagent for a wider search). Identify the file and the failing code path.

### 6. Triage: code vs. external infra

End with an explicit split — this is the deliverable:
- **In our control (code):** what we can fix, where, how.
- **External / vendor / infra:** timeouts, deprecations, rate limits, upstream outages — surface them as their own bucket so they are not silently absorbed into an implementation task.

Never let an unresolved infra symptom slide into "let me just patch the code around it" without naming it as infra first.

## What this skill does NOT do

- It does not handle Langfuse auth, CLI install, or generic API usage → that's the `langfuse` skill.
- It does not define project-specific failure signatures → those live in the project's own docs.
- It does not instrument code or migrate prompts → see the `langfuse` skill's references.
