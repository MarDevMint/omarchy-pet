import QtQuick
import qs.Commons
import "../lib/Moves.js" as Moves

// One Clawd on the desktop (see DesktopPet.qml). Fills the screen; only
// `hitArea` (Clawd himself) takes clicks. Starts on the bottom edge, can be
// dragged anywhere, and wanders sideways at whatever height he was left at.
// Left-click: laptop. Right-click: pin all. Drag: move.
Item {
  id: root

  property var move: Moves.MOVES.rest
  property bool canWander: false
  property bool pinned: false
  property real startX: -1          // 0..1 across the screen, -1 = `spawnX`
  property real startY: -1          // 0..1 down the screen, -1 = bottom edge
  property real spawnX: 0.85
  property real petScale: 0.55
  property bool smoothScaling: false
  property bool animate: true
  property real speed: 1.0
  property color tint: "#c97159"
  property real walkSpeed: 28       // px per second
  property string bubbleText: ""
  property bool bubbleForced: false

  signal touched()
  signal pinToggled()
  signal dropped()

  readonly property Item hitArea: pet
  // Where he stands, as 0..1 of the room he has (what gets saved).
  readonly property var position: maxX > 0 && maxY > 0
    ? { x: pet.x / maxX, y: pet.y / maxY } : null
  readonly property real petW: Moves.CELL_WIDTH * petScale
  readonly property real petH: Moves.CELL_HEIGHT * petScale
  readonly property real maxX: Math.max(0, width - petW)
  readonly property real maxY: Math.max(0, height - petH)
  readonly property bool walking: walkAnim.running
  readonly property var shownMove: oneShot
    || (walking ? Moves.move(walkingRight ? "walkRight" : "walkLeft") : move)
  property var oneShot: null
  property int oneShotLoops: 0
  property bool walkingRight: true
  property bool dragging: false
  property int frame: 0

  function startWalk() {
    if (maxX <= 0 || pinned) return
    var from = pet.x
    var to = Math.random() * maxX
    if (Math.abs(to - from) < 80) to = from > maxX / 2 ? from - 160 : from + 160
    to = Math.max(0, Math.min(maxX, to))
    walkingRight = to > from
    walkAnim.to = to
    walkAnim.duration = Math.abs(to - from) / walkSpeed * 1000
    walkAnim.restart()
  }

  function playOnce(key, loops) {
    walkAnim.stop()
    oneShot = Moves.move(key)
    oneShotLoops = loops || 1
    frame = 0
  }

  onMaxXChanged: if (pet.x > maxX) pet.x = maxX
  onMaxYChanged: if (pet.y > maxY) pet.y = maxY
  onCanWanderChanged: if (!canWander && walkAnim.running) walkAnim.stop()
  onPinnedChanged: if (pinned && walkAnim.running) walkAnim.stop()
  onShownMoveChanged: frame = 0

  Timer {
    interval: 6000 + Math.random() * 10000
    running: root.visible && root.canWander && !root.pinned && !root.walking
      && !root.dragging && !root.oneShot
    repeat: false
    onTriggered: {
      root.startWalk()
      interval = 6000 + Math.random() * 10000
    }
  }

  Timer {
    interval: Moves.frameInterval(root.shownMove, root.speed)
    running: root.visible && root.animate
    repeat: true
    onTriggered: {
      if (root.frame + 1 < root.shownMove.frames) {
        root.frame++
        return
      }
      root.frame = 0
      if (root.oneShot && --root.oneShotLoops <= 0) root.oneShot = null
    }
  }

  NumberAnimation {
    id: walkAnim
    target: pet
    property: "x"
    easing.type: Easing.Linear
  }

  Item {
    id: pet
    width: root.petW
    height: root.petH
    // Starting spot. Walking and dragging take over afterwards.
    x: (root.startX >= 0 ? root.startX : root.spawnX) * root.maxX
    y: (root.startY >= 0 ? Math.min(1, root.startY) : 1) * root.maxY

    ClawdSprite {
      anchors.fill: parent
      move: root.shownMove
      frame: root.animate ? root.frame : 0
      smooth: root.smoothScaling
      tint: root.tint
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
      drag.target: pet
      drag.axis: Drag.XAndYAxis
      drag.minimumX: 0
      drag.maximumX: root.maxX
      drag.minimumY: 0
      drag.maximumY: root.maxY
      property bool moved: false

      onPressed: { moved = false; walkAnim.stop() }
      onPositionChanged: if (drag.active) { moved = true; root.dragging = true }
      onReleased: {
        root.dragging = false
        if (moved) root.dropped()
      }
      onClicked: function(event) {
        if (moved) return
        if (event.button === Qt.RightButton) root.pinToggled()
        else root.touched()
      }
    }
  }

  // Speech bubble: on hover, and on its own when forced (this agent needs
  // you, failed, or just finished).
  Rectangle {
    readonly property bool shown: mouse.containsMouse || root.bubbleForced
    width: bubbleLabel.implicitWidth + Style.spacing.md * 2
    height: bubbleLabel.implicitHeight + Style.spacing.sm * 2
    x: Math.max(0, Math.min(root.width - width, pet.x + pet.width / 2 - width / 2))
    // Above him, or below when he is up against the top edge.
    y: pet.y + pet.height * 0.3 - height >= 0
      ? pet.y + pet.height * 0.3 - height : pet.y + pet.height
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: 1
    opacity: shown && root.bubbleText !== "" ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Text {
      id: bubbleLabel
      anchors.centerIn: parent
      text: root.bubbleText + (root.pinned ? "  󰐃" : "")
      textFormat: Text.PlainText
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
