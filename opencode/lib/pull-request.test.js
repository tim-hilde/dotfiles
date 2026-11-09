// Run: node --test lib/pull-request.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ciState,
  ciSymbol,
  ciTone,
  codexReviewState,
  findPullRequestUrls,
  findPullRequestUrlsInHistory,
  isPullRequestVisible,
  mergePullRequestUrls,
  parsePullRequest,
  PR_FIELDS,
  pullRequestFetcher,
  pullRequestSymbol,
  pullRequestTone,
  reviewSymbol,
  reviewTone,
  showsChecks,
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
const noShared = { read: () => undefined, write: () => {} };
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

test("by default keeps the ten most recently named pull requests", () => {
  const messages = Array.from({ length: 12 }, (_, index) => named(index + 1));
  const urls = findPullRequestUrls(messages);
  assert.equal(urls.length, 10);
  assert.deepEqual([urls[0], urls.at(-1)], [url(3), url(12)]);
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
    closedAt: null,
    ci: "none",
    review: "none",
  });
});

let runs = 0;
const run = (conclusion, status = "COMPLETED") => ({ __typename: "CheckRun", name: `job-${runs++}`, status, conclusion });
const context = (state) => ({ __typename: "StatusContext", context: `ci/status-${runs++}`, state });

test("asks gh for the checks, the comments, and the commits", () => {
  for (const field of ["statusCheckRollup", "comments", "commits"]) assert.ok(PR_FIELDS.split(",").includes(field));
});

test("ciState is none without any check", () => {
  assert.equal(ciState([]), "none");
  assert.equal(ciState(undefined), "none");
  assert.equal(ciState(null), "none");
});

test("ciState is success when every check passed, was skipped, or was neutral", () => {
  assert.equal(ciState([run("SUCCESS"), run("SKIPPED"), run("NEUTRAL"), context("SUCCESS")]), "success");
});

test("ciState is failure when a check failed, timed out, was cancelled, or errored", () => {
  for (const check of [run("FAILURE"), run("TIMED_OUT"), run("CANCELLED"), context("FAILURE"), context("ERROR")]) {
    assert.equal(ciState([run("SUCCESS"), check]), "failure");
  }
});

test("ciState is pending while a check runs or waits", () => {
  for (const check of [run("", "IN_PROGRESS"), run("", "QUEUED"), run(null, "PENDING"), context("PENDING"), context("EXPECTED")]) {
    assert.equal(ciState([run("SUCCESS"), check]), "pending");
  }
});

test("ciState reports a failure even while other checks are pending", () => {
  assert.equal(ciState([run("FAILURE"), run("", "IN_PROGRESS")]), "failure");
});

test("ciState is failure for every finished check that did not pass", () => {
  for (const conclusion of ["ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"]) {
    assert.equal(ciState([run("SUCCESS"), run(conclusion)]), "failure");
  }
});

const check = (name, conclusion, startedAt, status = "COMPLETED", workflowName = name) => ({
  __typename: "CheckRun",
  name,
  workflowName,
  status,
  conclusion,
  startedAt,
});

test("ciState judges only the newest run of a re-run check", () => {
  const failed = check("migration-ok", "FAILURE", "2026-11-09T12:31:17Z");
  const passed = check("migration-ok", "SUCCESS", "2026-11-09T12:32:25Z");
  assert.equal(ciState([failed, passed]), "success");
  assert.equal(ciState([passed, failed]), "success");
});

test("ciState shows a failure when the newest run of a check failed", () => {
  const passed = check("tests", "SUCCESS", "2026-11-09T12:31:17Z");
  const failed = check("tests", "FAILURE", "2026-11-09T12:32:25Z");
  assert.equal(ciState([passed, failed]), "failure");
});

test("ciState is pending when a re-run replaced a failed run and still runs", () => {
  const failed = check("tests", "FAILURE", "2026-11-09T12:31:17Z");
  const running = check("tests", "", "2026-11-09T12:32:25Z", "IN_PROGRESS");
  assert.equal(ciState([failed, running]), "pending");
});

test("ciState is pending when a queued re-run has no start time yet", () => {
  const failed = check("tests", "FAILURE", "2026-11-09T12:31:17Z");
  const queued = check("tests", "", "0001-01-01T00:00:00Z", "QUEUED");
  assert.equal(ciState([failed, queued]), "pending");
  assert.equal(ciState([queued, failed]), "pending");
});

test("ciState keeps checks with the same name in different workflows apart", () => {
  const failed = check("build", "FAILURE", "2026-11-09T12:31:17Z", "COMPLETED", "ci");
  const passed = check("build", "SUCCESS", "2026-11-09T12:32:25Z", "COMPLETED", "release");
  assert.equal(ciState([failed, passed]), "failure");
});

test("ciState judges only the newest status of a context", () => {
  const failed = { __typename: "StatusContext", context: "deploy", state: "FAILURE", startedAt: "2026-11-09T12:31:17Z" };
  const passed = { __typename: "StatusContext", context: "deploy", state: "SUCCESS", startedAt: "2026-11-09T12:32:25Z" };
  assert.equal(ciState([failed, passed]), "success");
});

