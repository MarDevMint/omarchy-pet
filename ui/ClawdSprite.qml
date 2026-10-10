import QtQuick
import "../lib/Moves.js" as Moves

// One cell of Clawd's atlas. Size it by height; width follows the cell ratio.
Item {
  id: root

  property var move: Moves.MOVES.rest
  property int frame: 0
  property bool smooth: false

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
  }
}
