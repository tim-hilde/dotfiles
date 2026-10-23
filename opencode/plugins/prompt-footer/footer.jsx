/** @jsxImportSource @opentui/solid */
import { createMemo, createSignal, Match, onCleanup, Show, Switch } from "solid-js";
import { useTerminalDimensions } from "@opentui/solid";
import { activityLabel, contextUsage, footerLayout, usageLabel } from "../../lib/prompt-footer.js";

const TICK_MS = 1000;
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

  const active = () => Boolean(subagents() || shells());
  const layout = createMemo(() =>
    footerLayout({ width: dimensions().width, usage: usage(), commands: shortcut("command.palette.show") }),
  );

  return (
    <Switch>
      <Match when={props.mode === "normal"}>
        <Switch>
          <Match when={active() || usage().length > 0}>
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
              <Show when={props.showDetails && layout().usage && usage().length > 0}>
                <text wrapMode="none" flexShrink={0} fg={theme.text.muted}>
                  {active() ? " · " : ""}
                  {usage().join(" · ")}
                </text>
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

export const promptFooter = (ctx, runStart) => (props) => (
  <PromptFooter
    ctx={ctx}
    runStart={runStart}
    sessionID={props.sessionID}
    mode={props.mode}
    showDetails={props.showDetails}
  />
);
