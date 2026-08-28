#!/bin/bash
# Get current track information
# Usage: ./get-current-track.sh
# Output: name<<>>artist<<>>album<<>>albumArtist<<>>duration<<>>position<<>>trackNumber<<>>discNumber<<>>id<<>>spotifyUrl<<>>artworkUrl<<>>popularity

osascript <<'EOF'
tell application "Spotify"
    try
        if player state is stopped then
            return "ERROR:No track playing"
        end if

        set trackName to name of current track
        set trackArtist to artist of current track
        set trackAlbum to album of current track
        set trackAlbumArtist to album artist of current track
        set trackDuration to (duration of current track) / 1000
        set trackPosition to player position
        set trackNum to track number of current track
        set discNum to disc number of current track
        set trackId to id of current track
        set trackUrl to spotify url of current track
        set artUrl to artwork url of current track
        set trackPopularity to popularity of current track

        return trackName & "<<>>" & trackArtist & "<<>>" & trackAlbum & "<<>>" & trackAlbumArtist & "<<>>" & trackDuration & "<<>>" & trackPosition & "<<>>" & trackNum & "<<>>" & discNum & "<<>>" & trackId & "<<>>" & trackUrl & "<<>>" & artUrl & "<<>>" & trackPopularity
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
