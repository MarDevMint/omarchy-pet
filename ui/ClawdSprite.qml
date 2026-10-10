import QtQuick
import "../lib/Moves.js" as Moves
import "../lib/Colors.js" as Colors

// One cell of Clawd's atlas. Size it by height; width follows the cell ratio.
// `tint` recolours his body (GPU shader, only when it differs from classic).
Item {
  id: root

  property var move: Moves.MOVES.rest
  property int frame: 0
  property bool smooth: false
  property color tint: Colors.CLASSIC

  readonly property bool recoloured: !Qt.colorEqual(tint, Colors.CLASSIC)

  implicitWidth: height * Moves.CELL_WIDTH / Moves.CELL_HEIGHT
  clip: true

  Image {
    width: root.width * Moves.COLUMNS
    height: root.height * Moves.ROWS
    x: -(root.frame % root.move.frames) * root.width
    y: -root.move.row * root.height
    source: Qt.resolvedUrl("../assets/clawd/spritesheet.png")
    smooth: root.smooth
    mipmap: root.smooth
    asynchronous: true

    layer.enabled: root.recoloured
    layer.smooth: root.smooth
    layer.effect: ShaderEffect {
      property color target: root.tint
      fragmentShader: Qt.resolvedUrl("../assets/shaders/recolor.frag.qsb")
    }
  }
}
