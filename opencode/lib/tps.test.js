// Run: node --test lib/tps.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { createTps } from "./tps.js";

const chars = (n) => "x".repeat(n);

test("shows nothing before any output", () => {
  assert.equal(createTps().label("s1", 0), "");
});

test("estimates the rate at 4 chars per token over the elapsed window", () => {
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

test("shows nothing once streaming stopped", () => {
  const tps = createTps();
  tps.delta("s1", chars(40), 0);
  assert.equal(tps.label("s1", 10_000), "");
});

test("keeps sessions independent", () => {
  const tps = createTps();
  tps.delta("s1", chars(40), 0);
  tps.delta("s1", chars(40), 1000);
  assert.equal(tps.label("s2", 1000), "");
});
