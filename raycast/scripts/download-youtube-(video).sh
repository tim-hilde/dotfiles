#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Youtube (Video)
# @raycast.mode compact
# @raycast.argument1 {"type": "text", "placeholder": "url", "optional": false}

# Optional parameters:
# @raycast.icon 📺

# Documentation:
# @raycast.author Tim

url="${1}"

if yt-dlp -q -S "res:1080" -f "bestvideo+bestaudio" --remux-video "mp4" "${url}"; then
    echo "✅ Video download completed"
else
    echo "❌ Video download failed"
fi
