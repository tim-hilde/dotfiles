// Run: node --test test/tmux-tui.test.js
//
// TMUX points at a socket that does not exist, so the plugin's tmux calls fail
// fast and never touch a real tmux server.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync, chmodSync, existsSync } from "node:fs";
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
    shell: { list: () => [] },
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

test("keeps the window title after cleanup by leaving automatic-rename off", async () => {
  const binDir = mkdtempSync(join(tmpdir(), "oc-tmux-bin-"));
  const log = join(binDir, "calls.log");
  writeFileSync(join(binDir, "tmux"), `#!/bin/sh\necho "$@" >> "${log}"\n`);
  chmodSync(join(binDir, "tmux"), 0o755);
  const originalPath = process.env.PATH;
  process.env.PATH = `${binDir}:${originalPath}`;

  try {
    const cleanup = await plugin.setup(ctx);
    await new Promise((resolve) => setTimeout(resolve, 300));
    await cleanup();
    await new Promise((resolve) => setTimeout(resolve, 300));
  } finally {
    process.env.PATH = originalPath;
  }

  const calls = readFileSync(log, "utf8");
  assert.match(calls, /rename-window -t %990001 Fix login/);
  assert.doesNotMatch(calls, /automatic-rename/);
});
