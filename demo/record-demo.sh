#!/usr/bin/env bash
# Script to record the asciinema demo
# Run: bash demo/record-demo.sh

set -e

CAST_FILE="demo/demo.cast"

echo "Recording asciinema demo to $CAST_FILE"
echo "Instructions:"
echo "  1. Type: claude           (show ghost text autosuggestion, press Ctrl+C to cancel)"
echo "  2. Type: claude --resume  (press TAB to show session list)"
echo "  3. Press Ctrl+D to stop recording"
echo ""
echo "Starting in 2 seconds..."
sleep 2

asciinema rec "$CAST_FILE" \
  --title "zsh-claude-resume: Auto-resume Claude Code sessions" \
  --cols 100 \
  --rows 24
