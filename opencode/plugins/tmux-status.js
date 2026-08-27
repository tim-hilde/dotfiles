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
import { createStatusStore, mergeSnapshots } from "../lib/tmux-status-state.js";
import { reapStale, isProcessAlive } from "../lib/tmux-status-reap.js";

const STATE_DIR =
  process.env.OC_TMUX_STATE_DIR || join(homedir(), ".cache", "opencode-tmux");

// opencode builds one plugin instance per workspace directory and drops every
// bus event whose location.directory does not match it. A single tmux pane can
// therefore host several instances, each seeing only its own slice of the
// stream. They share this module-scope registry and publish one merged state
// instead of overwriting each other's file.
const workspaces = new Map();

const TmuxStatus = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return {};

  const id = String(pane).replace(/^%/, "");
  const file = join(STATE_DIR, `${id}.json`);
  const tmpFile = join(STATE_DIR, `${id}.${process.pid}.tmp`);
  const project = directory ? basename(directory) : "";

  try {
    mkdirSync(STATE_DIR, { recursive: true });
  } catch {}

  // Reap files left behind by crashed/killed sessions (no clean exit means the
  // cleanup below never ran for them).
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
  const publish = () => {
    const merged = mergeSnapshots(workspaces.values());
    const payload = JSON.stringify({
      pane,
      state: merged.state,
      title: merged.title,
      project: merged.project,
      pid: process.pid,
      updatedAt: Date.now(),
    });
    try {
      writeFileSync(tmpFile, payload);
      renameSync(tmpFile, file);
    } catch {}
  };

  const store = createStatusStore({
    onChange: (snapshot) => {
      workspaces.set(directory, { ...snapshot, project });
      publish();
    },
  });
  workspaces.set(directory, { ...store.getSnapshot(), project });

  // Coalesce bursts: opencode publishes session.status busy once per loop step
  // and both session.status{idle} and session.idle when a run ends.
  let pulling = false;
  let dirty = false;
  const refresh = async () => {
    if (pulling) {
      dirty = true;
      return;
    }
    pulling = true;
    try {
      do {
        dirty = false;
        const result = await client.session.status({ query: { directory } });
        const statuses = result?.data ?? result ?? {};
        store.setBusy(
          Object.values(statuses).some(
            (s) => s?.type === "busy" || s?.type === "retry",
          ),
        );
      } while (dirty);
    } catch {
    } finally {
      pulling = false;
    }
  };

  const cleanup = () => {
    workspaces.delete(directory);
    if (workspaces.size === 0) {
      try {
        rmSync(file);
      } catch {}
      return;
    }
    publish();
  };

  process.once("exit", cleanup);

  publish();
  refresh();

  return {
    event: async ({ event }) => {
      const type = event && event.type;
      const props = (event && event.properties) || {};

      switch (type) {
        case "session.created":
        case "session.updated": {
          const info = props.info || {};
          if (!info.parentID) store.setTitle(info.title);
          break;
        }
        case "session.status":
        case "session.idle":
        case "session.error":
          await refresh();
          break;
        case "question.asked":
          store.askQuestion(props.id);
          break;
        case "question.replied":
        case "question.rejected":
          store.replyQuestion(props.requestID);
          break;
        case "permission.asked":
          store.askPermission(props.id);
          break;
        case "permission.replied":
          store.replyPermission(props.requestID);
          break;
      }
    },
    dispose: async () => cleanup(),
  };
};

export default TmuxStatus;
