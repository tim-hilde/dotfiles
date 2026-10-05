// Tokens-per-second estimate for the OpenCode 2 TUI footer.
//
// While a step streams, only text deltas arrive — no token counts — so the live
// rate is estimated from characters. When the step ends, the real token count
// calibrates the chars-per-token ratio and yields the step's final rate.
const WINDOW_MS = 3000;
const MIN_SPAN_MS = 1000;
const MIN_STEP_MS = 500;
const DEFAULT_CHARS_PER_TOKEN = 4;

export function createTps() {
  const sessions = new Map();

  const state = (id) => {
    let s = sessions.get(id);
    if (!s) {
      s = { samples: [], step: undefined, charsPerToken: DEFAULT_CHARS_PER_TOKEN, last: undefined };
      sessions.set(id, s);
    }
    return s;
  };

  return {
    delta(sessionID, text, now) {
      const s = state(sessionID);
      s.samples.push({ t: now, chars: text.length });
      s.step ??= { firstT: now, lastT: now, chars: 0 };
      s.step.lastT = now;
      s.step.chars += text.length;
    },

    stepEnded(sessionID, tokens) {
      const s = state(sessionID);
      const step = s.step;
      s.step = undefined;
      if (!step || tokens <= 0 || step.lastT - step.firstT < MIN_STEP_MS) return;
      s.charsPerToken = step.chars / tokens;
      s.last = tokens / ((step.lastT - step.firstT) / 1000);
    },

    label(sessionID, now) {
      const s = sessions.get(sessionID);
      if (!s) return "";
      s.samples = s.samples.filter((sample) => sample.t > now - WINDOW_MS);
      if (s.samples.length) {
        const chars = s.samples.reduce((sum, sample) => sum + sample.chars, 0);
        const span = Math.min(WINDOW_MS, Math.max(MIN_SPAN_MS, now - s.samples[0].t));
        return `⚡ ${Math.round(chars / s.charsPerToken / (span / 1000))} tok/s`;
      }
      return s.last === undefined ? "" : `⌀ ${Math.round(s.last)} tok/s`;
    },
  };
}
