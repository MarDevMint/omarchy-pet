.pragma library

// Clawd's moves and how Claude Code states map onto them.
//
// The atlas (assets/clawd/spritesheet.png) is built by tools/build-atlas:
// one row per move, 8 columns of 192x208 cells. ROW numbers here must match
// the row order in that script.

var CELL_WIDTH = 192
var CELL_HEIGHT = 208
var COLUMNS = 8
var ROWS = 7

// ms is the time per frame at animation speed 1.0.
var MOVES = {
  rest:      { key: "rest",      label: "Resting",   row: 0, frames: 8, ms: 900 },
  music:     { key: "music",     label: "Music",     row: 1, frames: 6, ms: 700 },
  build:     { key: "build",     label: "Building",  row: 2, frames: 4, ms: 850 },
  laptop:    { key: "laptop",    label: "Needs you", row: 3, frames: 6, ms: 700 },
  reading:   { key: "reading",   label: "Reading",   row: 4, frames: 6, ms: 700 },
  walkRight: { key: "walkRight", label: "Walking",   row: 5, frames: 8, ms: 280 },
  walkLeft:  { key: "walkLeft",  label: "Walking",   row: 6, frames: 8, ms: 280 }
}

// Buttons in the panel, in order. "walking" previews a walk to the right.
var PANEL_MOVES = ["rest", "music", "build", "reading", "laptop", "walkRight"]

// Claude Code state (written by bin/claudepet-hook) -> what Clawd does.
// move "idle" means: music if something is playing, otherwise rest.
// holdMs: short-lived states fall back to idle after this long.
var STATES = {
  idle:     { move: "idle",    label: "Idle" },
  thinking: { move: "reading", label: "Thinking…" },
  reading:  { move: "reading", label: "Reading" },
  building: { move: "build",   label: "Building" },
  working:  { move: "build",   label: "Working" },
  waiting:  { move: "laptop",  label: "Needs you" },
  done:     { move: "idle",    label: "Done!", holdMs: 6000 },
  error:    { move: "laptop",  label: "Something failed", holdMs: 10000 }
}

function move(key) {
  return MOVES[key] || MOVES.rest
}

function state(name) {
  return STATES[name] ? name : "idle"
}

function stateLabel(name) {
  return (STATES[name] || STATES.idle).label
}

function moveForState(name, musicPlaying) {
  var key = (STATES[name] || STATES.idle).move
  if (key === "idle") key = musicPlaying ? "music" : "rest"
  return move(key)
}

// Claude is not busy: Clawd may wander, and music decides the idle pose.
function isIdle(name) {
  return name === "idle" || name === "done"
}

function frameInterval(m, speed) {
  return Math.max(60, Math.round(m.ms / Math.max(0.25, speed || 1)))
}
