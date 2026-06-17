import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const LOG = join(homedir(), ".cache", "opencode-tmux", "debug.log");

const Debug = async ({ client }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane) return {};
  const log = (msg) => {
    try { appendFileSync(LOG, new Date().toISOString() + " " + msg + "\n"); } catch {}
  };
  log("plugin init pane=" + pane);
  return {
    event: async ({ event }) => {
      const t = event && event.type;
      if (!t) return;
      log("EVENT " + t + " props=" + JSON.stringify(event.properties));
    },
  };
};

export default Debug;
