// Pull request named in a session's chat, with its state read through `gh pr view`.

const KINDS = { OPEN: "open", MERGED: "merged", CLOSED: "closed" };
const SYMBOLS = { open: "\uf407", draft: "\uf4dd", merged: "\uf419", closed: "\uf4dc" };
const TONES = { open: "success", draft: "muted", merged: "info", closed: "error" };
const CI_SYMBOLS = { success: "✓", failure: "✗", pending: "…", none: "–" };
const CI_TONES = { success: "success", failure: "error", pending: "warning", none: "muted" };
const REVIEW_SYMBOLS = { approved: "✓", comments: "!", changes: "✗", stale: "~", none: "–" };
const REVIEW_TONES = { approved: "success", comments: "warning", changes: "error", stale: "warning", none: "muted" };
const PR_URL = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+/g;
const FAILED_CONCLUSIONS = new Set(["FAILURE", "TIMED_OUT", "CANCELLED"]);
const FAILED_CONTEXT_STATES = new Set(["FAILURE", "ERROR"]);
const PENDING_CONTEXT_STATES = new Set(["PENDING", "EXPECTED"]);
const CODEX_MARKER = "<!-- codex-review -->";
const CODEX_AUTHOR = "github-actions";

export const PR_FIELDS = "number,title,state,isDraft,url,closedAt,statusCheckRollup,comments,commits";

export const MAX_PULL_REQUESTS = 10;

const CLOSED_VISIBLE_MS = 2 * 24 * 60 * 60 * 1000;

function textUrls(value) {
  if (typeof value !== "string" || !value.includes("/pull/")) return [];
  return value.match(PR_URL) ?? [];
}

function partUrls(part) {
  if (part.type === "text") return textUrls(part.text);
  if (part.type !== "tool" || !part.state?.input?.command?.includes("gh pr create")) return [];
  return (part.state.content ?? []).flatMap((item) => textUrls(item.text));
}

function collectUrls(messages) {
  return messages.flatMap((message) => (message.type === "assistant" ? (message.content ?? []).flatMap(partUrls) : []));
}

export function mergePullRequestUrls(urls, limit = MAX_PULL_REQUESTS) {
  const latestFirst = [];
  for (const url of urls.toReversed()) if (!latestFirst.includes(url)) latestFirst.push(url);
  return latestFirst.slice(0, limit).toReversed();
}

export function findPullRequestUrls(messages, limit = MAX_PULL_REQUESTS) {
  return mergePullRequestUrls(collectUrls(messages), limit);
}

export async function findPullRequestUrlsInHistory(listPage, limit = MAX_PULL_REQUESTS, maxPages = 10) {
  let found = [];
  try {
    let cursor;
    for (let page = 0; page < maxPages; page++) {
      const { data, cursor: next } = await listPage(cursor);
      found = [...collectUrls(data.toReversed()), ...found];
      cursor = next?.next;
      if (!cursor || mergePullRequestUrls(found, Infinity).length >= limit) break;
    }
  } catch {}
  return mergePullRequestUrls(found, limit);
}

export function ciState(rollup) {
  if (!Array.isArray(rollup) || rollup.length === 0) return "none";
  let pending = false;
  for (const check of rollup) {
    if (check.__typename === "StatusContext") {
      if (FAILED_CONTEXT_STATES.has(check.state)) return "failure";
      if (PENDING_CONTEXT_STATES.has(check.state)) pending = true;
    } else {
      if (FAILED_CONCLUSIONS.has(check.conclusion)) return "failure";
      if (check.status !== "COMPLETED") pending = true;
    }
  }
  return pending ? "pending" : "success";
}

function verdictSection(body) {
  const lines = body.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## Verdict");
  if (start === -1) return "";
  const end = lines.findIndex((line, index) => index > start && line.startsWith("## "));
  return lines.slice(start + 1, end === -1 ? undefined : end).join("\n");
}

export function codexReviewState(comments, headCommittedAt) {
  const reviews = (Array.isArray(comments) ? comments : []).filter(
    (comment) => comment.author?.login === CODEX_AUTHOR && comment.body?.includes(CODEX_MARKER),
  );
  if (reviews.length === 0) return "none";
  const latest = reviews.reduce((a, b) => (Date.parse(b.createdAt) >= Date.parse(a.createdAt) ? b : a));
  const verdict = verdictSection(latest.body);
  let state = "none";
  if (verdict.includes("Request Changes")) state = "changes";
  else if (verdict.includes("Approve")) state = "approved";
  else if (verdict.includes("Comment")) state = "comments";
  const head = Date.parse(headCommittedAt ?? "");
  const written = Date.parse(latest.createdAt);
  return !Number.isNaN(head) && !Number.isNaN(written) && written < head ? "stale" : state;
}

export function parsePullRequest(stdout) {
  let data;
  try {
    data = JSON.parse(stdout);
  } catch {
    return undefined;
  }
  const kind = data?.state === "OPEN" && data.isDraft ? "draft" : KINDS[data?.state];
  if (!kind || !Number.isInteger(data.number) || typeof data.title !== "string" || typeof data.url !== "string") {
    return undefined;
  }
  const headCommittedAt = data.commits?.at(-1)?.committedDate;
  return {
    number: data.number,
    title: data.title,
    url: data.url,
    kind,
    closedAt: data.closedAt ?? null,
    ci: ciState(data.statusCheckRollup),
    review: codexReviewState(data.comments, headCommittedAt),
  };
}

export function showsChecks(pr) {
  return pr.kind === "open" || pr.kind === "draft";
}

export function isPullRequestVisible(pr, now = Date.now()) {
  if (pr.kind === "open" || pr.kind === "draft") return true;
  const closedAt = Date.parse(pr.closedAt ?? "");
  return Number.isNaN(closedAt) || now - closedAt <= CLOSED_VISIBLE_MS;
}

export function truncateEnd(text, width) {
  if (width === undefined || text.length <= width) return text;
  if (width <= 0) return "";
  return `${text.slice(0, width - 1)}…`;
}

export function pullRequestSymbol(kind) {
  return SYMBOLS[kind];
}

export function pullRequestTone(kind) {
  return TONES[kind];
}

export function ciSymbol(state) {
  return CI_SYMBOLS[state];
}

export function ciTone(state) {
  return CI_TONES[state];
}

export function reviewSymbol(state) {
  return REVIEW_SYMBOLS[state];
}

export function reviewTone(state) {
  return REVIEW_TONES[state];
}

export function pullRequestFetcher(run, ttl = 60_000, clock = Date.now) {
  const cache = new Map();
  return (url) => {
    const hit = cache.get(url);
    if (hit && clock() - hit.at < ttl) return hit.result;
    const result = run(url).then(parsePullRequest, () => undefined);
    cache.set(url, { at: clock(), result });
    return result;
  };
}
