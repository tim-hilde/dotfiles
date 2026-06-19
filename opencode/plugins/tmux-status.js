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
  // Child (subagent) session ids. opencode keeps the ROOT session "busy" for
  // the whole turn — through every tool call and subagent — and only emits its
  // idle once everything has finished. So the root's idle is the authoritative
  // "done" signal; a subagent's idle just means one subagent finished while the
  // root keeps working, and must be ignored.
  const subagents = new Set();
  // Sticky while we're blocked on the user (permission / question / plan_exit).
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

  const setWorking = () => {
    waiting = false;
    if (state === "working") return;
    // Debounce so sub-300ms blips don't churn the state file.
    if (!workingTimer) {
      workingTimer = setTimeout(() => {
        workingTimer = null;
        if (!waiting) setState("working");
      }, 300);
    }
  };

  const setDone = () => {
    clearWorkingTimer();
    waiting = false;
    setState("done");
  };

  const setWaiting = () => {
    clearWorkingTimer();
    waiting = true;
    setState("waiting");
  };

  // A subagent going idle means the root is still working -> ignore it.
  // Any other (root) idle ends the whole turn.
  const onIdle = (sid) => {
    if (sid && subagents.has(sid)) return;
    setDone();
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
          if (info.parentID) {
            if (info.id) subagents.add(info.id);
            break;
          }
          if (info.id) rootSessionId = info.id;
          if (typeof info.title === "string" && info.title !== title) {
            title = info.title;
            write();
          }
          break;
        }
        case "session.status": {
          const t = props.status && props.status.type;
          if (t === "busy") setWorking();
          else if (t === "idle") onIdle(props.sessionID);
          // "retry" — keep current state.
          break;
        }
        case "session.idle":
          onIdle(props.sessionID);
          break;
        case "session.error":
          onIdle(props.sessionID);
          break;
        case "session.deleted": {
          const sid = props.info && props.info.id;
          if (sid) subagents.delete(sid);
          break;
        }
        case "message.updated":
          if (props.info && props.info.role === "user") setWorking();
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
