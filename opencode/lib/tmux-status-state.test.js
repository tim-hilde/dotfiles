import { test } from "node:test";
import assert from "node:assert/strict";
import {
  createStatusMachine,
  IDLE_SETTLE_MS,
  WORKING_DEBOUNCE_MS,
} from "./tmux-status-state.js";

// Deterministic fake-timer harness: time only advances when we tell it to.
function harness(opts = {}) {
  let time = 0;
  let nextId = 1;
  let timers = [];
  const writes = [];
  const m = createStatusMachine({
    now: () => time,
    setTimer: (fn, ms) => {
      const id = nextId++;
      timers.push({ id, fn, at: time + ms });
      return id;
    },
    clearTimer: (id) => {
      timers = timers.filter((t) => t.id !== id);
    },
    onChange: (snap) => writes.push({ ...snap, at: time }),
    ...opts,
  });
  return {
    m,
    writes,
    state: () => m.getState(),
    advance(ms) {
      time += ms;
      // fire due timers in order; tolerate timers scheduled during firing
      for (;;) {
        const due = timers
          .filter((t) => t.at <= time)
          .sort((a, b) => a.at - b.at);
        if (due.length === 0) break;
        const t = due[0];
        timers = timers.filter((x) => x !== t);
        t.fn();
      }
    },
  };
}

const ev = (type, properties = {}) => ({ type, properties });
const busy = (sid = "ses_root") => ev("session.status", { sessionID: sid, status: { type: "busy" } });
const statusIdle = (sid = "ses_root") => ev("session.status", { sessionID: sid, status: { type: "idle" } });
const sessionIdle = (sid = "ses_root") => ev("session.idle", { sessionID: sid });
const userMsg = (sid = "ses_root") => ev("message.updated", { info: { role: "user", id: "msg_1", sessionID: sid } });
const subagentCreated = (id) => ev("session.created", { info: { id, parentID: "ses_root" } });
const rootUpdated = (title) => ev("session.updated", { info: { id: "ses_root", title } });

function toWorking(h) {
  h.m.handleEvent(userMsg());
  h.advance(WORKING_DEBOUNCE_MS);
  assert.equal(h.state(), "working");
}

// THE BUG REPRODUCTION: a transient root idle mid-turn must NOT flip the pane
// to "done". opencode emits idle between steps; a busy resumes shortly after.
test("transient idle followed by busy within settle window never reports done", () => {
  const h = harness();
  toWorking(h);

  h.m.handleEvent(sessionIdle()); // transient idle
  h.advance(IDLE_SETTLE_MS - 100); // not yet settled
  assert.equal(h.state(), "working", "must stay working until settled");

  h.m.handleEvent(busy()); // work resumes -> cancels pending settle
  h.advance(IDLE_SETTLE_MS * 2); // plenty of time

  assert.equal(h.state(), "working");
  assert.equal(
    h.writes.some((w) => w.state === "done"),
    false,
    "no done flash may ever be written",
  );
});

test("idle with no following busy settles to done after IDLE_SETTLE_MS", () => {
  const h = harness();
  toWorking(h);

  h.m.handleEvent(sessionIdle());
  h.advance(IDLE_SETTLE_MS - 1);
  assert.equal(h.state(), "working", "not settled one tick early");

  h.advance(1);
  assert.equal(h.state(), "done");
});

test("session.status idle also settles (carries sessionID in 1.17.x)", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(statusIdle());
  h.advance(IDLE_SETTLE_MS);
  assert.equal(h.state(), "done");
});

test("subagent idle is ignored: pane keeps working", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(subagentCreated("ses_sub"));

  h.m.handleEvent(sessionIdle("ses_sub")); // subagent finished, root still working
  h.advance(IDLE_SETTLE_MS * 2);

  assert.equal(h.state(), "working");
  assert.equal(h.writes.some((w) => w.state === "done"), false);
});

test("root idle after a subagent idle still settles to done", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(subagentCreated("ses_sub"));
  h.m.handleEvent(sessionIdle("ses_sub")); // ignored
  h.advance(50);
  h.m.handleEvent(sessionIdle("ses_root")); // real completion
  h.advance(IDLE_SETTLE_MS);
  assert.equal(h.state(), "done");
});

test("permission.updated sets waiting immediately and blocks a settle", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(ev("permission.updated", { sessionID: "ses_root" }));
  assert.equal(h.state(), "waiting");
});

test("markWaiting (question/plan_exit hook) sets waiting and survives idle settle window", () => {
  const h = harness();
  toWorking(h);
  h.m.markWaiting();
  assert.equal(h.state(), "waiting");
  h.advance(IDLE_SETTLE_MS * 2);
  assert.equal(h.state(), "waiting", "waiting is sticky until work resumes or turn ends");
});

test("a pending settle is cancelled when waiting begins", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(sessionIdle());
  h.advance(IDLE_SETTLE_MS - 100);
  h.m.markWaiting(); // user is asked something before settle fires
  h.advance(IDLE_SETTLE_MS * 2);
  assert.equal(h.state(), "waiting");
  assert.equal(h.writes.some((w) => w.state === "done"), false);
});

test("title update from root session triggers a write", () => {
  const h = harness();
  h.m.handleEvent(rootUpdated("Fix idle detection"));
  assert.equal(h.m.getTitle(), "Fix idle detection");
  assert.equal(h.writes.some((w) => w.title === "Fix idle detection"), true);
});

test("user message resumes work after done", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(sessionIdle());
  h.advance(IDLE_SETTLE_MS);
  assert.equal(h.state(), "done");

  h.m.handleEvent(userMsg());
  h.advance(WORKING_DEBOUNCE_MS);
  assert.equal(h.state(), "working");
});

test("rapid idle/busy/idle only the final idle settles to done", () => {
  const h = harness();
  toWorking(h);
  h.m.handleEvent(sessionIdle());
  h.advance(200);
  h.m.handleEvent(busy());
  h.advance(200);
  h.m.handleEvent(sessionIdle());
  h.advance(IDLE_SETTLE_MS - 1);
  assert.equal(h.state(), "working");
  h.advance(1);
  assert.equal(h.state(), "done");
});
