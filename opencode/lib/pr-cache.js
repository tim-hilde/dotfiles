// Shared pull request data for the dashboard (`prs`) and the OpenCode pr sidebar.
// One small file per pull request. The dashboard writes what it fetches, and the sidebar reads it before it runs gh itself.

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

const KINDS = new Set(["open", "draft", "merged", "closed"])
const CI_STATES = new Set(["success", "failure", "pending", "none"])
const REVIEW_STATES = new Set(["approved", "comments", "changes", "stale", "none"])

export const PR_CACHE_TTL_MS = 60_000

export function sharedCacheBase() {
  return join(process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"), "pr-data")
}

export function pullRequestRef(url) {
  const match = /^https:\/\/github\.com\/([\w.-]+)\/([\w.-]+)\/pull\/(\d+)$/.exec(url ?? "")
  if (!match) return undefined
  return { owner: match[1], repo: match[2], number: Number(match[3]) }
}

export function sharedPullRequestPath(url, base = sharedCacheBase()) {
  const ref = pullRequestRef(url)
  if (!ref) return undefined
  return join(base, `${ref.owner}__${ref.repo}__${ref.number}.json`)
}

function isPullRequest(value) {
  return (
    typeof value === "object" &&
    value !== null &&
    Number.isInteger(value.number) &&
    typeof value.title === "string" &&
    typeof value.url === "string" &&
    KINDS.has(value.kind) &&
    CI_STATES.has(value.ci) &&
    REVIEW_STATES.has(value.review)
  )
}

export function readSharedPullRequest(url, now = Date.now(), ttlMs = PR_CACHE_TTL_MS, base = sharedCacheBase()) {
  const path = sharedPullRequestPath(url, base)
  if (!path) return undefined
  try {
    const record = JSON.parse(readFileSync(path, "utf8"))
    const fetchedAt = Date.parse(record?.fetchedAt ?? "")
    if (record?.version !== 1 || !Number.isFinite(fetchedAt) || now - fetchedAt >= ttlMs) return undefined
    if (!isPullRequest(record.pr) || record.pr.url !== url) return undefined
    return record.pr
  } catch {
    return undefined
  }
}

export function writeSharedPullRequest(pr, now = Date.now(), base = sharedCacheBase()) {
  if (!isPullRequest(pr)) return false
  const path = sharedPullRequestPath(pr.url, base)
  if (!path) return false
  try {
    mkdirSync(dirname(path), { recursive: true, mode: 0o700 })
    const temporary = `${path}.${process.pid}.tmp`
    writeFileSync(temporary, JSON.stringify({ version: 1, fetchedAt: new Date(now).toISOString(), pr }), {
      mode: 0o600,
    })
    renameSync(temporary, path)
    return true
  } catch {
    return false
  }
}

export const sharedCache = {
  read: (url, now, ttlMs) => readSharedPullRequest(url, now, ttlMs),
  write: (pr, now) => writeSharedPullRequest(pr, now),
}
