import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lib/Moves.js" as Moves
import "lib/Util.js" as LibUtil
import "lib/Colors.js" as Colors
import "services" as Services
import "ui" as UI

// Clawd, a Claude Code companion. Engine forked from OmaPets
// (yesmeck/OmaPets, MIT), now split up:
//
//   lib/Moves.js              moves, atlas layout, Claude state -> move
//   lib/Colors.js             agent colours (per project), palette
//   services/ClaudeState.qml  Claude Code state from bin/claudepet-hook
//   services/Music.qml        is any media player playing (MPRIS)
//   ui/ClawdSprite.qml        one atlas cell
//   ui/DesktopPet.qml         desktop strip, one Clawd per agent
//   ui/DeskClawd.qml          one walking Clawd (drag, bubble, pin)
//   ui/BarAgents.qml          one small Clawd per agent in the bar
//   ui/CountBadge.qml         notification-style badge
//   ui/PetPanel.qml           the panel that opens from the bar
//   tools/build-atlas         packs the GIFs into assets/clawd/spritesheet.png
//   tools/build-shaders       compiles assets/shaders (body recolour)
//
// This file owns the settings, the animation clock and the bar icon.
BarWidget {
  id: root
  moduleName: "mar.claudepet"

  // --- settings --------------------------------------------------------------

  readonly property real petScale: Number(setting("scale", 1.0))
  readonly property real fullDeskScale: 0.55   // "100%" in the panel
  readonly property real deskScale: Number(setting("deskScale", fullDeskScale))
  readonly property real animationSpeed: Number(setting("animationSpeed", 1.0))
  readonly property bool smoothScaling: setting("smoothScaling", false) === true
  readonly property bool animate: setting("animate", true) !== false
  readonly property bool roam: setting("roam", true) !== false
  readonly property bool pinned: setting("pinned", false) === true
  // {cwd: 0..1}: where each project's Clawd stands when pinned.
  readonly property var deskPositions: setting("deskPositions", ({}))
  // Bar: "Single" = one Clawd + badge, "Agents" = one Clawd per session.
  readonly property string barStyle: String(setting("barStyle", "Single"))
  // Badge on the single Clawd: "Count", "Dot" or "None".
  readonly property string badge: String(setting("badge", "Count"))
  // {cwd: "#rrggbb"}: one colour per project, see lib/Colors.js.
  readonly property var agentColors: setting("agentColors", ({}))

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

  // --- agent colours -----------------------------------------------------------

  function colourFor(cwd) {
    return Colors.colourFor(agentColors, cwd)
  }

  function setAgentColour(cwd, hex) {
    if (!cwd || !Colors.normalized(hex)) return
    var next = {}
    for (var k in agentColors) next[k] = agentColors[k]
    next[cwd] = Colors.normalized(hex)
    setSetting("agentColors", next)
  }

  // New projects get a colour as soon as they show up.
  function assignColours() {
    var next = Colors.assign(agentColors, claude.agents)
    if (next) setSetting("agentColors", next)
  }

  Connections {
    target: root.claude
    function onAgentsChanged() { Qt.callLater(root.assignColours) }
  }

  // The single Clawd wears the colour of the agent that matters most now.
  readonly property color mainTint: claude.agents.length > 0
    ? colourFor(claude.raw.cwd) : Colors.CLASSIC
  readonly property var baseMove: Moves.moveForState(claude.state, music.playing)
  property var oneShot: null
  property int oneShotLoops: 0
  property int frame: 0
  readonly property var shownMove: oneShot || baseMove

  // "Resting" / "Listening to music" while idle, Claude's state otherwise.
  readonly property string moodLine: claudeIdle && claude.state === "idle"
    ? (music.playing ? music.label : "Resting")
    : claude.label
  readonly property string statusLine: "Claude Code · " + claude.label
    + (claude.sessions > 1 ? " (" + claude.sessions + " sessions)" : "")
    + (music.playing ? " · ♪" : "")

  function playOnce(key, loops) {
    oneShot = Moves.move(key)
    oneShotLoops = loops || 1
    frame = 0
    if (key.indexOf("walk") === 0) desk.walkAll()
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
    var script = LibUtil.localPath(Qt.resolvedUrl("bin/install-hooks"))
    hookInstaller.removing = claude.hooksInstalled
    hookInstaller.command = claude.hooksInstalled ? [script, "--uninstall"] : [script]
    hookInstaller.running = true
  }

  function togglePin() {
    desk.pinRequested(!root.pinned, desk.currentPositions())
  }

  IpcHandler {
    target: "mar.claudepet"

    function play(move: string): void { root.playOnce(move, 2) }
    function reload(): void { root.claude.reload() }
    function toggle(): void { root.panelOpen = !root.panelOpen }
    function walk(): void { desk.walkAll() }
    function pin(): void { root.togglePin() }
    function pickColour(cwd: string): void { root.panelOpen = true; petPanel.editingCwd = cwd }
    function status(): string {
      return JSON.stringify({ claude: root.claude.state, music: music.playing,
        move: root.shownMove.key, pinned: root.pinned, agents: root.claude.agents.length })
    }
  }

  // --- bar icon ----------------------------------------------------------------

  property bool panelOpen: false

  function close() {
    panelOpen = false
  }

  readonly property bool showAgents: barStyle === "Agents" && claude.agents.length > 0

  // Steady clock for the per-agent sprites (each loops its own move).
  property int tick: 0
  Timer {
    interval: Moves.frameInterval(Moves.MOVES.music, root.animationSpeed)
    running: root.animate && root.showAgents
    repeat: true
    onTriggered: root.tick++
  }

  implicitWidth: (showAgents ? Math.round(barAgents.implicitWidth) : Math.round(barSprite.width))
    + Style.spacing.sm
  implicitHeight: barSize

  UI.ClawdSprite {
    id: barSprite
    visible: !root.showAgents
    height: root.barSize * root.petScale
    width: implicitWidth
    anchors.centerIn: parent
    move: root.shownMove
    frame: root.animate ? root.frame : 0
    smooth: root.smoothScaling
    tint: root.mainTint

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) root.playOnce("laptop", 2)
        else root.panelOpen = !root.panelOpen
      }
    }
  }

  // Agents at work (or waiting on you), like the notification bell's count.
  UI.CountBadge {
    // One agent is obvious from Clawd himself; the badge starts at two.
    visible: !root.showAgents && count >= 2 && style !== "None"
    anchors.right: barSprite.right
    anchors.rightMargin: -Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: Style.space(3)
    style: root.badge
    count: root.claude.activeCount
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  }

  UI.BarAgents {
    id: barAgents
    visible: root.showAgents
    anchors.centerIn: parent
    agents: root.claude.agents
    musicPlaying: music.playing
    tick: root.tick
    animate: root.animate
    smoothScaling: root.smoothScaling
    spriteHeight: root.barSize * root.petScale
    colourFor: root.colourFor
    bar: root.bar
    // Left: panel. Right: panel on this agent's colour. Middle: laptop.
    onClicked: function(agent, button) {
      if (button === Qt.MiddleButton) {
        root.playOnce("laptop", 2)
      } else if (button === Qt.RightButton && agent.cwd) {
        petPanel.editingCwd = agent.cwd
        root.panelOpen = true
      } else {
        root.panelOpen = !root.panelOpen
      }
    }
  }

  HoverHandler {
    enabled: !root.showAgents
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

    agents: root.claude.agents
    fallbackMove: root.shownMove
    fallbackText: root.moodLine
    previewMove: root.oneShot
    musicPlaying: music.playing
    musicLabel: music.label
    colourFor: root.colourFor
    positions: root.deskPositions
    pinned: root.pinned
    roam: root.roam
    petScale: root.deskScale
    smoothScaling: root.smoothScaling
    animate: root.animate
    speed: root.animationSpeed

    onPinRequested: function(isPinned, positions) {
      var merged = {}
      for (var k in root.deskPositions) merged[k] = root.deskPositions[k]
      for (var p in positions) merged[p] = positions[p]
      root.setSettings({ pinned: isPinned, deskPositions: merged })
    }
  }

  UI.PetPanel {
    id: petPanel
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.panelOpen
    pet: root
  }
}