const codex = (verdict, createdAt = "2026-11-06T10:30:00Z", overrides = {}) => ({
  author: { login: "github-actions" },
  createdAt,
  body: `<!-- codex-review -->\n## Summary\nText\n\n## Verdict\n${verdict}\n\n## Required Changes\nNone\n`,
  ...overrides,
});
const HEAD = "2026-11-06T10:00:00Z";

test("codexReviewState is none without a Codex comment", () => {
  assert.equal(codexReviewState([], HEAD), "none");
  assert.equal(codexReviewState(undefined, HEAD), "none");
});

test("codexReviewState reads the Verdict section in both forms", () => {
  assert.equal(codexReviewState([codex("- [x] 🔄 Request Changes — fix the race")], HEAD), "changes");
  assert.equal(codexReviewState([codex("**Request Changes** — fix the race")], HEAD), "changes");
  assert.equal(codexReviewState([codex("- [x] ✅ Approve")], HEAD), "approved");
  assert.equal(codexReviewState([codex("Approve with nits")], HEAD), "approved");
  assert.equal(codexReviewState([codex("- [x] 💬 Comment")], HEAD), "comments");
});

test("codexReviewState ignores the unticked options of a checklist verdict", () => {
  const checklist = (approve, comment, changes) =>
    codex(
      [
        `**[${approve}] ✅ Approve**  `,
        `**[${comment}] 💬 Comment**  `,
        `**[${changes}] 🔄 Request Changes** — text`,
      ].join("\n"),
    );
  assert.equal(codexReviewState([checklist("x", " ", " ")], HEAD), "approved");
  assert.equal(codexReviewState([checklist(" ", "x", " ")], HEAD), "comments");
  assert.equal(codexReviewState([checklist(" ", " ", "x")], HEAD), "changes");
  const list = codex("- [ ] ✅ Approve\n- [ ] 💬 Comment\n- [x] 🔄 **Request Changes** — text");
  assert.equal(codexReviewState([list], HEAD), "changes");
  const approved = codex("- [x] ✅ Approve\n- [ ] 💬 Comment\n- [ ] 🔄 **Request Changes**");
  assert.equal(codexReviewState([approved], HEAD), "approved");
});

test("codexReviewState takes the first option named in the verdict, not a later mention", () => {
  assert.equal(codexReviewState([codex("**💬 Comment** — No blockers. Approve after the nits.")], HEAD), "comments");
  assert.equal(codexReviewState([codex("**✅ Approve** — nothing here warrants Request Changes.")], HEAD), "approved");
  assert.equal(codexReviewState([codex("**🔄 Request Changes** — do not Approve yet.")], HEAD), "changes");
});

test("codexReviewState ignores comments of other authors and without the marker", () => {
  const quoted = codex("Approve", "2026-11-06T10:30:00Z", { author: { login: "tim-hilde" } });
  const plain = codex("Approve", "2026-11-06T10:30:00Z", { body: "## Verdict\nApprove" });
  assert.equal(codexReviewState([quoted, plain], HEAD), "none");
});

test("codexReviewState uses the newest Codex comment", () => {
  const older = codex("Request Changes", "2026-11-06T10:10:00Z");
  const newer = codex("Approve", "2026-11-06T10:40:00Z");
  assert.equal(codexReviewState([newer, older], HEAD), "approved");
});

test("codexReviewState is stale when a commit is newer than the review", () => {
  assert.equal(codexReviewState([codex("Approve", "2026-11-06T09:00:00Z")], HEAD), "stale");
  assert.equal(codexReviewState([codex("Approve", "2026-11-06T09:00:00Z")], undefined), "approved");
});

test("parsePullRequest derives the CI and review state", () => {
  const pr = parsePullRequest(
    gh({
      statusCheckRollup: [run("FAILURE")],
      comments: [codex("Request Changes", "2026-11-06T10:30:00Z")],
      commits: [{ committedDate: "2026-11-06T09:00:00Z" }, { committedDate: HEAD }],
    }),
  );
  assert.equal(pr?.ci, "failure");
  assert.equal(pr?.review, "changes");
});

test("shows the checks only for open and draft pull requests", () => {
  assert.equal(showsChecks({ kind: "open" }), true);
  assert.equal(showsChecks({ kind: "draft" }), true);
  assert.equal(showsChecks({ kind: "merged" }), false);
  assert.equal(showsChecks({ kind: "closed" }), false);
});

test("parses draft, merged, and closed pull requests", () => {
  assert.equal(parsePullRequest(gh({ isDraft: true }))?.kind, "draft");
  assert.equal(parsePullRequest(gh({ state: "MERGED" }))?.kind, "merged");
  assert.equal(parsePullRequest(gh({ state: "CLOSED" }))?.kind, "closed");
});

test("keeps the close time of a closed pull request", () => {
  const closedAt = "2026-11-04T09:00:00Z";
  assert.equal(parsePullRequest(gh({ state: "MERGED", closedAt }))?.closedAt, closedAt);
});

