// Stale-file sweep for the tmux-status plugin.
//
// Lives outside plugins/ for the same reason as tmux-status-state.js: kept
// pure with injected IO so the staleness logic is testable without touching
// the real filesystem or spawning processes.
//
// The plugin only deletes its own state file on a clean `process.once("exit")`,
// which never fires on SIGKILL/crash. Orphans then sit in the state dir
// forever. The status bar reader already ignores them (it only scans live
// tmux panes and checks pid liveness), so this sweep is purely disk hygiene:
// each new opencode launch reaps dead siblings' leftover files.

export function isProcessAlive(pid) {
  if (!pid) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    // EPERM: process exists but we don't own it -> treat as alive.
    return err && err.code === "EPERM";
  }
}

const TMP_PID_RE = /\.(\d+)\.tmp$/;

export function reapStale({ dir, readdir, readFile, rm, isAlive }) {
  let entries;
  try {
    entries = readdir(dir);
  } catch {
    return;
  }

  for (const entry of entries) {
    let pid = null;

    if (entry.endsWith(".json")) {
      try {
        const data = JSON.parse(readFile(`${dir}/${entry}`));
        pid = data && data.pid;
      } catch {
        pid = null; // corrupt/unparseable -> treat as stale
      }
      if (pid && isAlive(pid)) continue;
    } else {
      const match = TMP_PID_RE.exec(entry);
      if (!match) continue; // not a file this plugin owns
      pid = Number(match[1]);
      if (isAlive(pid)) continue;
    }

    try {
      rm(`${dir}/${entry}`, { force: true });
    } catch {}
  }
}
