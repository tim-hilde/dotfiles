/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import { createMemo, For, Show } from "solid-js"

const LABELS: Record<string, string> = {
  connected: "Connected",
  pending: "Connecting",
  failed: "Error",
  disabled: "Disabled",
  needs_auth: "Sign in",
}

function McpView(props: { context: any; sessionID: string }) {
  const context = props.context
  const theme = () => context.theme
  const [view, updateView] = context.storage.store("view", { initial: { open: true } })
  const session = createMemo(() => context.data.session.get(props.sessionID))
  const servers = createMemo(() => context.data.location.mcp.server.list(session()?.location) ?? [])
  const active = createMemo(() => servers().filter((server: any) => server.status.status === "connected").length)
  const errors = createMemo(
    () => servers().filter((server: any) => ["failed", "needs_auth"].includes(server.status.status)).length,
  )
  const collapsible = () => servers().length > 2
  const color = (status: string) => {
    if (status === "connected") return theme().text.feedback.success.base
    if (status === "failed") return theme().text.feedback.error.base
    if (status === "needs_auth") return theme().text.feedback.warning.base
    return theme().text.muted
  }

  return (
    <Show when={servers().length > 0}>
      <box flexDirection="column">
        <box
          flexDirection="row"
          gap={1}
          onMouseDown={() =>
            collapsible() && updateView((draft: any) => void (draft.open = !draft.open)).catch(console.error)
          }
        >
          <Show when={collapsible()}>
            <text fg={theme().text.base}>{view.open ? "▼" : "▶"}</text>
          </Show>
          <text fg={theme().text.base}>
            <b>MCP</b>
            <Show when={!view.open}>
              <span style={{ fg: theme().text.muted }}>
                {` (${active()} active${errors() > 0 ? `, ${errors()} error${errors() > 1 ? "s" : ""}` : ""})`}
              </span>
            </Show>
          </text>
        </box>
        <Show when={!collapsible() || view.open}>
          <For each={servers()}>
            {(server: any) => (
              <box
                flexDirection="row"
                gap={1}
                minWidth={0}
                onMouseUp={() => context.keymap.dispatch("mcp.list")}
              >
                <text flexShrink={0} style={{ fg: color(server.status.status) }}>
                  •
                </text>
                <text fg={theme().text.base} wrapMode="none" truncate flexGrow={1} flexShrink={1} minWidth={0}>
                  <b>{server.name}</b>
                </text>
                <text
                  wrapMode="none"
                  flexShrink={0}
                  fg={server.status.status === "failed" ? theme().text.feedback.error.base : theme().text.muted}
                >
                  {LABELS[server.status.status] ?? server.status.status}
                </text>
              </box>
            )}
          </For>
        </Show>
      </box>
    </Show>
  )
}

export default Plugin.define({
  id: "local.mcp-sidebar",
  setup(context: any) {
    return context.ui.slot({
      append: "sidebar.content",
      render: (props: { sessionID: string }) => <McpView context={context} sessionID={props.sessionID} />,
    })
  },
})
