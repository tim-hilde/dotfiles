// Derives the tmux pane status from opencode's authoritative session status.
//
// Lives outside plugins/ on purpose: opencode loads every export of a
// plugins/*.js file as a plugin factory, so the pure logic is kept here and
// imported by the plugin. This module has no IO and no timers.
//
// There is no debounce. `busy` mirrors GET /session/status, which the plugin
// re-reads on every status event, so a missed event self-heals on the next one.
// `waiting` mirrors the pending question/permission requests; those cannot
// outlive a busy session, hence the clear in setBusy(false) — it recovers from
// a reply event we never saw.

const RANK = { done: 1, working: 2, waiting: 3 };

export function mergeSnapshots(snapshots) {
  let best = null;
  for (const snapshot of snapshots) {
    if (!best || RANK[snapshot.state] > RANK[best.state]) best = snapshot;
  }
  return best ?? { state: "done", title: "", project: "" };
}

export function createStatusStore({ onChange = () => {} } = {}) {
  let busy = false;
  let state = "done";
  let title = "";
  const questions = new Set();
  const permissions = new Set();

  const commit = () => {
    const next =
      questions.size || permissions.size
        ? "waiting"
        : busy
          ? "working"
          : "done";
    if (next === state) return;
    state = next;
    onChange({ state, title });
  };

  const track = (set, id, add) => {
    if (!id) return;
    if (add) set.add(id);
    else set.delete(id);
    commit();
  };

  return {
    setBusy(next) {
      busy = Boolean(next);
      if (!busy) {
        questions.clear();
        permissions.clear();
      }
      commit();
    },
    askQuestion: (id) => track(questions, id, true),
    replyQuestion: (id) => track(questions, id, false),
    askPermission: (id) => track(permissions, id, true),
    replyPermission: (id) => track(permissions, id, false),
    setTitle(next) {
      if (typeof next !== "string" || next === title) return;
      title = next;
      onChange({ state, title });
    },
    getSnapshot: () => ({ state, title }),
  };
}
