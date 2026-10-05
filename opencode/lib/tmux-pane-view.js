// Derives the tmux pane state for an OpenCode 2 TUI from its plugin context.
//
// Mirrors the TUI's own session-tab badge: a session counts with its whole
// family (root plus subagents); a pending permission or form means "waiting",
// a running member means "working". So does a member's running shell: an idle
// agent with a background command is resumed once that command finishes.
import { basename } from "node:path";

export function derivePaneView({ data, ui, location }) {
  const route = ui.router.current();
  const shownID = route?.type === "session" ? route.sessionID : undefined;
  const tabIDs = ui.tabs.enabled() ? ui.tabs.list().map((tab) => tab.sessionID) : [];

  const roots = new Set([shownID, ...tabIDs].filter(Boolean).map((id) => data.session.root(id)));
  const members = [...roots].flatMap((root) => {
    const family = data.session.family(root);
    return family.length ? family : [root];
  });

  const pending = (id) =>
    (data.session.permission.list(id)?.length ?? 0) > 0 ||
    (data.session.form.list(id)?.length ?? 0) > 0;
  const hasRunningShell = (root) =>
    data.shell
      .list(data.session.get(root)?.location)
      .some(
        (shell) => shell.status === "running" && members.includes(shell.metadata.sessionID),
      );
  const state = members.some(pending)
    ? "waiting"
    : members.some((id) => data.session.status(id) === "running") ||
        [...roots].some(hasRunningShell)
      ? "working"
      : "done";

  const shown = shownID ? data.session.get(data.session.root(shownID)) : undefined;
  const directory =
    shown?.location?.directory ?? (location ?? data.location.default()).directory;

  return { state, title: shown?.title ?? "", project: basename(directory) };
}