const NOW = Date.parse("2026-11-06T12:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;
const closedAgo = (ms) => new Date(NOW - ms).toISOString();

test("hides merged and closed pull requests that closed more than two days ago", () => {
  for (const kind of ["merged", "closed"]) {
    assert.equal(isPullRequestVisible({ kind, closedAt: closedAgo(2 * DAY_MS + 1) }, NOW), false);
  }
});

test("keeps closed pull requests within the last two days", () => {
  assert.equal(isPullRequestVisible({ kind: "merged", closedAt: closedAgo(1 * DAY_MS) }, NOW), true);
  assert.equal(isPullRequestVisible({ kind: "closed", closedAt: closedAgo(2 * DAY_MS) }, NOW), true);
});

test("keeps open pull requests and closed pull requests without a valid close time", () => {
  assert.equal(isPullRequestVisible({ kind: "open", closedAt: null }, NOW), true);
  assert.equal(isPullRequestVisible({ kind: "draft", closedAt: null }, NOW), true);
  assert.equal(isPullRequestVisible({ kind: "closed", closedAt: null }, NOW), true);
  assert.equal(isPullRequestVisible({ kind: "merged", closedAt: "not a date" }, NOW), true);
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

test("symbols distinguish the four kinds with the GitHub pull request icons", () => {
  const symbols = ["open", "draft", "merged", "closed"].map(pullRequestSymbol);
  assert.deepEqual(symbols, ["\uf407", "\uf4dd", "\uf419", "\uf4dc"]);
});

test("CI and review symbols match the pr dashboard", () => {
  assert.deepEqual(["success", "failure", "pending", "none"].map(ciSymbol), ["✓", "✗", "…", "–"]);
  assert.deepEqual(
    ["approved", "comments", "changes", "stale", "none"].map(reviewSymbol),
    ["✓", "!", "✗", "~", "–"],
  );
});

test("tones follow the state", () => {
  assert.deepEqual(["open", "draft", "merged", "closed"].map(pullRequestTone), ["success", "muted", "info", "error"]);
  assert.deepEqual(["success", "failure", "pending", "none"].map(ciTone), ["success", "error", "warning", "muted"]);
  assert.deepEqual(
    ["approved", "comments", "changes", "stale", "none"].map(reviewTone),
    ["success", "warning", "error", "warning", "muted"],
  );
});

test("fetcher runs gh once per URL within the cache time", async () => {
  let now = 0;
  const calls = [];
  const fetchPr = pullRequestFetcher(async (target) => (calls.push(target), gh()), 60_000, () => now, noShared);
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
  const fetchPr = pullRequestFetcher(async () => (calls++, gh()), 60_000, () => now, noShared);
  await fetchPr("/a");
  now = 60_000;
  await fetchPr("/a");
  assert.equal(calls, 2);
});

test("fetcher returns undefined when gh fails", async () => {
  const fetchPr = pullRequestFetcher(
    async () => {
      throw new Error("no pull requests found for branch");
    },
    60_000,
    Date.now,
    noShared,
  );
  assert.equal(await fetchPr("/a"), undefined);
});

const shared = (stored) => ({
  reads: [],
  writes: [],
  read(url, now, ttl) {
    this.reads.push([url, now, ttl]);
    return typeof stored === "function" ? stored(now) : stored;
  },
  write(pr, now) {
    this.writes.push([pr, now]);
  },
});

test("fetcher reads the shared cache and does not run gh on a hit", async () => {
  let calls = 0;
  const store = shared({ number: 7, title: "cached", url: "/a", kind: "open", closedAt: null, ci: "success", review: "approved" });
  const fetchPr = pullRequestFetcher(async () => (calls++, gh()), 60_000, () => 0, store);
  assert.equal((await fetchPr("/a")).number, 7);
  assert.equal(calls, 0);
  assert.deepEqual(store.reads, [["/a", 0, 60_000]]);
});

test("fetcher reads the shared file again instead of pinning a hit in memory", async () => {
  let now = 0;
  let calls = 0;
  const pr = { number: 7, title: "cached", url: "/a", kind: "open", closedAt: null, ci: "success", review: "approved" };
  const store = shared((at) => (at < 60_000 ? pr : undefined));
  const fetchPr = pullRequestFetcher(async () => (calls++, gh()), 60_000, () => now, store);
  assert.equal((await fetchPr("/a")).number, 7);
  now = 59_999;
  assert.equal((await fetchPr("/a")).number, 7);
  assert.equal(calls, 0);
  now = 60_000;
  assert.equal((await fetchPr("/a")).number, 482);
  assert.equal(calls, 1);
});

test("fetcher writes a fetched pull request to the shared cache", async () => {
  let now = 0;
  const store = shared(undefined);
  const fetchPr = pullRequestFetcher(async () => gh(), 60_000, () => now, store);
  await fetchPr("/a");
  assert.equal(store.writes.length, 1);
  assert.equal(store.writes[0][0].number, 482);
  assert.equal(store.writes[0][1], 0);
});

test("fetcher does not write when gh returns nothing it can parse", async () => {
  const store = shared(undefined);
  const fetchPr = pullRequestFetcher(async () => "not json", 60_000, () => 0, store);
  assert.equal(await fetchPr("/a"), undefined);
  assert.deepEqual(store.writes, []);
});
