import type { Plugin } from "@opencode-ai/plugin"

const MAX_LEN = 64

function sanitize(title: string): string {
  return title.replace(/[\r\n\t]+/g, " ").trim().slice(0, MAX_LEN)
}

export const TmuxTitle: Plugin = async ({ $ }) => {
  const pane = process.env.TMUX_PANE
  const inTmux = Boolean(process.env.TMUX && pane)

  if (inTmux) {
    // Best-effort: re-enable automatic-rename on clean exit so the window
    // name doesn't stay stale after opencode exits. Does not fire on SIGKILL.
    const restore = () => {
      try {
        const { execSync } = require("node:child_process")
        execSync(`tmux set -w -t ${pane} automatic-rename on`, { stdio: "ignore" })
      } catch {
        // tmux gone or pane closed – ignore
      }
    }
    process.once("SIGINT", () => { restore(); process.exit(130) })
    process.once("SIGTERM", () => { restore(); process.exit(143) })
    process.once("exit", restore)
  }

  return {
    event: async ({ event }) => {
      if (!inTmux) return
      if (event.type !== "session.updated" && event.type !== "session.created") return

      const info = (event as { properties: { info: { parentID?: string; title?: string } } }).properties.info
      if (info.parentID) return
      const title = sanitize(info.title ?? "")
      if (!title) return

      try {
        await $`tmux rename-window -t ${pane!} ${title}`.quiet()
      } catch {
        // tmux gone or pane closed – ignore
      }
    },
  }
}

export default TmuxTitle
