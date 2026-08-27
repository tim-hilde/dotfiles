import { test } from "node:test";
import assert from "node:assert/strict";
import { createStatusStore, mergeSnapshots } from "./tmux-status-state.js";

const harness = () => {
  const writes = [];
  const store = createStatusStore({ onChange: (s) => writes.push({ ...s }) });
  return { store, writes };
};

test("starts done with an empty title", () => {
  const { store } = harness();
  assert.deepEqual(store.getSnapshot(), { state: "done", title: "" });
});

test("a busy session makes the pane working", () => {
  const { store, writes } = harness();
  store.setBusy(true);
  assert.equal(store.getSnapshot().state, "working");
  assert.equal(writes.length, 1);
});

test("repeated setBusy does not rewrite", () => {
  const { store, writes } = harness();
  store.setBusy(true);
  store.setBusy(true);
  assert.equal(writes.length, 1);
});

test("losing the last busy session settles to done immediately", () => {
  const { store } = harness();
  store.setBusy(true);
  store.setBusy(false);
  assert.equal(store.getSnapshot().state, "done");
});

test("a pending question outranks working", () => {
  const { store } = harness();
  store.setBusy(true);
  store.askQuestion("q1");
  assert.equal(store.getSnapshot().state, "waiting");
  store.replyQuestion("q1");
  assert.equal(store.getSnapshot().state, "working");
});

test("a pending permission outranks working", () => {
  const { store } = harness();
  store.setBusy(true);
  store.askPermission("p1");
  assert.equal(store.getSnapshot().state, "waiting");
  store.replyPermission("p1");
  assert.equal(store.getSnapshot().state, "working");
});

test("waiting holds until every pending request is resolved", () => {
  const { store } = harness();
  store.setBusy(true);
  store.askQuestion("q1");
  store.askPermission("p1");
  store.replyQuestion("q1");
  assert.equal(store.getSnapshot().state, "waiting");
  store.replyPermission("p1");
  assert.equal(store.getSnapshot().state, "working");
});

test("an idle workspace drops request ids whose reply was never seen", () => {
  const { store } = harness();
  store.setBusy(true);
  store.askQuestion("q1");
  store.setBusy(false);
  assert.equal(store.getSnapshot().state, "done");
});

test("a question asked before the status pull still wins", () => {
  const { store } = harness();
  store.askQuestion("q1");
  assert.equal(store.getSnapshot().state, "waiting");
  store.setBusy(true);
  assert.equal(store.getSnapshot().state, "waiting");
});

test("missing request ids are ignored", () => {
  const { store, writes } = harness();
  store.setBusy(true);
  store.askQuestion(undefined);
  store.askPermission("");
  assert.equal(store.getSnapshot().state, "working");
  assert.equal(writes.length, 1);
});

test("title changes are published without touching state", () => {
  const { store, writes } = harness();
  store.setTitle("Refactor the reducer");
  assert.deepEqual(writes, [{ state: "done", title: "Refactor the reducer" }]);
  store.setTitle("Refactor the reducer");
  assert.equal(writes.length, 1);
});

test("non-string titles are ignored", () => {
  const { store, writes } = harness();
  store.setTitle(undefined);
  assert.equal(writes.length, 0);
  assert.equal(store.getSnapshot().title, "");
});

test("mergeSnapshots returns done for an empty registry", () => {
  assert.deepEqual(mergeSnapshots([]), {
    state: "done",
    title: "",
    project: "",
  });
});

test("mergeSnapshots ranks working over done", () => {
  const merged = mergeSnapshots([
    { state: "done", title: "a", project: "a" },
    { state: "working", title: "b", project: "b" },
  ]);
  assert.equal(merged.project, "b");
});

test("mergeSnapshots ranks waiting over working", () => {
  const merged = mergeSnapshots([
    { state: "working", title: "b", project: "b" },
    { state: "waiting", title: "c", project: "c" },
  ]);
  assert.equal(merged.project, "c");
});

test("mergeSnapshots keeps the first of equally ranked workspaces", () => {
  const merged = mergeSnapshots([
    { state: "working", title: "b", project: "b" },
    { state: "working", title: "c", project: "c" },
  ]);
  assert.equal(merged.project, "b");
});
