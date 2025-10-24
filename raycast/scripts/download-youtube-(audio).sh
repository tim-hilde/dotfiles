#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Youtube (Audio)
# @raycast.mode fullOutput
# @raycast.argument1 {"type": "text", "placeholder": "url", "optional": false}

# Optional parameters:
# @raycast.icon 📺

# Documentation:
# @raycast.author Tim

url="${1}"

yt-dlp -f bestaudio --extract-audio --audio-format mp3 "${url}"
