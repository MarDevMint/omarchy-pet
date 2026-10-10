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
        text: "Agents · " + root.pet.claude.activeCount + " active of " + root.pet.claude.agents.length
      }

      Text {
        width: parent.width
        visible: root.pet.claude.agents.length === 0
        text: "No Claude Code sessions open"
        color: Color.foreground
        opacity: 0.6
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }

      Repeater {
        model: root.pet.claude.agents

        // One line per agent: project, then what it is doing.
        Item {
          required property var modelData
          width: column.width
          height: agentName.implicitHeight + Style.spacing.xs

          Text {
            id: agentName
            anchors.left: parent.left
            width: parent.width * 0.5
            text: modelData.project || "unknown"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
          }

          Text {
            anchors.right: parent.right
            width: parent.width * 0.5 - Style.spacing.sm
            horizontalAlignment: Text.AlignRight
            text: Moves.stateLabel(modelData.state)
              + (modelData.detail ? " · " + modelData.detail : "")
            color: modelData.state === "waiting" ? Color.accent : Color.foreground
            opacity: root.pet.claude.isBusy(modelData.state) || modelData.state === "waiting" ? 1 : 0.55
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
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

      // Bar layout and badge, as chip rows to stay compact.
      Repeater {
        model: [
          { key: "barStyle", label: "Bar", options: ["Single", "Agents"] },
          { key: "badge", label: "Badge", options: ["Count", "Dot", "None"] }
        ]

        Item {
          required property var modelData
          width: column.width
          height: chips.implicitHeight

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            textFormat: Text.PlainText
          }

          ButtonGroup {
            id: chips
            anchors.right: parent.right
            options: modelData.options
            value: String(root.pet[modelData.key])
            fontSize: Style.font.caption
            onChanged: function(v) { root.pet.setSetting(modelData.key, v) }
          }
        }
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

      // Desktop size: 100% is the full size (deskScale 0.55).
      Item {
        width: parent.width
        height: sizeLabel.implicitHeight + sizeSlider.implicitHeight + Style.spacing.xs

        Text {
          id: sizeLabel
          text: "Desktop size"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          textFormat: Text.PlainText
        }

        Text {
          anchors.right: parent.right
          text: Math.round(sizeSlider.liveValue) + "%"
          color: Color.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }

        PanelSlider {
          id: sizeSlider
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          bar: root.pet.bar
          minimum: 30
          maximum: 100
          step: 5
          integer: true
          value: Math.round(root.pet.deskScale / root.pet.fullDeskScale * 100)
          onReleased: function(v) {
            root.pet.setSetting("deskScale", Math.round(v) / 100 * root.pet.fullDeskScale)
          }
        }
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
