#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Youtube (Audio)
# @raycast.mode compact
# @raycast.argument1 {"type": "text", "placeholder": "url", "optional": false}

# Optional parameters:
# @raycast.icon 📺

# Documentation:
# @raycast.author Tim

url="${1}"

if yt-dlp -f bestaudio --extract-audio --audio-format mp3 "${url}"; then
    echo "✅ Audio download completed"
else
    echo "❌ Audio download failed"
fi
