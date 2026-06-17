import { writeFileSync, renameSync, mkdirSync, rmSync } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

const INITIAL = "done";

const sanitizePaneId = (pane) => String(pane).replace(/^%/, "");

const freshTracker = () => ({
  state: INITIAL,
  title: "",
  rootSessionId: null,
  subagents: new Set(),
});

const stateForTool = (tool) =>
  tool === "question" || tool === "plan_exit" ? "waiting" : null;

// Updates tracker (title / rootSessionId / subagents / state) as a side effect
// and returns the new state string, or null when the event changes no state.
const reduceEvent = (tracker, event) => {
  const type = event && event.type;
  const props = (event && event.properties) || {};
  let next = null;
  switch (type) {
    case "session.created":
    case "session.updated": {
      const info = props.info || {};
      if (info.parentID) {
        if (info.id) tracker.subagents.add(info.id);
      } else {
        if (info.id) tracker.rootSessionId = info.id;
        if (typeof info.title === "string") tracker.title = info.title;
      }
      break;
    }
    case "session.deleted": {
      const id = props.info && props.info.id;
      if (id) tracker.subagents.delete(id);
      break;
    }
    case "message.updated":
      next = props.info && props.info.role === "user" ? "working" : null;
      break;
    case "session.status":
      next = props.status && props.status.type === "busy" ? "working" : null;
      break;
    case "session.idle": {
      const id = props.sessionID;
      next = id && tracker.subagents.has(id) ? null : "done";
      break;
    }
    case "session.error":
      next = "done";
      break;
  }
  if (next !== null) tracker.state = next;
  return next;
};

const TmuxStatus = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return {};

  const id = sanitizePaneId(pane);
  const file = join(STATE_DIR, `${id}.json`);
  const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);
  const project = directory ? basename(directory) : "";
  const tracker = freshTracker();

  // Inactivity timer: if no busy event arrives for 2s after the last one,
  // we consider the turn done. This handles both root idle and subagent patterns.
  let inactivityTimer = null;
  let workingTimer = null;

  try {
    mkdirSync(STATE_DIR, { recursive: true });
  } catch {}

  const write = (nextState = null) => {
    if (nextState !== null) tracker.state = nextState;
    const payload = JSON.stringify({
      pane,
      state: tracker.state,
      title: tracker.title,
      project,
      pid: process.pid,
      updatedAt: Date.now(),
    });
    try {
      writeFileSync(tmpFile, payload);
      renameSync(tmpFile, file);
    } catch {}
  };

  const armInactivity = () => {
    if (inactivityTimer) clearTimeout(inactivityTimer);
    inactivityTimer = setTimeout(() => {
      inactivityTimer = null;
      if (tracker.state === "working") write("done");
    }, 8000);
  };

  const setWorking = () => {
    if (workingTimer) clearTimeout(workingTimer);
    workingTimer = setTimeout(() => {
      workingTimer = null;
      if (tracker.state !== "done" && tracker.state !== "waiting") {
        write("working");
        armInactivity();
      }
    }, 300);
  };

  const setDone = () => {
    if (workingTimer) { clearTimeout(workingTimer); workingTimer = null; }
    if (inactivityTimer) { clearTimeout(inactivityTimer); inactivityTimer = null; }
    write("done");
  };

  // Register exit cleanup BEFORE first write (defensive ordering)
  process.once("exit", () => {
    try { rmSync(file); } catch {}
  });

  write(INITIAL);

  // Best-effort title seed — deferred so we don't block plugin init.
  // client.session.list() may hang if called before the server is ready.
  setTimeout(async () => {
    try {
      const res = await client.session.list();
      const sessions = (res && res.data) || [];
      const root = sessions
        .filter((s) => !s.parentID)
        .sort(
          (a, b) =>
            ((b.time && b.time.updated) || 0) - ((a.time && a.time.updated) || 0)
        )[0];
      if (root) {
        tracker.rootSessionId = root.id;
        if (typeof root.title === "string") tracker.title = root.title;
        write(null);
      }
    } catch {}
  }, 0);

  return {
    event: async ({ event }) => {
      const prevTitle = tracker.title;
      const type = event && event.type;
      const props = (event && event.properties) || {};

      // Handle working/done transitions directly to use the debounce/immediate logic.
      if (type === "message.updated" && props.info && props.info.role === "user") {
        reduceEvent(tracker, event);
        setWorking();
        return;
      }
      if (type === "session.status") {
        if (props.status && props.status.type === "busy") {
          // Each busy pulse resets the inactivity timer.
          if (inactivityTimer) { clearTimeout(inactivityTimer); inactivityTimer = null; }
          setWorking();
        }
        // session.status idle has no sessionID — can't tell root from subagent, ignore.
        return;
      }
      if (type === "session.idle") {
        const sid = props.sessionID;
        // Only set done for the root session; subagent idle means root is still working.
        if (sid && tracker.subagents.has(sid)) return;
        setDone();
        return;
      }
      if (type === "session.error") {
        setDone();
        return;
      }

      // All other events (session.created/updated/deleted, etc.) — update tracker
      // metadata and write if title changed.
      const next = reduceEvent(tracker, event);
      if (next !== null || tracker.title !== prevTitle) write(next);
    },
    "permission.ask": async () => {
      if (workingTimer) { clearTimeout(workingTimer); workingTimer = null; }
      write("waiting");
    },
    "tool.execute.before": async (input) => {
      const s = stateForTool(input && input.tool);
      if (s) {
        if (workingTimer) { clearTimeout(workingTimer); workingTimer = null; }
        write(s);
      }
    },
  };
};

export default TmuxStatus;
