#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Transcribe Youtube
# @raycast.mode compact
# @raycast.argument1 {"type": "text", "placeholder": "url", "optional": false}

# Optional parameters:
# @raycast.icon 📝

# Documentation:
# @raycast.author Tim

SESSION="dotfiles"
RAW_URL="${1}"

# YouTube URL auf https://www.youtube.com/watch?v=ID normalisieren
vid="$(echo "$RAW_URL" | grep -oE '[?&]v=([^&]+)' | head -1 | cut -d= -f2)"
if [ -n "$vid" ]; then
  URL="https://www.youtube.com/watch?v=$vid"
else
  URL="$RAW_URL"
fi

WINDOW_NAME="yt-transcribe-$(date +%s)"

# Create session if it doesn't exist
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n "main"
fi

# Create new window: download audio to temp dir, transcribe, copy to clipboard, cleanup
tmux new-window -t "$SESSION" -n "$WINDOW_NAME" "bash -c '
set -o pipefail
TMP=\$(mktemp -d)
trap \"rm -rf \$TMP\" EXIT

if yt-dlp --audio-format mp3 --extract-audio -o \"\$TMP/%(title)s.%(ext)s\" \"$URL\" \
   && AUDIO=\$(ls \"\$TMP\"/*.mp3 2>/dev/null | head -1) \
   && [ -n \"\$AUDIO\" ] \
   && typewhisper transcribe \"\$AUDIO\" | pbcopy; then
  osascript -e \"display notification \\\"Transcript copied to clipboard\\\" with title \\\"YouTube Transcribe\\\"\"
  sleep 2
  tmux kill-window -t $SESSION:$WINDOW_NAME
else
  echo \"❌ Transcription failed\"
  osascript -e \"display notification \\\"Transcription failed\\\" with title \\\"YouTube Transcribe\\\"\"
  echo \"Press any key to close...\"
  read -n 1
  tmux kill-window -t $SESSION:$WINDOW_NAME
fi
'"
