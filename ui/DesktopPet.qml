import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../lib/Moves.js" as Moves

// Clawd on the desktop: a strip along the bottom of the screen. Only Clawd
// himself takes clicks (mask); everything else passes through to the windows
// below. Wanders while allowed, otherwise stands and shows `move`.
PanelWindow {
  id: root

  property var move: Moves.MOVES.rest
  property bool canWander: false
  property bool pinned: false
  property real pinX: -1           // 0..1 along the strip, -1 = default spot
  property real petScale: 0.55
  property bool smoothScaling: false
  property bool animate: true
  property real speed: 1.0
  property real walkSpeed: 28      // px per second
  property string bubbleText: ""
  property bool bubbleForced: false

  signal touched()
  signal pinRequested(bool pinned, real fraction)

  readonly property real petW: Moves.CELL_WIDTH * petScale
  readonly property real petH: Moves.CELL_HEIGHT * petScale
  readonly property real maxX: Math.max(0, width - petW)
  readonly property bool walking: walkAnim.running
  readonly property var shownMove: walking
    ? Moves.move(walkingRight ? "walkRight" : "walkLeft") : move
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

  function requestPin(isPinned) {
    pinRequested(isPinned, maxX > 0 ? pet.x / maxX : -1)
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
  implicitHeight: Math.ceil(petH + bubble.height + Style.spacing.sm)
  mask: Region { item: pet }

  onMaxXChanged: if (pet.x > maxX) pet.x = maxX
  onCanWanderChanged: if (!canWander && walkAnim.running) walkAnim.stop()
  onPinnedChanged: if (pinned && walkAnim.running) walkAnim.stop()
  onShownMoveChanged: frame = 0

  Timer {
    id: restTimer
    interval: 6000 + Math.random() * 10000
    running: root.visible && root.canWander && !root.pinned && !root.walking && !root.dragging
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
    onTriggered: root.frame = (root.frame + 1) % root.shownMove.frames
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
    y: root.height - height
    // Starting spot. Walking and dragging take over x afterwards.
    x: root.pinX >= 0 ? root.pinX * root.maxX : root.maxX * 0.85

    ClawdSprite {
      anchors.fill: parent
      move: root.shownMove
      frame: root.animate ? root.frame : 0
      smooth: root.smoothScaling
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
      drag.target: pet
      drag.axis: Drag.XAxis
      drag.minimumX: 0
      drag.maximumX: root.maxX
      property bool moved: false

      onPressed: { moved = false; walkAnim.stop() }
      onPositionChanged: if (drag.active) { moved = true; root.dragging = true }
      onReleased: {
        root.dragging = false
        if (moved && root.pinned) root.requestPin(true)
      }
      onClicked: function(event) {
        if (moved) return
        if (event.button === Qt.RightButton) root.requestPin(!root.pinned)
        else root.touched()
      }
    }
  }

  // Speech bubble: on hover, and on its own when the caller forces it
  // (Claude needs you, failed, just finished).
  Rectangle {
    id: bubble
    readonly property bool shown: mouse.containsMouse || root.bubbleForced
    width: bubbleLabel.implicitWidth + Style.spacing.md * 2
    height: bubbleLabel.implicitHeight + Style.spacing.sm * 2
    x: Math.max(0, Math.min(root.width - width, pet.x + pet.width / 2 - width / 2))
    y: pet.y + pet.height * 0.3 - height
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
