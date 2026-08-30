# AppleScript Patterns for Spotify

This document contains AppleScript patterns for Spotify automation. Use these patterns when the provided scripts don't cover your specific use case.

## Execution

All AppleScript code should be executed via `osascript`:

```bash
osascript <<'EOF'
tell application "Spotify"
    -- AppleScript code here
end tell
EOF
```

Or with variable interpolation (use `<<EOF` without quotes):

```bash
osascript <<EOF
tell application "Spotify"
    play track "$SPOTIFY_URI"
end tell
EOF
```

## Output Delimiters

For structured output that's easy to parse:
- `<<>>` separates fields within a record
- `ERROR:` prefix indicates errors

## Core Patterns

### Playback Control

```applescript
tell application "Spotify"
    -- Basic controls
    play
    pause
    playpause  -- toggle

    -- Navigation
    next track
    previous track
end tell
```

### Search

```applescript
-- Open search in Spotify using URI scheme
open location "spotify:search:bohemian%20rhapsody"

-- Search with filters
open location "spotify:search:artist:queen"
open location "spotify:search:album:a%20night%20at%20the%20opera"
open location "spotify:search:genre:jazz"
```

### Play Specific Content

```applescript
tell application "Spotify"
    -- Play a track
    play track "spotify:track:4uLU6hMCjMI75M1A2tKUQC"

    -- Play an album
    play track "spotify:album:7ppypgQppMf3mkRbZxYIFM"

    -- Play a playlist
    play track "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"

    -- Play track in context (e.g., within an album)
    play track "spotify:track:xxx" in context "spotify:album:yyy"
end tell
```

### Current Track Properties

```applescript
tell application "Spotify"
    if player state is not stopped then
        -- Basic info
        set trackName to name of current track
        set trackArtist to artist of current track
        set trackAlbum to album of current track
        set trackAlbumArtist to album artist of current track

        -- Identifiers
        set trackId to id of current track  -- Spotify URI
        set trackUrl to spotify url of current track  -- Web URL
        set artworkUrl to artwork url of current track

        -- Metadata
        set trackDuration to (duration of current track) / 1000  -- milliseconds to seconds
        set trackNumber to track number of current track
        set discNumber to disc number of current track
        set trackPopularity to popularity of current track  -- 0-100
    end if
end tell
```

### Player State

```applescript
tell application "Spotify"
    -- Check state: stopped, playing, or paused
    set currentState to player state

    if player state is playing then
        -- do something
    else if player state is paused then
        -- do something else
    else if player state is stopped then
        -- nothing playing
    end if
end tell
```

### Position Control

```applescript
tell application "Spotify"
    -- Get current position (in seconds)
    set currentPos to player position

    -- Seek to specific position
    set player position to 30  -- jump to 30 seconds

    -- Seek relative
    set player position to (player position + 10)  -- forward 10s
    set player position to (player position - 10)  -- back 10s
end tell
```

### Volume Control

```applescript
tell application "Spotify"
    -- Get volume (0-100)
    set vol to sound volume

    -- Set volume
    set sound volume to 50

    -- Adjust relative
    set sound volume to (sound volume + 10)  -- up 10
    set sound volume to (sound volume - 10)  -- down 10
end tell
```

### Shuffle and Repeat

```applescript
tell application "Spotify"
    -- Check states
    set isShuffling to shuffling
    set isRepeating to repeating

    -- Toggle
    set shuffling to not shuffling
    set repeating to not repeating

    -- Set explicitly
    set shuffling to true
    set repeating to false
end tell
```

### Check if Running

```applescript
tell application "System Events"
    if (name of processes) contains "Spotify" then
        -- Spotify is running
    else
        -- Spotify is not running
    end if
end tell
```

### Launch and Quit

```applescript
-- Launch (brings to front)
tell application "Spotify" to activate

-- Quit
tell application "Spotify" to quit
```

## Error Handling

```applescript
tell application "Spotify"
    try
        -- Your code here
        next track
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
```

## Building Output Strings

```applescript
tell application "Spotify"
    set trackName to name of current track
    set trackArtist to artist of current track
    set trackAlbum to album of current track

    -- Concatenate with delimiter
    return trackName & "<<>>" & trackArtist & "<<>>" & trackAlbum
end tell
```

## Property Reference

### Track Properties (Read-Only)

| Property | Type | Description |
|----------|------|-------------|
| `name` | string | Track title |
| `artist` | string | Artist name |
| `album` | string | Album name |
| `album artist` | string | Album artist |
| `id` | string | Spotify URI |
| `spotify url` | string | Spotify web URL |
| `artwork url` | string | Album artwork URL |
| `duration` | integer | Length in milliseconds |
| `track number` | integer | Track position on album |
| `disc number` | integer | Disc number |
| `popularity` | integer | Popularity score (0-100) |
| `played count` | integer | Times played |

### Player Properties

| Property | Type | Read/Write | Description |
|----------|------|------------|-------------|
| `player state` | enum | Read | stopped, playing, paused |
| `player position` | real | Read/Write | Position in seconds |
| `sound volume` | integer | Read/Write | Volume (0-100) |
| `shuffling` | boolean | Read/Write | Shuffle mode |
| `repeating` | boolean | Read/Write | Repeat mode |
| `shuffling enabled` | boolean | Read | Shuffle available |
| `repeating enabled` | boolean | Read | Repeat available |
| `current track` | track | Read | Current track object |

### Commands

| Command | Description |
|---------|-------------|
| `play` | Resume playback |
| `pause` | Pause playback |
| `playpause` | Toggle play/pause |
| `next track` | Skip to next |
| `previous track` | Go to previous |
| `play track` | Play specific URI |

## Common Issues

### Spotify Not Running

Always check if Spotify is running before sending commands:

```applescript
tell application "System Events"
    if (name of processes) does not contain "Spotify" then
        return "ERROR:Spotify is not running"
    end if
end tell
```

### No Track Playing

Check player state before accessing current track:

```applescript
tell application "Spotify"
    if player state is stopped then
        return "ERROR:No track playing"
    end if
    -- Now safe to access current track
end tell
```

### Permission Errors

First run will prompt for Automation permissions in:
**System Settings > Privacy & Security > Automation**

Allow your terminal app to control Spotify.

### Dictionary Location

Spotify's AppleScript dictionary is at:
`/Applications/Spotify.app/Contents/Resources/Spotify.sdef`

View it in Script Editor: File > Open Dictionary > Spotify

## Integration Tips

1. **Always use error handling** - AppleScript can fail for many reasons
2. **Use heredocs for complex scripts** - Easier to read and maintain
3. **Escape user input** - Especially quotes and backslashes
4. **Check player state** - Before accessing current track properties
5. **Convert duration** - Spotify returns milliseconds, divide by 1000 for seconds
