import { test } from "node:test"
import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import {
  PR_CACHE_TTL_MS,
  readSharedPullRequest,
  sharedPullRequestPath,
  writeSharedPullRequest,
} from "./pr-cache.js"

const URL_A = "https://github.com/o/r/pull/482"
const PR = {
  number: 482,
  title: "Fix retry loop",
  url: URL_A,
  kind: "open",
  closedAt: null,
  ci: "failure",
  review: "changes",
}
const NOW = Date.parse("2026-11-09T12:00:00Z")

const withBase = (run) => {
  const base = mkdtempSync(join(tmpdir(), "pr-data-"))
  try {
    run(base)
  } finally {
    rmSync(base, { recursive: true, force: true })
  }
}

test("maps a pull request url to one file per pull request", () => {
  assert.equal(sharedPullRequestPath(URL_A, "/base"), "/base/o__r__482.json")
  assert.equal(sharedPullRequestPath("https://github.com/o/r/issues/9", "/base"), undefined)
  assert.equal(sharedPullRequestPath("https://github.com/o/r/pull/abc", "/base"), undefined)
  assert.equal(sharedPullRequestPath(undefined, "/base"), undefined)
})

test("writes and reads a pull request", () =>
  withBase((base) => {
    assert.equal(writeSharedPullRequest(PR, NOW, base), true)
    assert.deepEqual(readSharedPullRequest(URL_A, NOW + 1_000, PR_CACHE_TTL_MS, base), PR)
    const record = JSON.parse(readFileSync(join(base, "o__r__482.json"), "utf8"))
    assert.equal(record.version, 1)
    assert.equal(record.fetchedAt, new Date(NOW).toISOString())
  }))

test("ignores a pull request once it is older than the cache time", () =>
  withBase((base) => {
    writeSharedPullRequest(PR, NOW, base)
    assert.equal(readSharedPullRequest(URL_A, NOW + PR_CACHE_TTL_MS - 1, PR_CACHE_TTL_MS, base)?.number, 482)
    assert.equal(readSharedPullRequest(URL_A, NOW + PR_CACHE_TTL_MS, PR_CACHE_TTL_MS, base), undefined)
  }))

test("ignores a missing, broken, or foreign file", () =>
  withBase((base) => {
    assert.equal(readSharedPullRequest(URL_A, NOW, PR_CACHE_TTL_MS, base), undefined)
    writeFileSync(join(base, "o__r__482.json"), "not json")
    assert.equal(readSharedPullRequest(URL_A, NOW, PR_CACHE_TTL_MS, base), undefined)
    writeFileSync(
      join(base, "o__r__482.json"),
      JSON.stringify({ version: 1, fetchedAt: new Date(NOW).toISOString(), pr: { ...PR, url: "https://github.com/o/r/pull/1" } }),
    )
    assert.equal(readSharedPullRequest(URL_A, NOW, PR_CACHE_TTL_MS, base), undefined)
  }))

test("ignores a record with an unknown state", () =>
  withBase((base) => {
    writeFileSync(
      join(base, "o__r__482.json"),
      JSON.stringify({ version: 1, fetchedAt: new Date(NOW).toISOString(), pr: { ...PR, ci: "green" } }),
    )
    assert.equal(readSharedPullRequest(URL_A, NOW, PR_CACHE_TTL_MS, base), undefined)
    writeFileSync(
      join(base, "o__r__482.json"),
      JSON.stringify({ version: 1, fetchedAt: new Date(NOW).toISOString(), pr: { ...PR, kind: "weird" } }),
    )
    assert.equal(readSharedPullRequest(URL_A, NOW, PR_CACHE_TTL_MS, base), undefined)
  }))

test("refuses to write a pull request with an unknown state or a foreign url", () =>
  withBase((base) => {
    assert.equal(writeSharedPullRequest({ ...PR, review: "maybe" }, NOW, base), false)
    assert.equal(writeSharedPullRequest({ ...PR, url: "https://example.test/pull/1" }, NOW, base), false)
    assert.equal(writeSharedPullRequest(null, NOW, base), false)
  }))
