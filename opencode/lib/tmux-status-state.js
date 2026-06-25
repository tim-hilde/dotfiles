// Pure, timer-injectable state machine for the tmux-status plugin.
//
// Lives outside plugins/ on purpose: opencode loads every export of a
// plugins/*.js file as a plugin factory, so the reducer is kept here and
// imported by the plugin. This module has no IO and no real timers — all
// side effects are injected, which makes the idle-settle timing testable.
//
// Why a settle delay: opencode emits a transient `idle` between steps within
// a single turn, then resumes with `busy`. Marking the pane "done" on the
// first idle made it flip idle -> working repeatedly. We instead debounce the
// idle: a busy arriving inside the window cancels the pending "done".

export const IDLE_SETTLE_MS = 1000;
export const WORKING_DEBOUNCE_MS = 300;

export function createStatusMachine({
  now = () => Date.now(),
  setTimer = (fn, ms) => setTimeout(fn, ms),
  clearTimer = (h) => clearTimeout(h),
  onChange = () => {},
  initialState = "done",
} = {}) {
  let state = initialState;
  let title = "";
  let waiting = false; // sticky: blocked on the user (permission / question / plan_exit)
  let workingTimer = null;
  let idleTimer = null;
  const subagents = new Set();
  let rootSessionId = null;

  const clearWorkingTimer = () => {
    if (workingTimer !== null) {
      clearTimer(workingTimer);
      workingTimer = null;
    }
  };

  const clearIdleTimer = () => {
    if (idleTimer !== null) {
      clearTimer(idleTimer);
      idleTimer = null;
    }
  };

  const commit = (next) => {
    if (next === state) return;
    state = next;
    onChange({ state, title });
  };

  const setWorking = () => {
    waiting = false;
    clearIdleTimer(); // any busy pulse cancels a pending settle-to-done
    if (state === "working") return;
    if (workingTimer === null) {
      // Debounce so sub-300ms blips don't churn the state file.
      workingTimer = setTimer(() => {
        workingTimer = null;
        if (!waiting) commit("working");
      }, WORKING_DEBOUNCE_MS);
    }
  };

  const setWaiting = () => {
    clearWorkingTimer();
    clearIdleTimer();
    waiting = true;
    commit("waiting");
  };

  // Schedule "done" instead of committing immediately. A later busy/working or
  // waiting transition clears this timer, so transient mid-turn idles are
  // absorbed. Only a sustained idle (no busy for IDLE_SETTLE_MS) settles.
  const scheduleDone = () => {
    clearWorkingTimer();
    clearIdleTimer();
    idleTimer = setTimer(() => {
      idleTimer = null;
      waiting = false;
      commit("done");
    }, IDLE_SETTLE_MS);
  };

  // A subagent going idle means the root is still working -> ignore it.
  // Any other (root) idle starts the settle countdown.
  const onIdle = (sid) => {
    if (sid && subagents.has(sid)) return;
    scheduleDone();
  };

  const setTitle = (next) => {
    if (typeof next !== "string" || next === title) return;
    title = next;
    onChange({ state, title });
  };

  const handleEvent = (event) => {
    const type = event && event.type;
    const props = (event && event.properties) || {};

    switch (type) {
      case "session.created":
      case "session.updated": {
        const info = props.info || {};
        if (info.parentID) {
          if (info.id) subagents.add(info.id);
          break;
        }
        if (info.id) rootSessionId = info.id;
        setTitle(info.title);
        break;
      }
      case "session.status": {
        const t = props.status && props.status.type;
        if (t === "busy") setWorking();
        else if (t === "idle") onIdle(props.sessionID);
        // "retry" — keep current state.
        break;
      }
      case "session.idle":
        onIdle(props.sessionID);
        break;
      case "session.error":
        onIdle(props.sessionID);
        break;
      case "session.deleted": {
        const sid = props.info && props.info.id;
        if (sid) subagents.delete(sid);
        break;
      }
      // A permission prompt is published as a bus event (the plugin
      // "permission.ask" hook is unreliable across versions). The session
      // stays busy meanwhile, so without this it would just read "working".
      case "permission.asked":
      case "permission.updated":
        setWaiting();
        break;
      case "permission.replied":
        // User answered -> work resumes; a later idle settles it to done.
        setWorking();
        break;
      // NB: message.updated is intentionally NOT a "working" trigger. opencode
      // 1.17.x re-emits the user prompt's message.updated AFTER the turn goes
      // idle, which previously reverted the pane to "working" and left finished
      // sessions stuck. session.status busy is the authoritative working signal.
    }
  };

  return {
    handleEvent,
    markWaiting: setWaiting, // for the permission.ask hook & tool.execute.before
    getState: () => state,
    getTitle: () => title,
    getRootSessionId: () => rootSessionId,
    getSnapshot: () => ({ state, title }),
  };
}
