// Run: node --test lib/tps.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { createTps } from "./tps.js";

const chars = (n) => "x".repeat(n);

test("shows nothing before any output", () => {
  assert.equal(createTps().label("s1", 0), "");
});

test("estimates live rate at 4 chars per token over the elapsed window", () => {
  const tps = createTps();
  tps.delta("s1", chars(40), 0);
  tps.delta("s1", chars(40), 1000);
  tps.delta("s1", chars(40), 2000);
  assert.equal(tps.label("s1", 2000), "⚡ 15 tok/s");
});

test("drops samples older than the window", () => {
  const tps = createTps();
  tps.delta("s1", chars(400), 0);
  tps.delta("s1", chars(40), 4000);
  assert.equal(tps.label("s1", 4000), "⚡ 10 tok/s");
});

test("falls back to nothing once streaming stopped and no step ended", () => {
  const tps = createTps();
  tps.delta("s1", chars(40), 0);
  assert.equal(tps.label("s1", 10_000), "");
});

test("keeps the last step rate after streaming stops", () => {
  const tps = createTps();
  tps.delta("s1", chars(100), 0);
  tps.delta("s1", chars(100), 2000);
  tps.stepEnded("s1", 50);
  assert.equal(tps.label("s1", 10_000), "⌀ 25 tok/s");
});

test("calibrates chars per token from the ended step", () => {
  const tps = createTps();
  tps.delta("s1", chars(100), 0);
  tps.delta("s1", chars(100), 2000);
  tps.stepEnded("s1", 20);
  tps.delta("s1", chars(50), 10_000);
  tps.delta("s1", chars(50), 11_000);
  assert.equal(tps.label("s1", 11_000), "⚡ 10 tok/s");
});

test("ignores steps too short to give a stable rate", () => {
  const tps = createTps();
  tps.delta("s1", chars(100), 0);
  tps.delta("s1", chars(100), 200);
  tps.stepEnded("s1", 50);
  assert.equal(tps.label("s1", 10_000), "");
});

test("keeps sessions independent", () => {
  const tps = createTps();
  tps.delta("s1", chars(40), 0);
  tps.delta("s1", chars(40), 1000);
  assert.equal(tps.label("s2", 1000), "");
});
