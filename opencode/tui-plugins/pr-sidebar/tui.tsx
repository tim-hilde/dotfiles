/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import { execFile } from "node:child_process"
import { createEffect, createMemo, createSignal, For, onCleanup, Show } from "solid-js"
import {
  findPullRequestUrls,
  findPullRequestUrlsInHistory,
  mergePullRequestUrls,
  PR_FIELDS,
  pullRequestFetcher,
  pullRequestSymbol,
  truncateEnd,
} from "../../lib/pull-request.js"

const POLL_MS = 30_000
const GITHUB_ICON = "\uf408"

const runGh = (url: string) =>
  new Promise<string>((resolve, reject) =>
    execFile("gh", ["pr", "view", url, "--json", PR_FIELDS], { timeout: 10_000 }, (error, stdout) =>
      error ? reject(error) : resolve(stdout),
    ),
  )

const openUrl = (url: string) => execFile("open", [url], () => {})

function PullRequestsView(props: {
  context: any
  sessionID: string
  fetchPullRequest: (url: string) => Promise<any>
  historyUrls: (sessionID: string) => Promise<string[]>
}) {
  const { data, theme } = props.context
  const [history, setHistory] = createSignal<string[]>([])
  const [pullRequests, setPullRequests] = createSignal<any[]>([])
  const [hovered, setHovered] = createSignal<string>()
  const [titleWidth, setTitleWidth] = createSignal<number>()
  const [view, updateView] = props.context.storage.store("view", { initial: { open: true } })

  createEffect(() => {
    const sessionID = props.sessionID
    setHistory([])
    let live = true
    props.historyUrls(sessionID).then((urls) => live && setHistory(urls))
    onCleanup(() => (live = false))
  })

  const urls = createMemo(() =>
    mergePullRequestUrls([...history(), ...findPullRequestUrls(data.session.message.list(props.sessionID))]),
  )

  createEffect(() => {
    const current = urls()
    if (current.length === 0) return setPullRequests([])
    let live = true
    const load = () =>
      Promise.all(current.map(props.fetchPullRequest)).then((list) => live && setPullRequests(list.filter(Boolean)))
    load()
    const poll = setInterval(load, POLL_MS)
    onCleanup(() => {
      live = false
      clearInterval(poll)
    })
  })

  const collapsible = () => pullRequests().length > 2

  return (
    <Show when={pullRequests().length > 0}>
      <box flexDirection="column">
        <box
          flexDirection="row"
          gap={1}
          onMouseDown={() =>
            collapsible() && updateView((draft: any) => void (draft.open = !draft.open)).catch(console.error)
          }
        >
          <Show when={collapsible()}>
            <text fg={theme.text.base}>{view.open ? "▼" : "▶"}</text>
          </Show>
          <text fg={theme.text.base}>
            <b>{`${GITHUB_ICON} Pull requests`}</b>
            <Show when={collapsible() && !view.open}>
              <span style={{ fg: theme.text.muted }}>{` (${pullRequests().length})`}</span>
            </Show>
          </text>
        </box>
        <Show when={!collapsible() || view.open}>
          <For each={pullRequests()}>
            {(pr: any) => (
              <box
                flexDirection="row"
                gap={1}
                minWidth={0}
                onMouseOver={() => setHovered(pr.url)}
                onMouseOut={() => setHovered(undefined)}
                onMouseUp={() => openUrl(pr.url)}
              >
                <box
                  flexGrow={1}
                  flexShrink={1}
                  minWidth={0}
                  onSizeChange={function (this: any) {
                    setTitleWidth(this.width)
                  }}
                >
                  <text fg={hovered() === pr.url ? theme.text.base : theme.text.muted} wrapMode="none">
                    {truncateEnd(`#${pr.number} ${pr.title}`, titleWidth())}
                  </text>
                </box>
                <text flexShrink={0} fg={hovered() === pr.url ? theme.text.base : theme.text.muted}>
                  {pullRequestSymbol(pr.kind)}
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
  id: "local.pr-sidebar",
  setup(context: any) {
    const fetchPullRequest = pullRequestFetcher(runGh)
    // The TUI store only holds a recent window of a session; older messages are read once per session from the server.
    const histories = new Map<string, Promise<string[]>>()
    const historyUrls = (sessionID: string) => {
      if (!histories.has(sessionID)) {
        const page = (cursor?: string) =>
          context.client.message.list(
            cursor ? { sessionID, limit: 200, cursor } : { sessionID, limit: 200, order: "desc" },
          )
        histories.set(sessionID, findPullRequestUrlsInHistory(page))
      }
      return histories.get(sessionID)!
    }

    return context.ui.slot({
      append: "sidebar.content",
      render: (props: { sessionID: string }) => (
        <PullRequestsView
          context={context}
          sessionID={props.sessionID}
          fetchPullRequest={fetchPullRequest}
          historyUrls={historyUrls}
        />
      ),
    })
  },
})
