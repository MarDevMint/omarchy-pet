import QtQuick
import "../lib/Moves.js" as Moves

// One small Clawd per agent, side by side in the bar, each showing what
// its own session is doing. Hover one for its project and state.
//
// Clicks: the bar slot sits on top of every widget with its own MouseArea
// (for drag-to-reorder) and only lets left clicks through to MouseAreas
// below, never to TapHandlers. So each Clawd registers itself as a bar click
// target (`triggerPress`), the same contract WidgetButton uses: left clicks
// arrive from the slot, and also while another panel is open. Right and
// middle clicks are not taken by the slot and reach the MouseArea directly.
Row {
  id: root

  property var agents: []
  property bool musicPlaying: false
  property int tick: 0
  property bool animate: true
  property bool smoothScaling: false
  property real spriteHeight: 24
  property int maxShown: 7
  property QtObject bar: null
  property var colourFor: function(cwd) { return "#c97159" }

  signal clicked(var agent, int button)

  spacing: 0

  Repeater {
    // A count, not the agents array: ClaudeState hands out a fresh array
    // every couple of seconds, and an array model would rebuild every
    // sprite each time (dropping clicks, hovers and click targets).
    model: Math.min(root.agents.length, root.maxShown)

    ClawdSprite {
      id: sprite
      required property int index
      readonly property var agent: root.agents[index] || ({})
      property QtObject registeredBar: null

      height: root.spriteHeight
      width: implicitWidth
      move: Moves.moveForState(Moves.state(agent.state), root.musicPlaying)
      frame: root.animate ? root.tick : 0
      smooth: root.smoothScaling
      tint: root.colourFor(agent.cwd)

      function triggerPress(button) {
        root.clicked(sprite.agent, button)
      }

      function syncClickTarget() {
        if (registeredBar === root.bar) return
        if (registeredBar) registeredBar.unregisterClickTarget(sprite)
        registeredBar = root.bar
        if (registeredBar) registeredBar.registerClickTarget(sprite)
      }

      Component.onCompleted: syncClickTarget()
      Component.onDestruction: if (registeredBar) registeredBar.unregisterClickTarget(sprite)

      Connections {
        target: root
        function onBarChanged() { sprite.syncClickTarget() }
      }

      HoverHandler {
        onHoveredChanged: {
          if (!root.bar) return
          if (hovered) root.bar.showTooltip(sprite, (sprite.agent.project || "unknown")
            + " · " + Moves.stateLabel(sprite.agent.state)
            + (sprite.agent.detail ? " · " + sprite.agent.detail : ""))
          else root.bar.hideTooltip(sprite)
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
