import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../lib/Moves.js" as Moves

// A transparent full-screen layer holding one Clawd per agent
// (DeskClawd.qml), or the classic Clawd when no Claude Code session is open.
// Clawds can be dragged anywhere. Only the Clawds take clicks (mask);
// everything else passes through to the windows below.
PanelWindow {
  id: root

  property var agents: []            // ClaudeState.agents
  property var fallbackMove: Moves.MOVES.rest
  property string fallbackText: ""
  property var previewMove: null     // a move previewed from the panel
  property bool musicPlaying: false
  property string musicLabel: "Listening to music"
  property var colourFor: function(cwd) { return "#c97159" }
  // {cwd: {x, y}} as 0..1 of the screen, saved while pinned. Older saves
  // hold a bare number (x along the bottom); those still load.
  property var positions: ({})
  property bool pinned: false
  property bool roam: true
  property real petScale: 0.55
  property bool smoothScaling: false
  property bool animate: true
  property real speed: 1.0
  property int maxShown: 7

  // (pinned, {cwd: {x, y}}) — the caller saves both.
  signal pinRequested(bool pinned, var positions)

  readonly property bool hasAgents: agents.length > 0
  // A count, not an array: ClaudeState hands out a fresh agents array every
  // couple of seconds, and an array model would rebuild every Clawd each
  // time (killing a drag halfway and snapping him back).
  readonly property int clawdCount: hasAgents ? Math.min(agents.length, maxShown) : 1
  readonly property var fallbackAgent: ({ cwd: "", fallback: true })
  property var maskRegions: []

  function currentPositions() {
    var out = {}
    for (var i = 0; i < clawdRepeater.count; i++) {
      var c = clawdRepeater.itemAt(i)
      if (c && c.position) out[c.key] = c.position
    }
    return out
  }

  function walkAll() {
    for (var i = 0; i < clawdRepeater.count; i++)
      if (clawdRepeater.itemAt(i)) clawdRepeater.itemAt(i).startWalk()
  }

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "mar-claudepet"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  mask: Region { regions: root.maskRegions }

  Repeater {
    id: clawdRepeater
    model: root.clawdCount

    DeskClawd {
      required property int index
      readonly property var modelData: root.hasAgents ? (root.agents[index] || root.fallbackAgent) : root.fallbackAgent
      readonly property var saved: root.positions[key]
      readonly property string key: modelData.cwd || ""
      readonly property bool isFallback: !!modelData.fallback
      readonly property string agentState: isFallback ? "idle" : Moves.state(modelData.state)

      anchors.fill: parent
      move: root.previewMove
        || (isFallback ? root.fallbackMove : Moves.moveForState(agentState, root.musicPlaying))
      canWander: root.roam && root.animate && Moves.isIdle(agentState) && !root.previewMove
      pinned: root.pinned
      startX: saved === undefined || saved === null ? -1
        : (typeof saved === "object" ? Number(saved.x) : Number(saved))
      startY: saved !== null && typeof saved === "object" ? Number(saved.y) : -1
      spawnX: Math.max(0.05, 0.85 - index * 0.12)
      petScale: root.petScale
      smoothScaling: root.smoothScaling
      animate: root.animate
      speed: root.speed
      tint: isFallback ? "#c97159" : root.colourFor(key)
      bubbleText: isFallback ? root.fallbackText
        : agentState === "idle"
          ? (root.musicPlaying ? root.musicLabel : "Resting")
          : Moves.stateLabel(agentState) + (modelData.detail ? " · " + modelData.detail : "")
      bubbleForced: agentState === "waiting" || agentState === "error" || agentState === "done"

      onTouched: playOnce("laptop", 2)
      onPinToggled: root.pinRequested(!root.pinned, root.currentPositions())
      onDropped: if (root.pinned) root.pinRequested(true, root.currentPositions())
    }
  }

  // One click region per Clawd, kept in step with the Repeater.
  Instantiator {
    model: clawdRepeater.count
    delegate: Region {
      required property int index
      item: clawdRepeater.itemAt(index) ? clawdRepeater.itemAt(index).hitArea : null
    }
    onObjectAdded: function(i, region) {
      var next = root.maskRegions.slice()
      next.splice(i, 0, region)
      root.maskRegions = next
    }
    onObjectRemoved: function(i, region) {
      root.maskRegions = root.maskRegions.filter(function(r) { return r !== region })
    }
  }
}
