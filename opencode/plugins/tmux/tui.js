import {
  writeFileSync,
  readFileSync,
  readdirSync,
  renameSync,
  mkdirSync,
  rmSync,
} from "node:fs";
import { execFile, execFileSync } from "node:child_process";
import { join } from "node:path";
import { homedir } from "node:os";
import { derivePaneView } from "../../lib/tmux-pane-view.js";
import { reapStale, isProcessAlive } from "../../lib/tmux-status-reap.js";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");
// Polled rather than event-driven: switching the TUI to an idle session emits
// no server event, yet changes the pane's title and state.
const POLL_MS = 1000;
const MAX_TITLE_LEN = 64;

const windowTitle = (title) =>
  title.replace(/[\r\n\t]+/g, " ").trim().slice(0, MAX_TITLE_LEN);

export default {
  id: "tmux",
  setup(ctx) {
    const pane = process.env.TMUX_PANE;
    if (!pane || !process.env.TMUX) return;

    const id = pane.replace(/^%/, "");
    const file = join(STATE_DIR, `${id}.json`);
    const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);

    try {
      mkdirSync(STATE_DIR, { recursive: true });
    } catch {}
    try {
      reapStale({
        dir: STATE_DIR,
        readdir: readdirSync,
        readFile: (f) => readFileSync(f, "utf8"),
        rm: rmSync,
        isAlive: isProcessAlive,
      });
    } catch {}

    let last = {};
    const tick = () => {
      let view;
      try {
        view = derivePaneView(ctx);
      } catch {
        return;
      }
      if (
        view.state === last.state &&
        view.title === last.title &&
        view.project === last.project
      )
        return;
      const titleChanged = view.title !== last.title;
      last = view;

      try {
        writeFileSync(
          tmpFile,
          JSON.stringify({ pane, ...view, pid: process.pid, updatedAt: Date.now() }),
        );
        renameSync(tmpFile, file);
      } catch {}

      const title = windowTitle(view.title);
      if (titleChanged && title) {
        execFile("tmux", ["rename-window", "-t", pane, title], () => {});
      }
    };

    const timer = setInterval(tick, POLL_MS);
    timer.unref?.();

    let disposed = false;
    const cleanup = () => {
      if (disposed) return;
      disposed = true;
      clearInterval(timer);
      process.off("exit", cleanup);
      try {
        rmSync(file);
      } catch {}
      try {
        execFileSync("tmux", ["set", "-w", "-t", pane, "automatic-rename", "on"], {
          stdio: "ignore",
        });
      } catch {}
    };
    process.once("exit", cleanup);

    tick();
    return cleanup;
  },
};
