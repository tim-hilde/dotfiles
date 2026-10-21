// Pull request named in a session's chat, with its state read through `gh pr view`.

const KINDS = { OPEN: "open", MERGED: "merged", CLOSED: "closed" };
const SYMBOLS = { open: "●", draft: "◌", merged: "✓", closed: "✗" };
const PR_URL = /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/\d+/g;

export const PR_FIELDS = "number,state,isDraft,url";

export const MAX_PULL_REQUESTS = 5;

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
