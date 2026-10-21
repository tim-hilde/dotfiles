// Run: node --test lib/pull-request.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  findPullRequestUrl,
  findPullRequestUrlInHistory,
  parsePullRequest,
  pullRequestFetcher,
  pullRequestSymbol,
} from "./pull-request.js";

const gh = (overrides) =>
  JSON.stringify({ number: 482, state: "OPEN", isDraft: false, url: "https://github.com/o/r/pull/482", ...overrides });

const text = (value) => ({ type: "text", text: value });
const assistant = (...content) => ({ type: "assistant", content });
const shell = (command, output) => ({
  type: "tool",
  name: "shell",
  state: { status: "completed", input: { command }, content: [text(output)] },
});

test("finds a pull request URL named in an assistant text", () => {
  const messages = [assistant(text("Der PR ist offen: https://github.com/o/r/pull/842 gegen staging."))];
  assert.equal(findPullRequestUrl(messages), "https://github.com/o/r/pull/842");
});

test("finds the pull request URL printed by gh pr create", () => {
  const messages = [assistant(shell("gh pr create --base staging 2>&1 | tail -2", "https://github.com/o/r/pull/7\n"))];
  assert.equal(findPullRequestUrl(messages), "https://github.com/o/r/pull/7");
});

test("the most recently named pull request wins", () => {
  const messages = [
    assistant(text("Siehe https://github.com/o/r/pull/1")),
    assistant(text("Neu: https://github.com/o/r/pull/2")),
    assistant(text("Fertig.")),
  ];
  assert.equal(findPullRequestUrl(messages), "https://github.com/o/r/pull/2");
});

test("ignores user messages, tool input, and output of other commands", () => {
  const messages = [
    { type: "user", text: "Schau auf https://github.com/o/r/pull/3" },
    assistant(shell("gh pr list", "https://github.com/o/r/pull/4")),
    assistant(shell("echo https://github.com/o/r/pull/5", "ok")),
  ];
  assert.equal(findPullRequestUrl(messages), undefined);
});

test("ignores URLs that are not pull requests and messages without content", () => {
  const messages = [
    assistant(text("https://github.com/o/r/issues/9 und https://github.com/o/r/pull/abc")),
    { type: "assistant" },
    { type: "compaction" },
  ];
  assert.equal(findPullRequestUrl(messages), undefined);
});

const pager = (pages) => {
  const requests = [];
  const listPage = async (cursor) => {
    requests.push(cursor);
    const index = cursor ? Number(cursor) : 0;
    return { data: pages[index], cursor: { next: index + 1 < pages.length ? String(index + 1) : undefined } };
  };
  return { listPage, requests };
};
const named = (url) => assistant(text(`PR: ${url}`));

test("history search reads pages newest first and stops at the first match", async () => {
  const { listPage, requests } = pager([
    [named("https://github.com/o/r/pull/3"), assistant(text("ok"))].toReversed(),
    [named("https://github.com/o/r/pull/2")].toReversed(),
    [named("https://github.com/o/r/pull/1")],
  ]);
  assert.equal(await findPullRequestUrlInHistory(listPage), "https://github.com/o/r/pull/3");
  assert.deepEqual(requests, [undefined]);
});

test("history search continues to older pages when a page has no match", async () => {
  const { listPage, requests } = pager([[assistant(text("ok"))], [named("https://github.com/o/r/pull/1")], []]);
  assert.equal(await findPullRequestUrlInHistory(listPage), "https://github.com/o/r/pull/1");
  assert.deepEqual(requests, [undefined, "1"]);
});

test("history search gives up after the page limit and at the end of the history", async () => {
  const empty = [assistant(text("ok"))];
  const limited = pager([empty, empty, empty, empty]);
  assert.equal(await findPullRequestUrlInHistory(limited.listPage, 2), undefined);
  assert.equal(limited.requests.length, 2);
  const short = pager([empty]);
  assert.equal(await findPullRequestUrlInHistory(short.listPage), undefined);
  assert.equal(short.requests.length, 1);
});

test("history search returns undefined when reading a page fails", async () => {
  const listPage = async () => {
    throw new Error("offline");
  };
  assert.equal(await findPullRequestUrlInHistory(listPage), undefined);
});

test("parses an open pull request", () => {
  assert.deepEqual(parsePullRequest(gh()), { number: 482, url: "https://github.com/o/r/pull/482", kind: "open" });
});

test("parses draft, merged, and closed pull requests", () => {
  assert.equal(parsePullRequest(gh({ isDraft: true }))?.kind, "draft");
  assert.equal(parsePullRequest(gh({ state: "MERGED" }))?.kind, "merged");
  assert.equal(parsePullRequest(gh({ state: "CLOSED" }))?.kind, "closed");
});

test("a merged pull request that was a draft is merged", () => {
  assert.equal(parsePullRequest(gh({ state: "MERGED", isDraft: true }))?.kind, "merged");
});

test("returns undefined for empty, invalid, or unknown output", () => {
  assert.equal(parsePullRequest(""), undefined);
  assert.equal(parsePullRequest("not json"), undefined);
  assert.equal(parsePullRequest(gh({ state: "WEIRD" })), undefined);
  assert.equal(parsePullRequest(gh({ number: undefined })), undefined);
});

test("symbols distinguish the four kinds", () => {
  const symbols = ["open", "draft", "merged", "closed"].map(pullRequestSymbol);
  assert.deepEqual(symbols, ["●", "◌", "✓", "✗"]);
});

test("fetcher runs gh once per URL within the cache time", async () => {
  let now = 0;
  const calls = [];
  const fetchPr = pullRequestFetcher(async (url) => (calls.push(url), gh()), 60_000, () => now);
  const first = await fetchPr("/a");
  now = 59_000;
  const second = await fetchPr("/a");
  await fetchPr("/b");
  assert.deepEqual(calls, ["/a", "/b"]);
  assert.equal(first, second);
});

test("fetcher runs gh again after the cache time", async () => {
  let now = 0;
  let calls = 0;
  const fetchPr = pullRequestFetcher(async () => (calls++, gh()), 60_000, () => now);
  await fetchPr("/a");
  now = 60_000;
  await fetchPr("/a");
  assert.equal(calls, 2);
});

test("fetcher returns undefined when gh fails", async () => {
  const fetchPr = pullRequestFetcher(async () => {
    throw new Error("no pull requests found for branch");
  });
  assert.equal(await fetchPr("/a"), undefined);
});
