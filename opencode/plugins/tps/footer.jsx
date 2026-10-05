/** @jsxImportSource @opentui/solid */
import { createSignal, onCleanup, Show } from "solid-js";

const REFRESH_MS = 500;

function TpsFooter(props) {
  const read = () => (props.sessionID ? props.tps.label(props.sessionID, Date.now()) : "");
  const [label, setLabel] = createSignal(read());
  const timer = setInterval(() => setLabel(read()), REFRESH_MS);
  onCleanup(() => clearInterval(timer));

  return (
    <Show when={label()}>
      <text fg={props.ctx.theme.text.muted}>{label()}</text>
    </Show>
  );
}

export const tpsFooter = (ctx, tps) => (props) => (
  <TpsFooter ctx={ctx} tps={tps} sessionID={props.sessionID} />
);
