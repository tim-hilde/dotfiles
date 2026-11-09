// Pull request named in a session's chat, with its state read through one `gh api graphql` request.

import { sharedCache, PR_CACHE_TTL_MS, pullRequestRef } from "./pr-cache.js"

const KINDS = { OPEN: "open", MERGED: "merged", CLOSED: "closed" };
const SYMBOLS = { open: "\uf407", draft: "\uf4dd", merged: "\uf419", closed: "\uf4dc" };
const TONES = { open: "success", draft: "muted", merged: "info", closed: "error" };
const CI_SYMBOLS = { success: "✓", failure: "✗", pending: "…", none: "–" };
const CI_TONES = { success: "success", failure: "error", pending: "warning", none: "muted" };
const REVIEW_SYMBOLS = { approved: "✓", comments: "!", changes: "✗", stale: "~", none: "–" };
const REVIEW_TONES = { approved: "success", comments: "warning", changes: "error", stale: "warning", none: "muted" };
const PR_URL = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+/g;
const CODEX_MARKER = "<!-- codex-review -->";
const CODEX_AUTHOR = "github-actions";

// One request per pull request. The CI state comes from the checks of the head commit, like the dashboard (`mapCi` in pr-dashboard/src/ci.ts).
export const PR_QUERY = `query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { pullRequest(number: $number) { number title state isDraft url closedAt comments(last: 100) { nodes { body url createdAt author { login } } } commits(last: 1) { nodes { commit { committedDate statusCheckRollup { state contexts(first: 100) { pageInfo { hasNextPage } nodes { __typename ... on CheckRun { name status conclusion startedAt checkSuite { workflowRun { event workflow { name } } } } ... on StatusContext { context state createdAt } } } } } } } } } }`;

export function pullRequestQueryArgs(url) {
  const ref = pullRequestRef(url);
  if (!ref) return undefined;
  return ["api", "graphql", "-f", `query=${PR_QUERY}`, "-f", `owner=${ref.owner}`, "-f", `repo=${ref.repo}`, "-F", `number=${ref.number}`];
}

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

const PASSED_CONCLUSIONS = new Set(["SUCCESS", "NEUTRAL", "SKIPPED"]);
const FAILED_CONTEXT_STATES = new Set(["FAILURE", "ERROR"]);
const PENDING_CONTEXT_STATES = new Set(["PENDING", "EXPECTED"]);

// A check without a start time is unfinished, so it is newer than any finished check.
const startedAt = (node) => {
  const time = Date.parse(node.startedAt ?? node.createdAt ?? "");
  if (time > 0) return time;
  return node.status != null && node.status !== "COMPLETED" ? Infinity : 0;
};

// GitHub's own overall state, used when the check list is missing or cut off by the page size.
function ciFromAggregate(state) {
  if (state === null || state === undefined) return "none";
  if (state === "SUCCESS") return "success";
  if (state === "FAILURE" || state === "ERROR") return "failure";
  return "pending";
}

// GitHub lists every run on the head commit, so a re-run check appears more than once. Only the newest run counts.
function newestChecks(nodes) {
  const newest = new Map();
  for (const node of nodes) {
    const suite = node.checkSuite?.workflowRun;
    const key =
      node.__typename === "StatusContext"
        ? `context:${node.context}`
        : `run:${suite?.event ?? ""}:${suite?.workflow?.name ?? ""}:${node.name}`;
    const seen = newest.get(key);
    if (!seen || startedAt(node) >= startedAt(seen)) newest.set(key, node);
  }
  return [...newest.values()];
}

// A check that still runs keeps the pull request yellow, even when another one already failed.
export function ciState(rollup) {
  const contexts = rollup?.contexts;
  const nodes = contexts?.nodes ?? [];
  if (nodes.length === 0 || contexts?.pageInfo?.hasNextPage) return ciFromAggregate(rollup?.state);
  const newest = newestChecks(nodes);
  if (newest.some(running)) return "pending";
  return newest.some(failed) ? "failure" : "success";
}

function running(node) {
  return node.__typename === "StatusContext"
    ? PENDING_CONTEXT_STATES.has(node.state)
    : node.status != null && node.status !== "COMPLETED";
}

function failed(node) {
  return node.__typename === "StatusContext"
    ? FAILED_CONTEXT_STATES.has(node.state)
    : !PASSED_CONCLUSIONS.has(node.conclusion);
}

function verdictSection(body) {
  const lines = body.split("\n");
  const start = lines.findIndex((line) => line.trim() === "## Verdict");
  if (start === -1) return "";
  const end = lines.findIndex((line, index) => index > start && line.startsWith("## "));
  // Some comments list all three options as a checklist and tick one; the unticked options do not count.
  return lines
    .slice(start + 1, end === -1 ? undefined : end)
    .filter((line) => !line.includes("[ ]"))
    .join("\n");
}

export function codexReviewState(comments, headCommittedAt) {
  const reviews = (Array.isArray(comments) ? comments : []).filter(
    (comment) => comment.author?.login === CODEX_AUTHOR && comment.body?.includes(CODEX_MARKER),
  );
  if (reviews.length === 0) return "none";
  const latest = reviews.reduce((a, b) => (Date.parse(b.createdAt) >= Date.parse(a.createdAt) ? b : a));
  const verdict = verdictSection(latest.body);
  const named = [
    ["changes", verdict.indexOf("Request Changes")],
    ["approved", verdict.indexOf("Approve")],
    ["comments", verdict.indexOf("Comment")],
  ].filter(([, index]) => index !== -1);
  const state = named.length === 0 ? "none" : named.reduce((a, b) => (b[1] < a[1] ? b : a))[0];
  const head = Date.parse(headCommittedAt ?? "");
  const written = Date.parse(latest.createdAt);
  return !Number.isNaN(head) && !Number.isNaN(written) && written < head ? "stale" : state;
}

export function parsePullRequest(stdout) {
  let data;
  try {
    data = JSON.parse(stdout)?.data?.repository?.pullRequest;
  } catch {
    return undefined;
  }
  const kind = data?.state === "OPEN" && data.isDraft ? "draft" : KINDS[data?.state];
  if (!kind || !Number.isInteger(data.number) || typeof data.title !== "string" || typeof data.url !== "string") {
    return undefined;
  }
  const head = data.commits?.nodes?.at(-1)?.commit;
  return {
    number: data.number,
    title: data.title,
    url: data.url,
    kind,
    closedAt: data.closedAt ?? null,
    ci: ciState(head?.statusCheckRollup),
    review: codexReviewState(data.comments?.nodes, head?.committedDate),
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

export function pullRequestFetcher(run, ttl = PR_CACHE_TTL_MS, clock = Date.now, shared = sharedCache) {
  const cache = new Map();
  return (url) => {
    const hit = cache.get(url);
    if (hit && clock() - hit.at < ttl) return hit.result;
    let stored;
    try {
      stored = shared.read(url, clock(), ttl);
    } catch {}
    // A hit from the shared file is not pinned in memory: the file is the clock, so the next call reads it again.
    if (stored) return Promise.resolve(stored);
    const result = run(url)
      .then(parsePullRequest, () => undefined)
      .then((pr) => {
        if (pr) {
          try {
            shared.write(pr, clock());
          } catch {}
        }
        return pr;
      });
    cache.set(url, { at: clock(), result });
    return result;
  };
}
