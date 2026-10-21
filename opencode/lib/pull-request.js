// Pull request of a directory's current branch, read through `gh pr view`.

const KINDS = { OPEN: "open", MERGED: "merged", CLOSED: "closed" };
const SYMBOLS = { open: "●", draft: "◌", merged: "✓", closed: "✗" };

export const PR_FIELDS = "number,state,isDraft,url";

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
  return (directory) => {
    const hit = cache.get(directory);
    if (hit && clock() - hit.at < ttl) return hit.result;
    const result = run(directory).then(parsePullRequest, () => undefined);
    cache.set(directory, { at: clock(), result });
    return result;
  };
}
