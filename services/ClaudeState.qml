import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Moves.js" as Moves
import "../lib/Util.js" as LibUtil

// What Claude Code is doing, read from the state file bin/claudepet-hook
// keeps in XDG_RUNTIME_DIR. Short-lived states (done, error) expire to idle.
Item {
  id: root

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
  readonly property string stateFile: runtimeDir + "/mar-claudepet/state.json"
  readonly property string settingsFile:
    (Quickshell.env("CLAUDE_CONFIG_DIR") || Quickshell.env("HOME") + "/.claude") + "/settings.json"

  property var raw: ({ state: "idle", detail: "", t: 0, sessions: 0 })
  property string state: "idle"
  readonly property string detail: state === raw.state ? String(raw.detail || "") : ""
  readonly property int sessions: Number(raw.sessions || 0)
  readonly property string label: Moves.stateLabel(state)
    + (detail === "" ? "" : " · " + detail)
  property bool hooksInstalled: false

  // Every live Claude Code session, oldest first:
  // {id, project, cwd, state, detail, tool, t, pid, since}
  // done/error expire to idle per agent too (holdMs in lib/Moves.js).
  property double now: Date.now()
  readonly property var agents: (Array.isArray(raw.agents) ? raw.agents : []).map(function(a) {
    var hold = (Moves.STATES[a.state] || {}).holdMs
    if (hold === undefined || root.now - Number(a.t || 0) <= hold) return a
    var copy = {}
    for (var k in a) copy[k] = a[k]
    copy.state = "idle"
    copy.detail = ""
    return copy
  })
  // Agents doing something right now, and those also waiting on the user.
  readonly property int workingCount: agents.filter(function(a) { return root.isBusy(a.state) }).length
  readonly property int waitingCount: agents.filter(function(a) { return a.state === "waiting" }).length
  readonly property int activeCount: workingCount + waitingCount

  function isBusy(name) {
    return name === "thinking" || name === "reading" || name === "building" || name === "working"
  }

  function refresh() {
    var s = Moves.state(String(raw.state || "idle"))
    var hold = Moves.STATES[s].holdMs
    if (hold !== undefined && Date.now() - Number(raw.t || 0) > hold) s = "idle"
    if (s !== state) state = s
  }

  function apply(text) {
    try {
      var parsed = JSON.parse(String(text || "{}"))
      if (parsed && typeof parsed.state === "string") raw = parsed
    } catch (error) {
      // Half-written or missing file: keep the last good state.
    }
    refresh()
  }

  function reload() {
    stateView.reload()
    settingsView.reload()
  }

  FileView {
    id: stateView
    path: root.runtimeDir === "" ? "" : root.stateFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("")
  }

  FileView {
    id: settingsView
    path: root.settingsFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.hooksInstalled = String(text() || "").indexOf("mar.claudepet/bin/claudepet-hook") >= 0
    onLoadFailed: root.hooksInstalled = false
  }

  // A terminal closed abruptly never runs SessionEnd; have the hook prune
  // dead sessions and rebuild state.json every 30 s (about 20 ms of work).
  Process {
    id: refresher
    command: [LibUtil.localPath(Qt.resolvedUrl("../bin/claudepet-hook")), "--refresh"]
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!refresher.running) refresher.running = true
  }

  // The hook replaces state.json atomically, which can drop the file watch;
  // re-read it every couple of seconds (an in-process read, no subprocess).
  // Also expires done/error on time.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      root.now = Date.now()
      stateView.reload()
    }
  }
}
