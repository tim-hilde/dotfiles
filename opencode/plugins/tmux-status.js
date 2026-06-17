import { writeFileSync, renameSync, mkdirSync, rmSync } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";
import {
  sanitizePaneId,
  reduceEvent,
  stateForTool,
  freshTracker,
  INITIAL,
} from "../lib/tmux-status-core.mjs";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

const TmuxStatus = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return {};

  const id = sanitizePaneId(pane);
  const file = join(STATE_DIR, `${id}.json`);
  const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);
  const project = directory ? basename(directory) : "";
  const tracker = freshTracker();

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

  // Register exit cleanup BEFORE first write (defensive ordering)
  process.once("exit", () => {
    try {
      rmSync(file);
    } catch {}
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
      const next = reduceEvent(tracker, event);
      if (next !== null || tracker.title !== prevTitle) write(next);
    },
    "permission.ask": async () => {
      write("waiting");
    },
    "tool.execute.before": async (input) => {
      const s = stateForTool(input && input.tool);
      if (s) write(s);
    },
  };
};

export default TmuxStatus;
