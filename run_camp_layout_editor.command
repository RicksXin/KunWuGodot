#!/bin/zsh
set -eu
cd "$(dirname "$0")"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
  res://scenes/prototypes/camp_layout_editor.tscn \
  -- --no-profile-write --ignore-config-cache
