#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Youtube (Video)
# @raycast.mode compact
# @raycast.argument1 {"type": "text", "placeholder": "url(s)", "optional": false}

# Optional parameters:
# @raycast.icon 📺

# Documentation:
# @raycast.author Tim

SESSION="dotfiles"
RAW_INPUT="${1}"

# URLs aus Input parsen (Zeilenumbrüche, leere Zeilen + Whitespace filtern)
URLS=()
while IFS= read -r line; do
  trimmed="$(echo "$line" | xargs)"
  [ -n "$trimmed" ] && URLS+=("$trimmed")
done <<< "$RAW_INPUT"

# Abbruch, wenn keine URLs
if [ ${#URLS[@]} -eq 0 ]; then
  echo "❌ Keine URLs übergeben"
  exit 1
fi

COUNT=${#URLS[@]}
WINDOW_NAME="yt-dl-${COUNT}-$(date +%s)"

# Session sicherstellen
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n "main"
fi

# URLs als newline-getrennter String für die Subshell
URL_LIST=$(printf '%s\n' "${URLS[@]}")

# Ein Window, sequenzielle Downloads, gemeinsame Erfolgs-/Fehlerlogik
tmux new-window -t "$SESSION" -n "$WINDOW_NAME" "bash -c '
FAILED=()
SUCCESS=0
TOTAL='"$COUNT"'
INDEX=0
while IFS= read -r url; do
  [ -z \"\$url\" ] && continue
  INDEX=\$((INDEX+1))
  echo \"\"
  echo \"▶️  [\$INDEX/\$TOTAL] \$url\"
  if yt-dlp -S res:1080 -f bestvideo+bestaudio --remux-video mp4 \"\$url\"; then
    SUCCESS=\$((SUCCESS+1))
  else
    FAILED+=(\"\$url\")
  fi
done <<< '"$(printf '%q' "$URL_LIST")"'

echo \"\"
echo \"✅ \$SUCCESS erfolgreich, ❌ \${#FAILED[@]} fehlgeschlagen\"
if [ \${#FAILED[@]} -gt 0 ]; then
  echo \"Fehlgeschlagene URLs:\"
  printf \"  - %s\n\" \"\${FAILED[@]}\"
  echo \"\"
  echo \"Press any key to close...\"
  read -n 1
else
  sleep 2
fi
tmux kill-window -t '"$SESSION:$WINDOW_NAME"'
'"
