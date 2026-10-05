// Port of OpenCode 2's built-in prompt footer (opencode.prompt.footer) logic,
// extended with how long subagents and shells have been running.

export function formatDuration(ms) {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const pad = (n) => String(n).padStart(2, "0");
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m${pad(seconds % 60)}s`;
  return `${Math.floor(minutes / 60)}h${pad(minutes % 60)}m`;
}

export function activityLabel(count, noun, starts, now) {
  if (count === 0) return undefined;
  const label = `${count} ${noun}${count === 1 ? "" : "s"}`;
  const known = starts.filter((start) => start !== undefined);
  if (known.length === 0) return label;
  return `${label} (${formatDuration(now - Math.min(...known))})`;
}

function lastAssistant(messages, revertID) {
  const revertIndex = revertID ? messages.findIndex((message) => message.id === revertID) : -1;
  if (revertID && revertIndex === -1) return undefined;
  const end = revertIndex === -1 ? messages.length : revertIndex;
  const compaction = messages.findLastIndex(
    (message, index) => message.type === "compaction" && message.status === "completed" && index < end,
  );
  return messages.findLast(
    (message, index) => message.type === "assistant" && message.tokens !== undefined && index > compaction && index < end,
  );
}

export function contextUsage(messages, models, revertID) {
  const message = lastAssistant(messages, revertID);
  if (!message) return undefined;
  const { input, output, reasoning, cache } = message.tokens;
  const tokens = input + output + reasoning + cache.read + cache.write;
  if (tokens <= 0) return undefined;
  const model = models?.find((m) => m.providerID === message.model.providerID && m.id === message.model.id);
  return { tokens, percent: model?.limit.context ? Math.round((tokens / model.limit.context) * 100) : undefined };
}

function formatTokens(tokens) {
  if (tokens >= 1e6) return `${(tokens / 1e6).toFixed(1)}M`;
  if (tokens >= 1000) return `${(tokens / 1000).toFixed(1)}K`;
  return String(tokens);
}

export function usageLabel({ tokens, percent }) {
  const label = formatTokens(tokens);
  return percent === undefined ? label : `${label} (${percent}%)`;
}

export function footerLayout({ width, usage, commands }) {
  if (usage.length === 0) return { usage: false, shortcuts: width >= 44 };
  const available = Math.max(0, width - 8);
  const room = available - Math.min(28, Math.floor(available / 2));
  const usageText = usage.join(" · ");
  const shortcuts = commands ? `${commands} commands` : "";
  if (shortcuts && `${usageText} · ${shortcuts}`.length <= room) return { usage: true, shortcuts: true };
  return { usage: usageText.length <= room, shortcuts: false };
}
