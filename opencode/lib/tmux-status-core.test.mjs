import test from "node:test";
import assert from "node:assert/strict";
import {
  sanitizePaneId,
  freshTracker,
  reduceEvent,
  stateForTool,
  INITIAL,
} from "./tmux-status-core.mjs";

test("sanitizePaneId strips leading %", () => {
  assert.equal(sanitizePaneId("%23"), "23");
  assert.equal(sanitizePaneId("%0"), "0");
  assert.equal(sanitizePaneId("23"), "23");
  assert.equal(sanitizePaneId(23), "23");
});

test("fresh tracker starts done", () => {
  assert.equal(freshTracker().state, INITIAL);
  assert.equal(INITIAL, "done");
});

test("user message -> working", () => {
  const t = freshTracker();
  const s = reduceEvent(t, { type: "message.updated", properties: { info: { role: "user", sessionID: "s1" } } });
  assert.equal(s, "working");
});

test("assistant message -> no change", () => {
  const t = freshTracker();
  const s = reduceEvent(t, { type: "message.updated", properties: { info: { role: "assistant", sessionID: "s1" } } });
  assert.equal(s, null);
});

test("session.status busy -> working (overrides waiting)", () => {
  const t = freshTracker();
  t.state = "waiting";
  const s = reduceEvent(t, { type: "session.status", properties: { sessionID: "s1", status: { type: "busy" } } });
  assert.equal(s, "working");
});

test("root session.idle -> done", () => {
  const t = freshTracker();
  const s = reduceEvent(t, { type: "session.idle", properties: { sessionID: "root1" } });
  assert.equal(s, "done");
});

test("subagent idle is ignored", () => {
  const t = freshTracker();
  reduceEvent(t, { type: "session.created", properties: { info: { id: "sub1", parentID: "root1" } } });
  const s = reduceEvent(t, { type: "session.idle", properties: { sessionID: "sub1" } });
  assert.equal(s, null);
});

test("session.error -> done", () => {
  const t = freshTracker();
  const s = reduceEvent(t, { type: "session.error", properties: { sessionID: "root1" } });
  assert.equal(s, "done");
});

test("root session title is tracked", () => {
  const t = freshTracker();
  reduceEvent(t, { type: "session.updated", properties: { info: { id: "root1", title: "Build the thing" } } });
  assert.equal(t.title, "Build the thing");
  assert.equal(t.rootSessionId, "root1");
});

test("session.status non-busy -> no change", () => {
  const t = freshTracker();
  const s = reduceEvent(t, { type: "session.status", properties: { sessionID: "s1", status: { type: "idle" } } });
  assert.equal(s, null);
});

test("stateForTool maps question and plan_exit to waiting", () => {
  assert.equal(stateForTool("question"), "waiting");
  assert.equal(stateForTool("plan_exit"), "waiting");
  assert.equal(stateForTool("read"), null);
});
