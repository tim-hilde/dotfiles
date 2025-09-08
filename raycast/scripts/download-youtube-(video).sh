#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download Youtube (Video)
# @raycast.mode compact
# @raycast.argument1 {"type": "text", "placeholder": "url", "optional": false, "percentEncoded": true}

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.author Tim

curl -X POST http://raspberrypi.local:5001/download \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"$1\"}"

