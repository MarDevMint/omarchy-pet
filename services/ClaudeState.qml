import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Moves.js" as Moves

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

  // The hook replaces state.json atomically, which can drop the file watch;
  // re-read it every couple of seconds (an in-process read, no subprocess).
  // Also expires done/error on time.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: stateView.reload()
  }
}
