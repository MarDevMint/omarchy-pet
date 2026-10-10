import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lib/Moves.js" as Moves
import "services" as Services
import "ui" as UI

// Clawd, a Claude Code companion. Engine forked from OmaPets
// (yesmeck/OmaPets, MIT), now split up:
//
//   lib/Moves.js              moves, atlas layout, Claude state -> move
//   services/ClaudeState.qml  Claude Code state from bin/claudepet-hook
//   services/Music.qml        is any media player playing (MPRIS)
//   ui/ClawdSprite.qml        one atlas cell
//   ui/DesktopPet.qml         Clawd walking along the bottom of the screen
//   ui/PetPanel.qml           the panel that opens from the bar
//   tools/build-atlas         packs the GIFs into assets/clawd/spritesheet.png
//
// This file owns the settings, the animation clock and the bar icon.
BarWidget {
  id: root
  moduleName: "mar.claudepet"

  // --- settings --------------------------------------------------------------

  readonly property real petScale: Number(setting("scale", 1.0))
  readonly property real deskScale: Number(setting("deskScale", 0.55))
  readonly property real animationSpeed: Number(setting("animationSpeed", 1.0))
  readonly property bool smoothScaling: setting("smoothScaling", false) === true
  readonly property bool animate: setting("animate", true) !== false
  readonly property bool roam: setting("roam", true) !== false
  readonly property bool pinned: setting("pinned", false) === true
  readonly property real pinX: Number(setting("pinX", -1))

  function setting(key, fallback) {
    return settings && settings[key] !== undefined ? settings[key] : fallback
  }

  function setSettings(values) {
    var entry = { id: root.moduleName }
    for (var k in root.settings)
      if (k !== "id") entry[k] = root.settings[k]
    for (var v in values) entry[v] = values[v]
    var updated = false
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      updated = root.bar.shell.updateEntryInline(root.moduleName, entry)
    if (!updated) root.settings = entry
  }

  function setSetting(key, value) {
    var values = {}
    values[key] = value
    setSettings(values)
  }

  // --- what Clawd is doing ------------------------------------------------------

  Services.ClaudeState { id: claudeState }
  Services.Music { id: music }
  readonly property var claude: claudeState

  readonly property bool claudeIdle: Moves.isIdle(claude.state)
  readonly property var baseMove: Moves.moveForState(claude.state, music.playing)
  property var oneShot: null
  property int oneShotLoops: 0
  property int frame: 0
  readonly property var shownMove: oneShot || baseMove

  // "Resting" / "Listening to music" while idle, Claude's state otherwise.
  readonly property string moodLine: claudeIdle && claude.state === "idle"
    ? (music.playing ? "Listening to music" : "Resting")
    : claude.label
  readonly property string statusLine: "Claude Code · " + claude.label
    + (claude.sessions > 1 ? " (" + claude.sessions + " sessions)" : "")
    + (music.playing ? " · ♪" : "")

  function playOnce(key, loops) {
    oneShot = Moves.move(key)
    oneShotLoops = loops || 1
    frame = 0
    if (key.indexOf("walk") === 0) desk.startWalk()
  }

  onBaseMoveChanged: if (!oneShot) frame = 0
  onAnimateChanged: frame = 0

  // Frame clock. Stops entirely when animation is off.
  Timer {
    interval: Moves.frameInterval(root.shownMove, root.animationSpeed)
    running: root.animate
    repeat: true
    onTriggered: {
      if (root.frame + 1 < root.shownMove.frames) {
        root.frame++
        return
      }
      root.frame = 0
      if (root.oneShot && --root.oneShotLoops <= 0) root.oneShot = null
      root.claude.refresh()
    }
  }

  // --- Claude Code hooks ----------------------------------------------------

  property string hooksMessage: ""

  Process {
    id: hookInstaller
    running: false
    property bool removing: false
    onExited: function(exitCode) {
      if (exitCode !== 0) root.hooksMessage = "Could not update Claude Code settings"
      else if (removing) root.hooksMessage = "Hooks removed (backup kept)"
      else root.hooksMessage = "Hooks added. Restart open Claude Code sessions"
      root.claude.reload()
    }
  }

  function toggleHooks() {
    if (hookInstaller.running) return
    var script = decodeURIComponent(String(Qt.resolvedUrl("bin/install-hooks")).replace(/^file:\/\//, ""))
    hookInstaller.removing = claude.hooksInstalled
    hookInstaller.command = claude.hooksInstalled ? [script, "--uninstall"] : [script]
    hookInstaller.running = true
  }

  function togglePin() {
    desk.requestPin(!root.pinned)
  }

  IpcHandler {
    target: "mar.claudepet"

    function play(move: string): void { root.playOnce(move, 2) }
    function reload(): void { root.claude.reload() }
    function toggle(): void { root.panelOpen = !root.panelOpen }
    function walk(): void { desk.startWalk() }
    function pin(): void { root.togglePin() }
    function status(): string {
      return JSON.stringify({ claude: root.claude.state, music: music.playing,
        move: root.shownMove.key, pinned: root.pinned, walking: desk.walking })
    }
  }

  // --- bar icon ----------------------------------------------------------------

  property bool panelOpen: false

  function close() {
    panelOpen = false
  }

  implicitWidth: Math.round(barSprite.width) + Style.spacing.sm
  implicitHeight: barSize

  UI.ClawdSprite {
    id: barSprite
    height: root.barSize * root.petScale
    width: implicitWidth
    anchors.centerIn: parent
    move: root.shownMove
    frame: root.animate ? root.frame : 0
    smooth: root.smoothScaling

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) root.playOnce("laptop", 2)
        else root.panelOpen = !root.panelOpen
      }
    }
  }

  HoverHandler {
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, root.statusLine)
      else root.bar.hideTooltip(root)
    }
  }

  // --- desktop and panel --------------------------------------------------------

  UI.DesktopPet {
    id: desk
    readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
    screen: barWindow ? barWindow.screen : null
    visible: root.roam && barWindow !== null

    move: root.shownMove
    canWander: root.roam && root.animate && root.claudeIdle && !root.oneShot
    pinned: root.pinned
    pinX: root.pinX
    petScale: root.deskScale
    smoothScaling: root.smoothScaling
    animate: root.animate
    speed: root.animationSpeed
    bubbleText: root.moodLine
    bubbleForced: root.claude.state === "waiting" || root.claude.state === "error"
      || root.claude.state === "done"

    onTouched: root.playOnce("laptop", 2)
    onPinRequested: function(isPinned, fraction) {
      root.setSettings({ pinned: isPinned, pinX: fraction })
    }
  }

  UI.PetPanel {
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.panelOpen
    pet: root
  }
}
