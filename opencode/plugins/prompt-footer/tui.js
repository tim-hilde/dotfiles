// Replaces the built-in footer, which is disabled via "-opencode.prompt.footer" in cli.json.
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

    const offSlot = ctx.ui.slot({
      append: "prompt.footer",
      render: promptFooter(ctx, runStart),
    });

    return () => {
      offs.forEach((off) => off());
      offSlot();
    };
  },
};
