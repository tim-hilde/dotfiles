import { createTps } from "../../lib/tps.js";

const DELTA_EVENTS = [
  "session.text.delta",
  "session.reasoning.delta",
  "session.tool.input.delta",
];

export default {
  id: "tps",
  async setup(ctx) {
    // Loaded lazily: the JSX runtime only resolves inside the OpenCode host, not under node.
    const { tpsFooter } = await import("./footer.jsx");
    const tps = createTps();

    const offs = DELTA_EVENTS.map((type) =>
      ctx.data.on(type, (event) => tps.delta(event.data.sessionID, event.data.delta, Date.now())),
    );

    const offSlot = ctx.ui.slot({
      append: "prompt.footer.status",
      render: tpsFooter(ctx, tps),
    });

    return () => {
      offs.forEach((off) => off());
      offSlot();
    };
  },
};
