---
name: spotify
description: Control Spotify on macOS. Use for playing music, controlling playback, and getting track information.
allowed-tools: Bash, Read, WebSearch
---

# Spotify Mac Skill

This skill provides commands to control Spotify on macOS via AppleScript.

## Available Scripts

All scripts are in the `./scripts/` directory (relative to this file). Execute them via bash from the plugin root.

### Playback Control

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `play.sh` | Resume playback | none |
| `pause.sh` | Pause playback | none |
| `toggle-playback.sh` | Toggle play/pause | none |
| `next-track.sh` | Skip to next track | none |
| `previous-track.sh` | Go to previous track | none |
| `play-uri.sh` | Play specific URI | `<spotify_uri> [context_uri]` |

### Search

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `search.sh` | Open Spotify search visually | `<query>` |

**Agent-Assisted Search (Recommended):**
To search and play automatically, use web search to find Spotify URLs:
1. Search: `site:open.spotify.com [query]` (e.g., "site:open.spotify.com bohemian rhapsody")
2. Get the URL from results (e.g., `https://open.spotify.com/track/6l8GvAyoUZwWDgF1e4822w`)
3. Play it: `play-uri.sh "https://open.spotify.com/track/..."`

This works for tracks, albums, playlists, and artists.

### Track Information

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `get-current-track.sh` | Get current track info | none |
| `get-player-state.sh` | Get player state | none |

### Volume Control

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `get-volume.sh` | Get current volume | none |
| `set-volume.sh` | Set volume level | `<volume 0-100>` |
| `volume-up.sh` | Increase volume by 10 | none |
| `volume-down.sh` | Decrease volume by 10 | none |

### Position Control

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `get-position.sh` | Get current position | none |
| `set-position.sh` | Seek to position | `<seconds>` |
| `fast-forward.sh` | Forward 10 seconds | none |
| `rewind.sh` | Rewind 10 seconds | none |

### Mode Control

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `toggle-shuffle.sh` | Toggle shuffle mode | none |
| `toggle-repeat.sh` | Toggle repeat mode | none |
| `get-modes.sh` | Get shuffle/repeat status | none |

### Utility

| Script | Purpose | Arguments |
|--------|---------|-----------|
| `is-running.sh` | Check if Spotify is running | none |
| `launch.sh` | Launch Spotify app | none |
| `quit.sh` | Quit Spotify | none |

## Output Format

Scripts use delimiters for structured output:
- `<<>>` separates fields within a record
- `ERROR:` prefix indicates an error message

### Track Record Format

```
name<<>>artist<<>>album<<>>albumArtist<<>>duration<<>>position<<>>trackNumber<<>>discNumber<<>>id<<>>spotifyUrl<<>>artworkUrl<<>>popularity
```

### Player State Format

```
state<<>>position<<>>volume<<>>shuffling<<>>repeating
```

### Modes Format

```
shuffling<<>>repeating
```

## Usage Examples

### Basic Playback
```bash
# Play/pause
./scripts/play.sh
./scripts/pause.sh
./scripts/toggle-playback.sh

# Navigation
./scripts/next-track.sh
./scripts/previous-track.sh
```

### Search and Play (Agent-Assisted)
```bash
# Agent searches web for: site:open.spotify.com bohemian rhapsody
# Gets URL from results, then plays:
./scripts/play-uri.sh "https://open.spotify.com/track/6l8GvAyoUZwWDgF1e4822w"

# Works for any content type:
./scripts/play-uri.sh "https://open.spotify.com/playlist/37i9dQZF1DXaXB8fQg7xif"
./scripts/play-uri.sh "https://open.spotify.com/album/3BHe7LbW5yRjyqXNJ3A6mW"
```

### Visual Search (Opens Spotify App)
```bash
./scripts/search.sh "bohemian rhapsody"
./scripts/search.sh "artist:queen"
./scripts/search.sh "playlist:hot country"
```

### Play Specific Content
```bash
# Play a track
./scripts/play-uri.sh "spotify:track:4uLU6hMCjMI75M1A2tKUQC"

# Play an album
./scripts/play-uri.sh "spotify:album:7ppypgQppMf3mkRbZxYIFM"

# Play a playlist
./scripts/play-uri.sh "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"

# Play track in album context (enables album queue)
./scripts/play-uri.sh "spotify:track:xxx" "spotify:album:yyy"
```

### Get Track Information
```bash
# Get current track details
./scripts/get-current-track.sh
# Output: Song Name<<>>Artist<<>>Album<<>>Album Artist<<>>180<<>>45<<>>1<<>>1<<>>spotify:track:xxx<<>>https://open.spotify.com/track/xxx<<>>https://i.scdn.co/image/xxx<<>>75

# Get player state
./scripts/get-player-state.sh
# Output: playing<<>>45.5<<>>75<<>>false<<>>true
```

### Volume Control
```bash
# Get current volume
./scripts/get-volume.sh

# Set specific volume
./scripts/set-volume.sh 50

# Adjust volume
./scripts/volume-up.sh
./scripts/volume-down.sh
```

### Seeking
```bash
# Get current position
./scripts/get-position.sh

# Jump to 30 seconds
./scripts/set-position.sh 30

# Skip forward/backward 10 seconds
./scripts/fast-forward.sh
./scripts/rewind.sh
```

### Shuffle and Repeat
```bash
# Toggle modes
./scripts/toggle-shuffle.sh
./scripts/toggle-repeat.sh

# Check current modes
./scripts/get-modes.sh
# Output: true<<>>false
```

### App Control
```bash
# Check if running
./scripts/is-running.sh

# Launch/quit
./scripts/launch.sh
./scripts/quit.sh
```

## Parsing Output

When receiving track info, parse like this:

1. Split by `<<>>` to get fields
2. Fields are: name, artist, album, albumArtist, duration, position, trackNumber, discNumber, id, spotifyUrl, artworkUrl, popularity

Example parsing in bash:
```bash
IFS='<<>>' read -ra fields <<< "$output"
name="${fields[0]}"
artist="${fields[1]}"
album="${fields[2]}"
# ... etc
```

## Spotify URI Format

Spotify uses URIs to identify content:
- **Tracks**: `spotify:track:<track_id>`
- **Albums**: `spotify:album:<album_id>`
- **Playlists**: `spotify:playlist:<playlist_id>`
- **Artists**: `spotify:artist:<artist_id>`

You can get URIs from:
- Spotify desktop: Right-click > Share > Copy Spotify URI
- Spotify web: Copy from URL (e.g., `https://open.spotify.com/track/xxx` -> `spotify:track:xxx`)

## Notes

- Scripts require macOS with Spotify Desktop app installed
- Works with free or premium Spotify accounts
- No authentication or API keys required
- First run may trigger macOS permission prompts for automation
- Duration is returned in seconds (converted from milliseconds)
- Position is in seconds

## Limitations

AppleScript API does **NOT** support:
- Adding to playlists
- Viewing or managing queue
- Liking/saving tracks
- Browsing library
- Searching private/personal playlists (use play-uri.sh with the playlist URI instead)

For these features, use the Spotify Web API (requires Premium + OAuth).

## Reference

For advanced AppleScript patterns and customization, see `./reference/applescript-patterns.md`.
