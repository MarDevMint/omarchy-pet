# Claude Pet (mar.claudepet)

Clawd lives in the Omarchy bar (and, if you like, on the desktop) and reacts
to Claude Code.

| Claude Code | Clawd |
|---|---|
| nothing going on | **Resting** (napping) |
| nothing going on, music playing (any MPRIS player) | **Music** (headphones) |
| prompt sent, Read, Grep, Glob, WebFetch, WebSearch | **Reading** (detective hat + magnifier) |
| Edit, Write, Bash, other tools | **Building** (hard hat + wrench) |
| permission prompt / question, or a failure | **Needs you** (laptop) + speech bubble |
| finished | back to Resting/Music, "Done!" bubble for 6 s |

Desktop Clawd walks along the bottom of the screen while Claude is idle and
stands still to work when Claude works. Left-click: laptop. Right-click:
pin/unpin. Drag: move. Hover: speech bubble. Clicks pass through everywhere
except Clawd (layer `mar-claudepet`).

Bar: click opens the panel, middle-click plays the laptop.

IPC: `omarchy-shell mar.claudepet play|toggle|walk|pin|status|reload`
(`play` takes rest, music, build, reading, laptop, walkRight, walkLeft).

## Layout

```
Main.qml                  settings, animation clock, bar icon, wiring
lib/Moves.js              moves, atlas layout, Claude state -> move
lib/Colors.js             agent colours (per project), palette, hue picker
lib/Util.js               small helpers
services/ClaudeState.qml  Claude Code state from the hook's state file
services/Music.qml        whether any media player is playing (MPRIS)
ui/ClawdSprite.qml        one cell of the atlas
ui/DesktopPet.qml         desktop strip, one Clawd per agent
ui/DeskClawd.qml          one walking Clawd (drag, bubble, pin)
ui/BarAgents.qml          one small Clawd per agent in the bar
ui/CountBadge.qml         notification-style badge
ui/PetPanel.qml           the panel (sized for 1366x768)
assets/shaders/           body recolour shader (tools/build-shaders)
bin/claudepet-hook        Claude Code hook, writes $XDG_RUNTIME_DIR/mar-claudepet
bin/install-hooks         add/remove the hook in ~/.claude/settings.json (backup first)
tools/build-atlas         packs ~/Pictures/Claude_pet GIFs into assets/clawd/spritesheet.png
tools/clean-gif.py        removes halo / colour noise from source GIFs
tools/build-shaders       compiles assets/shaders/*.frag with qsb
```

Adding a move: add the GIF to `tools/build-atlas` (a new row), run it, add the
row to `MOVES` in `lib/Moves.js` (keep `ROWS` in sync), map a state to it in
`STATES` if Claude should trigger it.

Privacy: the hook keeps only the tool name and a file basename, in RAM,
mode 700.

Credits: engine forked from OmaPets (yesmeck/OmaPets @ 2d4fa03, MIT, see
LICENSE.omapets). Walk GIFs recoloured #de886d -> #c97159. Personal hobby
project; Clawd is Anthropic's character.
