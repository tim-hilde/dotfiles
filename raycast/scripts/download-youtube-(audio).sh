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

SESSION="dotfiles"
URL="${1}"

# Create session if it doesn't exist
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n "main"
fi

# Create new window and run yt-dlp command with success/failure handling
tmux new-window -t "$SESSION" -n "${URL}" "bash -c '
if yt-dlp --audio-format mp3 --extract-audio \"${URL}\"; then
  sleep 2
  tmux kill-window -t $SESSION:${URL}
else
  echo \"❌ Audio download failed\"
  echo \"Press any key to close...\"
  read -n 1
  tmux kill-window -t $SESSION:${URL}
fi
'"

