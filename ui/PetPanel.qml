import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../lib/Moves.js" as Moves

// The panel that opens from the bar. Compact on purpose: it has to fit a
// 1366x768 screen. Reads and drives everything through `pet` (Main.qml).
KeyboardPanel {
  id: root

  required property var pet

  contentWidth: root.fittedContentWidth(Style.space(300))
  contentHeight: root.fittedContentHeight(column.implicitHeight)

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: column
      width: parent.width
      spacing: Style.spacing.sm

      Row {
        width: parent.width
        spacing: Style.spacing.md

        ClawdSprite {
          id: hero
          height: Style.space(84)
          move: root.pet.shownMove
          frame: root.pet.frame
          smooth: root.pet.smoothScaling

          MouseArea {
            anchors.fill: parent
            onClicked: root.pet.playOnce("laptop", 2)
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - hero.width - parent.spacing
          spacing: Style.spacing.xs

          Text {
            width: parent.width
            text: "Clawd"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            textFormat: Text.PlainText
          }

          Text {
            width: parent.width
            text: root.pet.statusLine
            color: Color.foreground
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }
        }
      }

      PanelSectionHeader {
        width: parent.width
        text: "Moves · click to preview"
      }

      Grid {
        id: moveGrid
        width: parent.width
        columns: 3
        spacing: Style.spacing.sm

        Repeater {
          model: Moves.PANEL_MOVES

          Button {
            required property string modelData
            readonly property var move: Moves.move(modelData)
            width: (moveGrid.width - moveGrid.spacing * 2) / 3
            text: move.label
            bordered: true
            focusable: true
            selected: root.pet.shownMove.label === move.label
            onClicked: root.pet.playOnce(modelData, 2)
          }
        }
      }

      PanelSectionHeader {
        width: parent.width
        text: "Options"
      }

      Toggle {
        width: parent.width
        label: "Walk on desktop"
        checked: root.pet.roam
        onClicked: root.pet.setSetting("roam", !root.pet.roam)
      }

      Toggle {
        width: parent.width
        label: "Pin in place"
        description: "Right-click Clawd to toggle, drag to move"
        checked: root.pet.pinned
        onClicked: root.pet.togglePin()
      }

      Toggle {
        width: parent.width
        label: "Animate"
        checked: root.pet.animate
        onClicked: root.pet.setSetting("animate", !root.pet.animate)
      }

      Toggle {
        width: parent.width
        label: "Smooth scaling"
        checked: root.pet.smoothScaling
        onClicked: root.pet.setSetting("smoothScaling", !root.pet.smoothScaling)
      }

      Toggle {
        width: parent.width
        label: "Claude Code hooks"
        description: root.pet.hooksMessage !== "" ? root.pet.hooksMessage
          : (root.pet.claude.hooksInstalled ? "" : "Off: Clawd can't see Claude yet")
        checked: root.pet.claude.hooksInstalled
        onClicked: root.pet.toggleHooks()
      }
    }
  }
}
