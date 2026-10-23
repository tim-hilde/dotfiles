// Run: node --test lib/pull-request.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  findPullRequestUrls,
  findPullRequestUrlsInHistory,
  mergePullRequestUrls,
  parsePullRequest,
  pullRequestFetcher,
  pullRequestSymbol,
  truncateEnd,
} from "./pull-request.js";

const gh = (overrides) =>
  JSON.stringify({
    number: 482,
    title: "Fix retry loop",
    state: "OPEN",
    isDraft: false,
    url: "https://github.com/o/r/pull/482",
    ...overrides,
  });

const url = (number) => `https://github.com/o/r/pull/${number}`;
const text = (value) => ({ type: "text", text: value });
const assistant = (...content) => ({ type: "assistant", content });
const named = (number) => assistant(text(`PR: ${url(number)}`));
const shell = (command, output) => ({
  type: "tool",
  name: "shell",
  state: { status: "completed", input: { command }, content: [text(output)] },
});

test("finds a pull request URL named in an assistant text", () => {
  const messages = [assistant(text(`Der PR ist offen: ${url(842)} gegen staging.`))];
  assert.deepEqual(findPullRequestUrls(messages), [url(842)]);
});

test("finds the pull request URL printed by gh pr create", () => {
  const messages = [assistant(shell("gh pr create --base staging 2>&1 | tail -2", `${url(7)}\n`))];
  assert.deepEqual(findPullRequestUrls(messages), [url(7)]);
});

test("finds several pull requests in the order of their last mention", () => {
  const messages = [named(1), assistant(text(`Neu: ${url(2)} und ${url(3)}`)), named(1), assistant(text("Fertig."))];
  assert.deepEqual(findPullRequestUrls(messages), [url(2), url(3), url(1)]);
});

test("keeps only the most recently named pull requests up to the limit", () => {
  const messages = [1, 2, 3, 4].map(named);
  assert.deepEqual(findPullRequestUrls(messages, 2), [url(3), url(4)]);
});

test("ignores user messages, tool input, and output of other commands", () => {
  const messages = [
    { type: "user", text: `Schau auf ${url(3)}` },
    assistant(shell("gh pr list", url(4))),
    assistant(shell(`echo ${url(5)}`, "ok")),
  ];
  assert.deepEqual(findPullRequestUrls(messages), []);
});

test("ignores URLs that are not pull requests and messages without content", () => {
  const messages = [
    assistant(text("https://github.com/o/r/issues/9 und https://github.com/o/r/pull/abc")),
    { type: "assistant" },
    { type: "compaction" },
  ];
  assert.deepEqual(findPullRequestUrls(messages), []);
});

test("merging keeps the last mention of each URL and the newest ones up to the limit", () => {
  assert.deepEqual(mergePullRequestUrls([url(1), url(2), url(1), url(3)], 2), [url(1), url(3)]);
  assert.deepEqual(mergePullRequestUrls([url(1), url(2), url(1)]), [url(2), url(1)]);
});

const pager = (pages) => {
  const requests = [];
  const listPage = async (cursor) => {
    requests.push(cursor);
    const index = cursor ? Number(cursor) : 0;
    return { data: pages[index].toReversed(), cursor: { next: index + 1 < pages.length ? String(index + 1) : undefined } };
  };
  return { listPage, requests };
};

test("history search collects pull requests across pages in chronological order", async () => {
  const { listPage, requests } = pager([[named(3), named(4)], [named(2)], [named(1)]]);
  assert.deepEqual(await findPullRequestUrlsInHistory(listPage, 3), [url(2), url(3), url(4)]);
  assert.deepEqual(requests, [undefined, "1"]);
});

test("history search gives up after the page limit and at the end of the history", async () => {
  const empty = [assistant(text("ok"))];
  const limited = pager([empty, empty, empty, empty]);
  assert.deepEqual(await findPullRequestUrlsInHistory(limited.listPage, 5, 2), []);
  assert.equal(limited.requests.length, 2);
  const short = pager([[named(1)]]);
  assert.deepEqual(await findPullRequestUrlsInHistory(short.listPage), [url(1)]);
  assert.equal(short.requests.length, 1);
});

test("history search returns what it found when reading a page fails", async () => {
  let calls = 0;
  const listPage = async () => {
    if (calls++ === 0) return { data: [named(1)], cursor: { next: "1" } };
    throw new Error("offline");
  };
  assert.deepEqual(await findPullRequestUrlsInHistory(listPage), [url(1)]);
});

test("parses an open pull request", () => {
  assert.deepEqual(parsePullRequest(gh()), {
    number: 482,
    title: "Fix retry loop",
    url: "https://github.com/o/r/pull/482",
    kind: "open",
  });
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
  assert.equal(parsePullRequest(gh({ title: undefined })), undefined);
});

test("truncateEnd keeps text that fits and cuts the end with an ellipsis otherwise", () => {
  assert.equal(truncateEnd("#12 Fix", 7), "#12 Fix");
  assert.equal(truncateEnd("#12 Fix retry loop", 10), "#12 Fix r…");
  assert.equal(truncateEnd("abc", 1), "…");
  assert.equal(truncateEnd("abc", 0), "");
  assert.equal(truncateEnd("abc", undefined), "abc");
});

test("symbols distinguish the four kinds", () => {
  const symbols = ["open", "draft", "merged", "closed"].map(pullRequestSymbol);
  assert.deepEqual(symbols, ["●", "◌", "✓", "✗"]);
});

test("fetcher runs gh once per URL within the cache time", async () => {
  let now = 0;
  const calls = [];
  const fetchPr = pullRequestFetcher(async (target) => (calls.push(target), gh()), 60_000, () => now);
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
