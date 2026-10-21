/** @jsxImportSource @opentui/solid */
import { createEffect, createMemo, createSignal, Match, onCleanup, Show, Switch } from "solid-js";
import { useTerminalDimensions } from "@opentui/solid";
import { activityLabel, contextUsage, footerLayout, usageLabel } from "../../lib/prompt-footer.js";
import { pullRequestSymbol } from "../../lib/pull-request.js";

const TICK_MS = 1000;
const PR_POLL_MS = 30_000;
const GITHUB_ICON = "\uf408";
const currency = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

function PromptFooter(props) {
  const { ctx } = props;
  const { data, theme } = ctx;
  const dimensions = useTerminalDimensions();
  const [hover, setHover] = createSignal(false);
  const [now, setNow] = createSignal(Date.now());
  const timer = setInterval(() => setNow(Date.now()), TICK_MS);
  onCleanup(() => clearInterval(timer));

  const shortcut = (id) => ctx.keymap.shortcuts(id)[0];

  const subagents = createMemo(() => {
    if (!props.sessionID) return undefined;
    const running = data.session
      .family(props.sessionID)
      .filter((id) => id !== props.sessionID && data.session.status(id) === "running");
    return activityLabel(running.length, "subagent", running.map(props.runStart), now());
  });

  const shells = createMemo(() => {
    if (!props.sessionID) return undefined;
    const own = data.shell.list(ctx.location).filter((shell) => shell.metadata.sessionID === props.sessionID);
    const starts = own.filter((shell) => shell.status === "running").map((shell) => shell.time.started);
    return activityLabel(own.length, "shell", starts, now());
  });

  const usage = createMemo(() => {
    if (!props.sessionID) return [];
    const session = data.session.get(props.sessionID);
    if (!session) return [];
    const context = contextUsage(
      data.session.message.list(props.sessionID),
      data.location.model.list(session.location),
      session.revert?.messageID,
    );
    const cost = data.session.cost(props.sessionID);
    return [context ? usageLabel(context) : undefined, cost > 0 ? currency.format(cost) : undefined].filter(Boolean);
  });

  const [pr, setPr] = createSignal();
  createEffect(() => {
    const sessionID = props.sessionID;
    if (!sessionID) return setPr(undefined);
    const directory = data.session.get(sessionID)?.location?.directory ?? data.location.default().directory;
    let live = true;
    const load = () =>
      props.pullRequest(directory).then((value) => {
        if (live) setPr(value);
      });
    load();
    const poll = setInterval(load, PR_POLL_MS);
    onCleanup(() => {
      live = false;
      clearInterval(poll);
    });
  });
  const [prHover, setPrHover] = createSignal(false);
  const prText = () => (pr() ? `${GITHUB_ICON} #${pr().number} ${pullRequestSymbol(pr().kind)}` : undefined);
  const prTone = () => {
    const feedback = theme.text.feedback;
    const kind = pr()?.kind;
    if (kind === "open") return feedback.success.base;
    if (kind === "merged") return feedback.info.base;
    if (kind === "closed") return feedback.error.base;
    return theme.text.muted;
  };

  const active = () => Boolean(subagents() || shells());
  const layout = createMemo(() =>
    footerLayout({
      width: dimensions().width,
      usage: [...usage(), prText()].filter(Boolean),
      commands: shortcut("command.palette.show"),
    }),
  );
  const showUsage = () => props.showDetails && layout().usage && usage().length > 0;
  const showPr = () => props.showDetails && layout().usage && Boolean(pr());

  return (
    <Switch>
      <Match when={props.mode === "normal"}>
        <Switch>
          <Match when={active() || usage().length > 0 || pr()}>
            <box flexDirection="row" minWidth={0} flexShrink={props.showDetails && layout().usage ? 0 : 1}>
              <Show when={active()}>
                <box
                  flexShrink={0}
                  onMouseOver={() => setHover(true)}
                  onMouseOut={() => setHover(false)}
                  onMouseUp={() => ctx.keymap.dispatch("session.child.first")}
                >
                  <text wrapMode="none" fg={hover() ? theme.text.base : theme.text.muted}>
                    <Show when={shortcut("session.child.first")}>
                      {(key) => <span style={{ fg: theme.text.base }}>{key()} </span>}
                    </Show>
                    {[subagents(), shells()].filter(Boolean).join(" · ")}
                  </text>
                </box>
              </Show>
              <Show when={showUsage()}>
                <text wrapMode="none" flexShrink={0} fg={theme.text.muted}>
                  {active() ? " · " : ""}
                  {usage().join(" · ")}
                </text>
              </Show>
              <Show when={showPr()}>
                <box
                  flexShrink={0}
                  onMouseOver={() => setPrHover(true)}
                  onMouseOut={() => setPrHover(false)}
                  onMouseUp={() => props.openUrl(pr().url)}
                >
                  <text wrapMode="none" fg={prHover() ? theme.text.base : theme.text.muted}>
                    {active() || showUsage() ? " · " : ""}
                    {`${GITHUB_ICON} #${pr().number} `}
                    <span style={{ fg: prTone() }}>{pullRequestSymbol(pr().kind)}</span>
                  </text>
                </box>
              </Show>
            </box>
          </Match>
          <Match when={props.showDetails && layout().shortcuts}>
            <text flexShrink={0} fg={theme.text.base}>
              {shortcut("agent.cycle")} <span style={{ fg: theme.text.muted }}>agents</span>
            </text>
          </Match>
        </Switch>
        <Show when={props.showDetails && layout().shortcuts}>
          <text wrapMode="none" flexShrink={0} fg={theme.text.base}>
            {shortcut("command.palette.show")} <span style={{ fg: theme.text.muted }}>commands</span>
          </text>
        </Show>
      </Match>
      <Match when={props.mode === "shell"}>
        <text flexShrink={0} fg={theme.text.base}>
          esc <span style={{ fg: theme.text.muted }}>{dimensions().width < 44 ? "shell" : "exit shell mode"}</span>
        </text>
      </Match>
    </Switch>
  );
}

export const promptFooter = (ctx, runStart, pullRequest, openUrl) => (props) => (
  <PromptFooter
    ctx={ctx}
    runStart={runStart}
    pullRequest={pullRequest}
    openUrl={openUrl}
    sessionID={props.sessionID}
    mode={props.mode}
    showDetails={props.showDetails}
  />
);
