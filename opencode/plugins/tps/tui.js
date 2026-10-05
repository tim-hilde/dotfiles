import { createTps } from "../../lib/tps.js";

export default {
  id: "tps",
  async setup(ctx) {
    // Loaded lazily: the JSX runtime only resolves inside the OpenCode host, not under node.
    const { tpsFooter } = await import("./footer.jsx");
    const tps = createTps();

    const DEBUG = "/private/var/folders/s0/fl6ny76n0lzb3ln_6yvt515c0000gn/T/opencode/tps-debug.ndjson";
    const dbg = { text: 0, reasoning: 0, n: 0, seen: new Set(), dup: 0, started: undefined, first: undefined, last: undefined };
    const track = (kind, event) => {
      const now = Date.now();
      const key = `${event.data.assistantMessageID}:${kind}:${event.data.ordinal}:${event.data.delta.length}:${event.data.delta.slice(0, 8)}`;
      if (dbg.seen.has(key)) dbg.dup++;
      dbg.seen.add(key);
      dbg[kind] += event.data.delta.length;
      dbg.n++;
      dbg.first ??= now;
      dbg.last = now;
    };

    const offs = [
      ctx.data.on("session.step.started", () => {
        dbg.started = Date.now();
      }),
      ctx.data.on("session.text.delta", (event) => {
        track("text", event);
        tps.delta(event.data.sessionID, event.data.delta, Date.now());
      }),
      ctx.data.on("session.reasoning.delta", (event) => {
        track("reasoning", event);
        tps.delta(event.data.sessionID, event.data.delta, Date.now());
      }),
      ctx.data.on("session.step.ended", async (event) => {
        const { output, reasoning } = event.data.tokens;
        const ended = Date.now();
        const { appendFileSync } = await import("node:fs");
        appendFileSync(
          DEBUG,
          JSON.stringify({
            tokens: event.data.tokens,
            finish: event.data.finish,
            chars: { text: dbg.text, reasoning: dbg.reasoning, deltas: dbg.n, dupDeltas: dbg.dup },
            stepMs: dbg.started ? ended - dbg.started : null,
            streamMs: dbg.first ? dbg.last - dbg.first : null,
            outputPerStepSec: dbg.started ? output / ((ended - dbg.started) / 1000) : null,
            outputPerStreamSec: dbg.first && dbg.last > dbg.first ? output / ((dbg.last - dbg.first) / 1000) : null,
            footerLabel: tps.label(event.data.sessionID, ended),
          }) + "\n",
        );
        Object.assign(dbg, { text: 0, reasoning: 0, n: 0, seen: new Set(), dup: 0, started: undefined, first: undefined, last: undefined });
        tps.stepEnded(event.data.sessionID, output + reasoning);
      }),
    ];

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
