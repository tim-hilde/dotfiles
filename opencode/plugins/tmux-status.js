import { writeFileSync, renameSync, mkdirSync, rmSync } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

const INITIAL = "done";

const sanitizePaneId = (pane) => String(pane).replace(/^%/, "");

const isWaitingTool = (tool) => tool === "question" || tool === "plan_exit";

const TmuxStatus = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return {};

  const id = sanitizePaneId(pane);
  const file = join(STATE_DIR, `${id}.json`);
  const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);
  const project = directory ? basename(directory) : "";

  let state = INITIAL;
  let title = "";
  let rootSessionId = null;
  // Every session that is currently processing — the root AND any subagents.
  // A subagent (or a long-running tool) keeps its session in here, so the pane
  // no longer flips to "done" while work is still in flight.
  const busy = new Set();
  // Sticky while we're blocked on the user (permission / question / plan_exit);
  // only cleared once work resumes or the whole turn ends.
  let waiting = false;
  let workingTimer = null;

  try {
    mkdirSync(STATE_DIR, { recursive: true });
  } catch {}

  const write = () => {
    const payload = JSON.stringify({
      pane,
      state,
      title,
      project,
      pid: process.pid,
      updatedAt: Date.now(),
    });
    try {
      writeFileSync(tmpFile, payload);
      renameSync(tmpFile, file);
    } catch {}
  };

  const setState = (next) => {
    if (next === state) return;
    state = next;
    write();
  };

  const clearWorkingTimer = () => {
    if (workingTimer) {
      clearTimeout(workingTimer);
      workingTimer = null;
    }
  };

  // Derive the pane state from what is actually running. Never overrides
  // "waiting" — that stays until work resumes or the turn fully ends.
  const refresh = () => {
    if (waiting) return;
    setState(busy.size > 0 ? "working" : "done");
  };

  const markBusy = (sid) => {
    if (sid) busy.add(sid);
    waiting = false;
    if (state === "working") return;
    // Debounce so sub-300ms blips don't churn the state file.
    if (!workingTimer) {
      workingTimer = setTimeout(() => {
        workingTimer = null;
        if (!waiting && busy.size > 0) setState("working");
      }, 300);
    }
  };

  const markIdle = (sid) => {
    if (sid) busy.delete(sid);
    // Once nothing is processing, the turn is over: drop any "waiting" hold.
    if (busy.size === 0) {
      waiting = false;
      clearWorkingTimer();
    }
    refresh();
  };

  const setWaiting = () => {
    waiting = true;
    clearWorkingTimer();
    setState("waiting");
  };

  // Register exit cleanup BEFORE first write (defensive ordering)
  process.once("exit", () => {
    try {
      rmSync(file);
    } catch {}
  });

  write();

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
        rootSessionId = root.id;
        if (typeof root.title === "string" && root.title !== title) {
          title = root.title;
          write();
        }
      }
    } catch {}
  }, 0);

  return {
    event: async ({ event }) => {
      const type = event && event.type;
      const props = (event && event.properties) || {};

      switch (type) {
        case "session.created":
        case "session.updated": {
          const info = props.info || {};
          // Subagent metadata — its busy/idle is tracked via session.status.
          if (info.parentID) break;
          if (info.id) rootSessionId = info.id;
          if (typeof info.title === "string" && info.title !== title) {
            title = info.title;
            write();
          }
          break;
        }
        case "session.status": {
          const t = props.status && props.status.type;
          if (t === "busy") markBusy(props.sessionID);
          else if (t === "idle") markIdle(props.sessionID);
          // "retry" — keep current state.
          break;
        }
        case "session.idle":
          markIdle(props.sessionID);
          break;
        case "session.deleted":
          markIdle(props.info && props.info.id);
          break;
        case "session.error": {
          if (props.sessionID) busy.delete(props.sessionID);
          else busy.clear();
          waiting = false;
          clearWorkingTimer();
          refresh();
          break;
        }
        case "message.updated":
          if (props.info && props.info.role === "user") {
            markBusy(props.info.sessionID);
          }
          break;
      }
    },
    "permission.ask": async () => {
      setWaiting();
    },
    "tool.execute.before": async (input) => {
      if (isWaitingTool(input && input.tool)) setWaiting();
    },
  };
};

export default TmuxStatus;
