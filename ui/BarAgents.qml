import QtQuick
import "../lib/Moves.js" as Moves

// One small Clawd per agent, side by side in the bar, each showing what
// its own session is doing. Hover one for its project and state.
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

  signal clicked()

  spacing: 0

  Repeater {
    model: root.agents.slice(0, root.maxShown)

    ClawdSprite {
      id: sprite
      required property var modelData
      height: root.spriteHeight
      width: implicitWidth
      move: Moves.moveForState(Moves.state(modelData.state), root.musicPlaying)
      frame: root.animate ? root.tick : 0
      smooth: root.smoothScaling

      HoverHandler {
        onHoveredChanged: {
          if (!root.bar) return
          if (hovered) root.bar.showTooltip(sprite, (sprite.modelData.project || "unknown")
            + " · " + Moves.stateLabel(sprite.modelData.state)
            + (sprite.modelData.detail ? " · " + sprite.modelData.detail : ""))
          else root.bar.hideTooltip(sprite)
        }
      }

      TapHandler {
        onTapped: root.clicked()
      }
    }
  }
}
