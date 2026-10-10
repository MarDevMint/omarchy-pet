import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../lib/Moves.js" as Moves

// The desktop strip along the bottom of the screen: one Clawd per agent
// (DeskClawd.qml), or the classic Clawd when no Claude Code session is open.
// Only the Clawds take clicks (mask); everything else passes through.
PanelWindow {
  id: root

  property var agents: []            // ClaudeState.agents
  property var fallbackMove: Moves.MOVES.rest
  property string fallbackText: ""
  property var previewMove: null     // a move previewed from the panel
  property bool musicPlaying: false
  property var colourFor: function(cwd) { return "#c97159" }
  property var positions: ({})       // {cwd: 0..1}, saved while pinned
  property bool pinned: false
  property bool roam: true
  property real petScale: 0.55
  property bool smoothScaling: false
  property bool animate: true
  property real speed: 1.0
  property int maxShown: 7

  // (pinned, {cwd: fraction}) — the caller saves both.
  signal pinRequested(bool pinned, var positions)

  readonly property bool hasAgents: agents.length > 0
  readonly property var clawds: hasAgents ? agents.slice(0, maxShown) : [{ cwd: "", fallback: true }]
  property var maskRegions: []

  function currentPositions() {
    var out = {}
    for (var i = 0; i < clawdRepeater.count; i++) {
      var c = clawdRepeater.itemAt(i)
      if (c && c.fraction >= 0) out[c.key] = c.fraction
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
    bottom: true
  }
  implicitHeight: Math.ceil(Moves.CELL_HEIGHT * petScale + Style.font.caption * 2.5 + Style.spacing.md)
  mask: Region { regions: root.maskRegions }

  Repeater {
    id: clawdRepeater
    model: root.clawds

    DeskClawd {
      required property var modelData
      required property int index
      readonly property string key: modelData.cwd || ""
      readonly property bool isFallback: !!modelData.fallback
      readonly property string agentState: isFallback ? "idle" : Moves.state(modelData.state)

      anchors.fill: parent
      move: root.previewMove
        || (isFallback ? root.fallbackMove : Moves.moveForState(agentState, root.musicPlaying))
      canWander: root.roam && root.animate && Moves.isIdle(agentState) && !root.previewMove
      pinned: root.pinned
      startX: root.positions[key] !== undefined ? Number(root.positions[key]) : -1
      spawnX: Math.max(0.05, 0.85 - index * 0.12)
      petScale: root.petScale
      smoothScaling: root.smoothScaling
      animate: root.animate
      speed: root.speed
      tint: isFallback ? "#c97159" : root.colourFor(key)
      bubbleText: isFallback ? root.fallbackText
        : (modelData.project || "unknown") + " · " + (agentState === "idle"
          ? (root.musicPlaying ? "Listening to music" : "Resting")
          : Moves.stateLabel(agentState) + (modelData.detail ? " · " + modelData.detail : ""))
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
