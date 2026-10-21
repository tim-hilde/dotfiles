// Pull request named in a session's chat, with its state read through `gh pr view`.

const KINDS = { OPEN: "open", MERGED: "merged", CLOSED: "closed" };
const SYMBOLS = { open: "●", draft: "◌", merged: "✓", closed: "✗" };
const PR_URL = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+/g;

export const PR_FIELDS = "number,state,isDraft,url";

function lastUrl(value) {
  if (typeof value !== "string" || !value.includes("/pull/")) return undefined;
  return value.match(PR_URL)?.at(-1);
}

function partUrl(part) {
  if (part.type === "text") return lastUrl(part.text);
  if (part.type !== "tool" || !part.state?.input?.command?.includes("gh pr create")) return undefined;
  return (part.state.content ?? []).map((item) => lastUrl(item.text)).findLast(Boolean);
}

export function findPullRequestUrl(messages) {
  for (const message of messages.toReversed()) {
    if (message.type !== "assistant") continue;
    const url = (message.content ?? []).map(partUrl).findLast(Boolean);
    if (url) return url;
  }
  return undefined;
}

export async function findPullRequestUrlInHistory(listPage, maxPages = 10) {
  try {
    let cursor;
    for (let page = 0; page < maxPages; page++) {
      const { data, cursor: next } = await listPage(cursor);
      const url = findPullRequestUrl(data.toReversed());
      if (url) return url;
      cursor = next?.next;
      if (!cursor) return undefined;
    }
  } catch {
    return undefined;
  }
  return undefined;
}

export function parsePullRequest(stdout) {
  let data;
  try {
    data = JSON.parse(stdout);
  } catch {
    return undefined;
  }
  const kind = data?.state === "OPEN" && data.isDraft ? "draft" : KINDS[data?.state];
  if (!kind || !Number.isInteger(data.number) || typeof data.url !== "string") return undefined;
  return { number: data.number, url: data.url, kind };
}

export function pullRequestSymbol(kind) {
  return SYMBOLS[kind];
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
