import QtQuick
import Quickshell.Services.Mpris

// Whether any media player (MPRIS: Spotify, browsers, mpv...) is playing,
// and what. Event driven, no polling.
Item {
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    for (var i = 0; i < players.length; i++)
      if (players[i] && players[i].isPlaying) return players[i]
    return null
  }
  readonly property bool playing: player !== null
  readonly property string title: player ? String(player.trackTitle || "") : ""
  readonly property int maxTitle: 40
  // 'Listening to "Song"', or the generic line when the player has no title.
  readonly property string label: title === "" ? "Listening to music"
    : "Listening to \u201c" + (title.length > maxTitle
      ? title.slice(0, maxTitle - 1) + "\u2026" : title) + "\u201d"
}
