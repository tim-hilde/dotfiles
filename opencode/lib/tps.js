// Live tokens-per-second estimate for the OpenCode 2 TUI footer.
//
// While a step streams, only deltas arrive — no token counts — so the rate is
// estimated from characters. The step's reported token usage is deliberately not
// used to calibrate this: it also counts tool-call arguments and provider-hidden
// reasoning that never stream as deltas, which skews the ratio badly.
const WINDOW_MS = 3000;
const MIN_SPAN_MS = 1000;
const CHARS_PER_TOKEN = 4;

export function createTps() {
  const sessions = new Map();

  return {
    delta(sessionID, text, now) {
      const samples = sessions.get(sessionID) ?? [];
      samples.push({ t: now, chars: text.length });
      sessions.set(sessionID, samples);
    },

    label(sessionID, now) {
      const samples = (sessions.get(sessionID) ?? []).filter((s) => s.t > now - WINDOW_MS);
      sessions.set(sessionID, samples);
      if (!samples.length) return "";
      const chars = samples.reduce((sum, s) => sum + s.chars, 0);
      const span = Math.min(WINDOW_MS, Math.max(MIN_SPAN_MS, now - samples[0].t));
      return `⚡ ${Math.round(chars / CHARS_PER_TOKEN / (span / 1000))} tok/s`;
    },
  };
}
