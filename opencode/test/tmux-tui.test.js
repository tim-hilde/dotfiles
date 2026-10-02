// Run: node --test test/tmux-tui.test.js
//
// TMUX points at a socket that does not exist, so the plugin's tmux calls fail
// fast and never touch a real tmux server.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const stateDir = mkdtempSync(join(tmpdir(), "oc-tmux-tui-"));
process.env.OC_TMUX_STATE_DIR = stateDir;
process.env.TMUX = join(stateDir, "no-such-socket") + ",1,0";
process.env.TMUX_PANE = "%990001";

const { default: plugin } = await import("../plugins/tmux/tui.js");

const ctx = {
  location: undefined,
  ui: {
    router: { current: () => ({ type: "session", sessionID: "a" }) },
    tabs: { enabled: () => false, list: () => [] },
  },
  data: {
    location: { default: () => ({ directory: "/Users/tim/dotfiles" }) },
    session: {
      get: (id) =>
        id === "a" ? { id, title: "Fix login", location: { directory: "/Users/tim/dotfiles" } } : undefined,
      root: (id) => id,
      family: () => ["a"],
      status: () => "running",
      permission: { list: () => [] },
      form: { list: () => [] },
    },
  },
};

test("publishes the pane state file and removes it on cleanup", async () => {
  const cleanup = await plugin.setup(ctx);
  const file = join(stateDir, "990001.json");

  const raw = readFileSync(file, "utf8");
  const payload = JSON.parse(raw);
  assert.deepEqual(
    { pane: payload.pane, state: payload.state, title: payload.title, project: payload.project, pid: payload.pid },
    { pane: "%990001", state: "working", title: "Fix login", project: "dotfiles", pid: process.pid },
  );
  // tmux/agent-switch.sh and agent-grid.sh match this with a whitespace-free regex.
  assert.match(raw, /"updatedAt":[0-9]+/);

  await cleanup();
  assert.equal(existsSync(file), false);
});
