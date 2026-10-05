// Run: node --test lib/prompt-footer.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { activityLabel, contextUsage, footerLayout, formatDuration, usageLabel } from "./prompt-footer.js";

const NOW = 10_000_000;

test("formats durations as seconds, minutes, or hours", () => {
  assert.equal(formatDuration(0), "0s");
  assert.equal(formatDuration(42_999), "42s");
  assert.equal(formatDuration(192_000), "3m12s");
  assert.equal(formatDuration(65_000), "1m05s");
  assert.equal(formatDuration(3_840_000), "1h04m");
});

test("activity label is absent when nothing runs", () => {
  assert.equal(activityLabel(0, "shell", [], NOW), undefined);
});

test("activity label shows the runtime of the single runner", () => {
  assert.equal(activityLabel(1, "shell", [NOW - 192_000], NOW), "1 shell (3m12s)");
});

test("activity label pluralizes and shows the longest runtime", () => {
  assert.equal(activityLabel(2, "subagent", [NOW - 40_000, NOW - 125_000], NOW), "2 subagents (2m05s)");
});

test("activity label omits the runtime when no start time is known", () => {
  assert.equal(activityLabel(1, "subagent", [undefined], NOW), "1 subagent");
});

const assistant = (id, total, model = { providerID: "anthropic", id: "claude" }) => ({
  id,
  type: "assistant",
  model,
  tokens: { input: total, output: 0, reasoning: 0, cache: { read: 0, write: 0 } },
});
const user = (id) => ({ id, type: "user" });
const models = [{ providerID: "anthropic", id: "claude", limit: { context: 200_000 } }];

test("context usage sums the tokens of the last assistant message", () => {
  const messages = [
    assistant("a1", 1000),
    user("u1"),
    { id: "a2", type: "assistant", model: models[0], tokens: { input: 40_000, output: 2_000, reasoning: 1_000, cache: { read: 3_000, write: 200 } } },
  ];
  assert.deepEqual(contextUsage(messages, models), { tokens: 46_200, percent: 23 });
});

test("context usage ignores messages before the last completed compaction", () => {
  const messages = [assistant("a1", 1000), { id: "c1", type: "compaction", status: "completed" }, user("u1")];
  assert.equal(contextUsage(messages, models), undefined);
});

test("context usage stops at the revert point", () => {
  const messages = [assistant("a1", 1000), user("u1"), assistant("a2", 5000)];
  assert.equal(contextUsage(messages, models, "u1").tokens, 1000);
  assert.equal(contextUsage(messages, models, "missing"), undefined);
});

test("context usage has no percent for an unknown model", () => {
  const messages = [assistant("a1", 1000, { providerID: "other", id: "x" })];
  assert.deepEqual(contextUsage(messages, models), { tokens: 1000, percent: undefined });
});

test("context usage is absent without tokens", () => {
  assert.equal(contextUsage([assistant("a1", 0)], models), undefined);
});

test("usage label abbreviates tokens and appends the percent", () => {
  assert.equal(usageLabel({ tokens: 46_200, percent: 23 }), "46.2K (23%)");
  assert.equal(usageLabel({ tokens: 1_500_000, percent: undefined }), "1.5M");
  assert.equal(usageLabel({ tokens: 999, percent: 0 }), "999 (0%)");
});

test("layout shows only shortcuts when there is no usage and room for them", () => {
  assert.deepEqual(footerLayout({ width: 44, usage: [], commands: "ctrl+p" }), { usage: false, shortcuts: true });
  assert.deepEqual(footerLayout({ width: 43, usage: [], commands: "ctrl+p" }), { usage: false, shortcuts: false });
});

test("layout drops shortcuts before usage as the terminal narrows", () => {
  const usage = ["46.2K (23%)", "$0.12"];
  assert.deepEqual(footerLayout({ width: 80, usage, commands: "ctrl+p" }), { usage: true, shortcuts: true });
  assert.deepEqual(footerLayout({ width: 60, usage, commands: "ctrl+p" }), { usage: true, shortcuts: false });
  assert.deepEqual(footerLayout({ width: 20, usage, commands: "ctrl+p" }), { usage: false, shortcuts: false });
});
