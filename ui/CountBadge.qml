import QtQuick
import qs.Commons

// Corner badge, styled like the notification bell's (jgarza.notification):
// "Count" shows a number pill, "Dot" a small dot, "None" nothing.
// Anchor it to the top-right of the icon it decorates.
Item {
  id: root

  property string style: "Count"
  property int count: 0
  property string fontFamily: Style.font.family

  width: pill.visible ? pill.width : dot.width
  height: pill.visible ? pill.height : dot.height
  visible: count > 0 && style !== "None"

  Rectangle {
    id: dot
    visible: root.style === "Dot"
    width: Style.space(6)
    height: width
    radius: width / 2
    color: Color.accent
  }

  Rectangle {
    id: pill
    visible: root.style === "Count"
    width: Math.max(label.implicitWidth + Style.space(6), Style.space(12))
    height: Style.space(12)
    radius: height / 2
    color: Color.accent

    Text {
      id: label
      anchors.centerIn: parent
      text: root.count > 99 ? "99+" : String(root.count)
      textFormat: Text.PlainText
      font.family: root.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - Style.space(3))
      font.bold: true
      color: Color.background
    }
  }
}
