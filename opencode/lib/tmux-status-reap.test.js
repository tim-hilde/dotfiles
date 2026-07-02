import { test } from "node:test";
import assert from "node:assert/strict";
import { reapStale } from "./tmux-status-reap.js";

// Fake fs: files is a Map<name, string|undefined>. undefined content means
// readFile throws (simulates a race where the file vanished mid-sweep).
function harness(files, alivePids) {
  const removed = [];
  reapStale({
    dir: "/state",
    readdir: () => [...files.keys()],
    readFile: (path) => {
      const name = path.split("/").pop();
      const content = files.get(name);
      if (content === undefined) throw new Error("ENOENT");
      return content;
    },
    rm: (path) => removed.push(path.split("/").pop()),
    isAlive: (pid) => alivePids.has(pid),
  });
  return removed;
}

test("removes .json with a dead pid", () => {
  const files = new Map([["124.json", JSON.stringify({ pid: 999 })]]);
  const removed = harness(files, new Set());
  assert.deepEqual(removed, ["124.json"]);
});

test("keeps .json with a live pid", () => {
  const files = new Map([["124.json", JSON.stringify({ pid: 999 })]]);
  const removed = harness(files, new Set([999]));
  assert.deepEqual(removed, []);
});

test("removes corrupt/unparseable .json", () => {
  const files = new Map([["124.json", "not json"]]);
  const removed = harness(files, new Set([999]));
  assert.deepEqual(removed, ["124.json"]);
});

test("removes .json with a missing pid field", () => {
  const files = new Map([["124.json", JSON.stringify({ state: "done" })]]);
  const removed = harness(files, new Set([999]));
  assert.deepEqual(removed, ["124.json"]);
});

test("removes .tmp whose owning pid is dead", () => {
  const files = new Map([["124.4242.tmp", ""]]);
  const removed = harness(files, new Set());
  assert.deepEqual(removed, ["124.4242.tmp"]);
});

test("keeps .tmp whose owning pid is alive", () => {
  const files = new Map([["124.4242.tmp", ""]]);
  const removed = harness(files, new Set([4242]));
  assert.deepEqual(removed, []);
});

test("ignores files it doesn't own", () => {
  const files = new Map([
    [".DS_Store", ""],
    ["notes.txt", ""],
  ]);
  const removed = harness(files, new Set());
  assert.deepEqual(removed, []);
});

test("a throwing readFile on one entry doesn't stop the sweep", () => {
  const files = new Map([
    ["124.json", undefined], // vanished mid-sweep -> readFile throws
    ["125.json", JSON.stringify({ pid: 999 })],
  ]);
  const removed = harness(files, new Set());
  assert.deepEqual(removed.sort(), ["124.json", "125.json"]);
});

test("mixed batch removes exactly the stale set", () => {
  const files = new Map([
    ["1.json", JSON.stringify({ pid: 100 })], // dead
    ["2.json", JSON.stringify({ pid: 200 })], // alive
    ["2.200.tmp", ""], // alive
    ["3.300.tmp", ""], // dead
  ]);
  const removed = harness(files, new Set([200]));
  assert.deepEqual(removed.sort(), ["1.json", "3.300.tmp"]);
});
