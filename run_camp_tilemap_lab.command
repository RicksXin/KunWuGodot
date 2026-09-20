#!/bin/zsh
set -eu
cd "$(dirname "$0")"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
  --log-file /tmp/kunwu-camp-tilemap-lab.log \
  res://scenes/prototypes/camp_terrain_sample.tscn \
  -- --no-profile-write --ignore-config-cache
