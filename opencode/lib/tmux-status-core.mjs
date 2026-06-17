export const INITIAL = "done";

export function sanitizePaneId(pane) {
  return String(pane).replace(/^%/, "");
}

export function freshTracker() {
  return { state: INITIAL, title: "", rootSessionId: null, subagents: new Set() };
}

export function stateForTool(tool) {
  return tool === "question" || tool === "plan_exit" ? "waiting" : null;
}

// Updates tracker (title / rootSessionId / subagents / state) as a side effect
// and returns the new state string, or null when the event changes no state.
export function reduceEvent(tracker, event) {
  const type = event && event.type;
  const props = (event && event.properties) || {};
  let next = null;
  switch (type) {
    case "session.created":
    case "session.updated": {
      const info = props.info || {};
      if (info.parentID) {
        if (info.id) tracker.subagents.add(info.id);
      } else {
        if (info.id) tracker.rootSessionId = info.id;
        if (typeof info.title === "string") tracker.title = info.title;
      }
      break;
    }
    case "session.deleted": {
      const id = props.info && props.info.id;
      if (id) tracker.subagents.delete(id);
      break;
    }
    case "message.updated":
      next = props.info && props.info.role === "user" ? "working" : null;
      break;
    case "session.status":
      next = props.status && props.status.type === "busy" ? "working" : null;
      break;
    case "session.idle": {
      const id = props.sessionID;
      next = id && tracker.subagents.has(id) ? null : "done";
      break;
    }
    case "session.error":
      next = "done";
      break;
  }
  if (next !== null) tracker.state = next;
  return next;
}
