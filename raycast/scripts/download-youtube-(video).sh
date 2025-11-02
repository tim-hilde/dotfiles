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

# url="${1}"
#
# if yt-dlp -q -S "res:1080" -f "bestvideo+bestaudio" --remux-video "mp4" "${url}"; then
#     echo "✅ Video download completed"
# else
#     echo "❌ Video download failed"
# fi

SESSION="dotfiles"
URL="{$1}"

# Create session if it doesn't exist
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n "main"
fi

# Create new window and run yt-dlp command with success/failure handling
tmux new-window -t "$SESSION" -n "$URL" "bash -c '
if yt-dlp -q -S \"res:1080\" -f \"bestvideo+bestaudio\" --remux-video \"mp4\" \"$URL\"; then
  echo \"✅ Video download completed\"
  sleep 2
  tmux kill-window -t $SESSION:$URL
else
  echo \"❌ Video download failed\"
  echo \"Press any key to close...\"
  read -n 1
  tmux kill-window -t $SESSION:$URL
fi
'"

