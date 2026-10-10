import QtQuick
import Quickshell.Services.Mpris

// Whether any media player (MPRIS: Spotify, browsers, mpv...) is playing.
// Event driven, no polling.
Item {
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property bool playing: {
    for (var i = 0; i < players.length; i++)
      if (players[i] && players[i].isPlaying) return true
    return false
  }
}
