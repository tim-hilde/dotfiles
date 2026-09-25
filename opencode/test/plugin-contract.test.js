// Run: node --experimental-strip-types --test test/*.test.js lib/*.test.js
// (opencode/package.json is gitignored, so the npm script lives only locally.)
//
// Pins the module-entry contract opencode's plugin loader enforces. The loader
// is identical in 1.18.x and v2: it prefers a default `{ server }` object and
// otherwise iterates every export, throwing on any non-function export.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Keep import-time side effects out of the test: tmux-status only touches the
// filesystem after its TMUX guard, so leaving TMUX unset makes the factory a
// no-op. The state dir is pinned regardless, in case a developer runs the
// suite inside a tmux session.
delete process.env.TMUX;
delete process.env.TMUX_PANE;
process.env.OC_TMUX_STATE_DIR = mkdtempSync(join(tmpdir(), "oc-plugin-contract-"));

const pluginsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "plugins");

const HOOK_KEYS = new Set([
  "event",
  "config",
  "tool",
  "auth",
  "provider",
  "dispose",
  "chat.message",
  "chat.params",
  "chat.headers",
  "permission.ask",
  "command.execute.before",
  "shell.env",
  "tool.execute.before",
  "tool.execute.after",
  "tool.definition",
  "experimental.chat.messages.transform",
  "experimental.chat.system.transform",
  "experimental.session.compacting",
  "experimental.text.complete",
]);

const isFactory = (value) =>
  typeof value === "function" ||
  (value !== null &&
    typeof value === "object" &&
    typeof value.server === "function");

const files = readdirSync(pluginsDir).filter((f) => /\.(js|ts)$/.test(f));

for (const file of files) {
  test(`${file} is a loadable opencode plugin module`, async () => {
    const mod = await import(join(pluginsDir, file));

    // opencode's loader iterates every export when the default is not a
    // PluginModule object; any non-function export then throws
    // "Plugin export is not a function".
    for (const value of Object.values(mod)) {
      assert.ok(
        isFactory(value),
        `${file} exports a value that is not a plugin factory: ${String(value)}`,
      );
    }

    assert.ok("default" in mod, `${file} must have a default export`);
    assert.notEqual(
      typeof mod.default,
      "function",
      `${file} default export regressed to a bare function; use { server }`,
    );
    assert.equal(typeof mod.default, "object", `${file} default must be an object`);
    // File-source (auto-discovered) plugins must declare an id: the loader
    // throws "Path plugin <path> must export id" otherwise.
    assert.equal(
      typeof mod.default.id,
      "string",
      `${file} must export a string id`,
    );
    assert.ok(mod.default.id.trim().length > 0, `${file} id must be non-empty`);
    assert.equal(
      typeof mod.default.server,
      "function",
      `${file} default.server must be a function`,
    );
    assert.equal(
      mod.default.tui,
      undefined,
      `${file} must not export tui() and server() together`,
    );

    const hooks = await mod.default.server(
      {
        client: { session: { status: async () => ({ data: {} }) } },
        project: {},
        directory: process.cwd(),
        worktree: process.cwd(),
        serverUrl: new URL("http://127.0.0.1:4096"),
        $: () => {},
      },
      undefined,
    );

    assert.ok(
      hooks && typeof hooks === "object",
      `${file} factory must return a hooks object`,
    );
    for (const key of Object.keys(hooks)) {
      assert.ok(HOOK_KEYS.has(key), `${file} returned an unknown hook key: ${key}`);
    }
    if ("dispose" in hooks) {
      assert.equal(typeof hooks.dispose, "function", `${file} dispose must be a function`);
    }
  });
}
