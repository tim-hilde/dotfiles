import {
  writeFileSync,
  readFileSync,
  readdirSync,
  renameSync,
  mkdirSync,
  rmSync,
} from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";
import { createStatusMachine } from "../lib/tmux-status-state.js";
import { reapStale, isProcessAlive } from "../lib/tmux-status-reap.js";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

const sanitizePaneId = (pane) => String(pane).replace(/^%/, "");

const isWaitingTool = (tool) => tool === "question" || tool === "plan_exit";

const TmuxStatus = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return {};

  const id = sanitizePaneId(pane);
  const file = join(STATE_DIR, `${id}.json`);
  const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);
  const project = directory ? basename(directory) : "";

  try {
    mkdirSync(STATE_DIR, { recursive: true });
  } catch {}

  // Reap files left behind by crashed/killed sessions (no clean exit means
  // the process.once("exit") cleanup below never ran for them).
  try {
    reapStale({
      dir: STATE_DIR,
      readdir: readdirSync,
      readFile: (f) => readFileSync(f, "utf8"),
      rm: rmSync,
      isAlive: isProcessAlive,
    });
  } catch {}

  // Atomic write: write to <file>.tmp, then rename() over <file>.
  const writeState = (snapshot) => {
    const payload = JSON.stringify({
      pane,
      state: snapshot.state,
      title: snapshot.title,
      project,
      pid: process.pid,
      updatedAt: Date.now(),
    });
    try {
      writeFileSync(tmpFile, payload);
      renameSync(tmpFile, file);
    } catch {}
  };

  // All state transitions (working debounce, idle settle, subagent filtering,
  // waiting stickiness) live in the pure, tested machine.
  const machine = createStatusMachine({ onChange: writeState });

  // Register exit cleanup BEFORE first write (defensive ordering)
  process.once("exit", () => {
    try {
      rmSync(file);
    } catch {}
  });

  writeState(machine.getSnapshot());

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
        // Feed it as a session.updated so the machine tracks the root id + title.
        machine.handleEvent({
          type: "session.updated",
          properties: { info: { id: root.id, title: root.title } },
        });
      }
    } catch {}
  }, 0);

  return {
    event: async ({ event }) => {
      machine.handleEvent(event);
    },
    "permission.ask": async () => {
      machine.markWaiting();
    },
    "tool.execute.before": async (input) => {
      if (isWaitingTool(input && input.tool)) machine.markWaiting();
    },
  };
};

export default TmuxStatus;
