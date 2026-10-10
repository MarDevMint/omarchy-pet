.pragma library

// Agent colours. Each project (Claude Code working directory) gets one,
// remembered in the widget setting `agentColors` ({cwd: "#rrggbb"}).
// New projects take the first palette colour no live agent is using; the
// eighth one wraps around.

var CLASSIC = "#c97159"

var PALETTE = [
  { name: "Clawd",  hex: "#c97159" },
  { name: "Red",    hex: "#d94848" },
  { name: "Yellow", hex: "#e3b341" },
  { name: "Green",  hex: "#4fae5c" },
  { name: "Blue",   hex: "#4a8fd9" },
  { name: "Indigo", hex: "#5b5bd6" },
  { name: "Violet", hex: "#a65bc9" }
]

var MAX_REMEMBERED = 50

function normalized(hex) {
  var value = String(hex || "").toLowerCase()
  return /^#[0-9a-f]{6}$/.test(value) ? value : ""
}

function colourFor(map, cwd) {
  return normalized(map && cwd ? map[cwd] : "") || CLASSIC
}

// Returns a new map with colours for any agent whose project has none yet,
// or null when nothing changed.
function assign(map, agents) {
  var next = {}
  var key
  for (key in map || {}) next[key] = map[key]
  var used = {}
  var changed = false
  for (var i = 0; i < agents.length; i++)
    if (agents[i].cwd && next[agents[i].cwd]) used[next[agents[i].cwd]] = true
  for (var j = 0; j < agents.length; j++) {
    var cwd = agents[j].cwd
    if (!cwd || next[cwd]) continue
    var pick = ""
    for (var p = 0; p < PALETTE.length && pick === ""; p++)
      if (!used[PALETTE[p].hex]) pick = PALETTE[p].hex
    if (pick === "") pick = PALETTE[Object.keys(used).length % PALETTE.length].hex
    next[cwd] = pick
    used[pick] = true
    changed = true
  }
  if (!changed) return null
  var keys = Object.keys(next)
  while (keys.length > MAX_REMEMBERED) delete next[keys.shift()]
  return next
}

// A colour from a hue (0-360) with Clawd's own saturation and lightness, so
// custom picks still look like him.
function fromHue(hue) {
  var h = ((Number(hue) % 360) + 360) % 360 / 360
  var s = 0.52, l = 0.57
  function channel(t) {
    t = (t + 1) % 1
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
    var p = 2 * l - q
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  function hex(v) {
    var n = Math.round(v * 255).toString(16)
    return n.length < 2 ? "0" + n : n
  }
  return "#" + hex(channel(h + 1 / 3)) + hex(channel(h)) + hex(channel(h - 1 / 3))
}
