// Replaces the built-in footer, which is disabled via "-opencode.prompt.footer" in cli.json.
import { execFile } from "node:child_process";
import { findPullRequestUrlInHistory, PR_FIELDS, pullRequestFetcher } from "../../lib/pull-request.js";

const runGh = (url) =>
  new Promise((resolve, reject) =>
    execFile("gh", ["pr", "view", url, "--json", PR_FIELDS], { timeout: 10_000 }, (error, stdout) =>
      error ? reject(error) : resolve(stdout),
    ),
  );

const openUrl = (url) => execFile("open", [url], () => {});

const ENDED_EVENTS = [
  "session.execution.succeeded",
  "session.execution.failed",
  "session.execution.interrupted",
];

export default {
  id: "prompt-footer",
  async setup(ctx) {
    // Loaded lazily: the JSX runtime only resolves inside the OpenCode host, not under node.
    const { promptFooter } = await import("./footer.jsx");
    const runStarts = new Map();

    const offs = [
      ctx.data.on("session.execution.started", (event) => runStarts.set(event.data.sessionID, event.created)),
      ...ENDED_EVENTS.map((type) => ctx.data.on(type, (event) => runStarts.delete(event.data.sessionID))),
    ];

    // Runs already in progress when the TUI started have no start event; their session creation time is the best guess.
    const runStart = (sessionID) => runStarts.get(sessionID) ?? ctx.data.session.get(sessionID)?.time.created;

    // The TUI store only holds a recent window of a session; older messages are read once per session from the server.
    const historyUrls = new Map();
    const historyUrl = (sessionID) => {
      if (!historyUrls.has(sessionID)) {
        const page = (cursor) =>
          ctx.client.message.list(
            cursor ? { sessionID, limit: 200, cursor } : { sessionID, limit: 200, order: "desc" },
          );
        historyUrls.set(sessionID, findPullRequestUrlInHistory(page));
      }
      return historyUrls.get(sessionID);
    };

    const offSlot = ctx.ui.slot({
      append: "prompt.footer",
      render: promptFooter(ctx, runStart, pullRequestFetcher(runGh), historyUrl, openUrl),
    });

    return () => {
      offs.forEach((off) => off());
      offSlot();
    };
  },
};
