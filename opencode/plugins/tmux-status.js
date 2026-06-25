import { writeFileSync, renameSync, mkdirSync, rmSync, appendFileSync } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";
import { createStatusMachine } from "../lib/tmux-status-state.js";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

// Temporary diagnostics: set OC_TMUX_DEBUG=1 to log every event + state write
// to ~/.cache/opencode-tmux/debug-<pane>.log. Off by default.
const DEBUG = process.env.OC_TMUX_DEBUG === "1";

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

  const dbg = DEBUG
    ? (line) => {
        try {
          appendFileSync(
            join(STATE_DIR, `debug-${id}.log`),
            `${new Date().toISOString()} ${line}\n`
          );
        } catch {}
      }
    : () => {};

  // Atomic write: write to <file>.tmp, then rename() over <file>.
  const writeState = (snapshot) => {
    dbg(`WRITE state=${snapshot.state} title=${JSON.stringify(snapshot.title)}`);
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
      if (DEBUG) {
        const p = (event && event.properties) || {};
        dbg(
          `EVENT ${event && event.type}` +
            ` sid=${p.sessionID ?? ""}` +
            ` id=${(p.info && p.info.id) ?? ""}` +
            ` parent=${(p.info && p.info.parentID) ?? ""}` +
            ` status=${(p.status && p.status.type) ?? ""}` +
            ` role=${(p.info && p.info.role) ?? ""}`
        );
      }
      machine.handleEvent(event);
    },
    "permission.ask": async () => {
      dbg("HOOK permission.ask");
      machine.markWaiting();
    },
    "tool.execute.before": async (input) => {
      const tool = input && input.tool;
      if (isWaitingTool(tool)) {
        dbg(`HOOK tool.execute.before tool=${tool}`);
        machine.markWaiting();
      }
    },
  };
};

export default TmuxStatus;
