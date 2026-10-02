// Run: node --test lib/tmux-pane-view.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { derivePaneView } from "./tmux-pane-view.js";

// Mirrors the slice of the V2 TUI plugin context the view reads. `sessions`
// maps id → { parentID?, title?, location?, running?, permissions?, forms? }.
function view({ route = { type: "home" }, sessions = {}, tabs, familyIndex = true } = {}) {
  const rootOf = (id) => {
    let current = id;
    while (sessions[current]?.parentID) current = sessions[current].parentID;
    return current;
  };
  return derivePaneView({
    location: undefined,
    ui: {
      router: { current: () => route },
      tabs: {
        enabled: () => tabs !== undefined,
        list: () => (tabs ?? []).map((sessionID) => ({ sessionID })),
      },
    },
    data: {
      location: { default: () => ({ directory: "/Users/tim/dotfiles" }) },
      session: {
        get: (id) => (sessions[id] ? { id, ...sessions[id] } : undefined),
        root: rootOf,
        family: (root) =>
          familyIndex ? Object.keys(sessions).filter((id) => rootOf(id) === root) : [],
        status: (id) => (sessions[id]?.running ? "running" : "idle"),
        permission: { list: (id) => sessions[id]?.permissions },
        form: { list: (id) => sessions[id]?.forms },
      },
    },
  });
}

const at = (sessionID) => ({ type: "session", sessionID });

test("home screen without tabs is done, untitled, in the TUI's directory", () => {
  assert.deepEqual(view(), { state: "done", title: "", project: "dotfiles" });
});

test("idle shown session is done and titled", () => {
  const result = view({ route: at("a"), sessions: { a: { title: "Fix login" } } });
  assert.equal(result.state, "done");
  assert.equal(result.title, "Fix login");
});

test("a subagent view shows the root session's title", () => {
  const sessions = { a: { title: "Fix login" }, b: { parentID: "a", title: "explore" } };
  assert.equal(view({ route: at("b"), sessions }).title, "Fix login");
});

test("a running subagent makes the shown session working", () => {
  const sessions = { a: { title: "Fix login" }, b: { parentID: "a", running: true } };
  assert.equal(view({ route: at("a"), sessions }).state, "working");
});

test("a pending permission in the family wins over running", () => {
  const sessions = {
    a: { running: true },
    b: { parentID: "a", running: true, permissions: [{ id: "per_1" }] },
  };
  assert.equal(view({ route: at("a"), sessions }).state, "waiting");
});

test("a pending form (question) is waiting", () => {
  const sessions = { a: { running: true, forms: [{ id: "frm_1" }] } };
  assert.equal(view({ route: at("a"), sessions }).state, "waiting");
});

test("resolved permissions and forms leave no waiting state behind", () => {
  const sessions = { a: { permissions: [], forms: [] } };
  assert.equal(view({ route: at("a"), sessions }).state, "done");
});

test("a running background tab makes the pane working", () => {
  const sessions = { a: { title: "Shown" }, c: { title: "Background", running: true } };
  const result = view({ route: at("a"), sessions, tabs: ["a", "c"] });
  assert.equal(result.state, "working");
  assert.equal(result.title, "Shown");
});

test("project comes from the shown session's directory", () => {
  const sessions = { a: { location: { directory: "/Users/tim/code/ris-mvp" } } };
  assert.equal(view({ route: at("a"), sessions }).project, "ris-mvp");
});

test("without a family index the root session itself still counts", () => {
  const sessions = { a: { running: true } };
  assert.equal(view({ route: at("a"), sessions, familyIndex: false }).state, "working");
});
