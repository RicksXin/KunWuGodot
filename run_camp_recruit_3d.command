#!/bin/zsh
set -eu
cd "$(dirname "$0")"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
 res://scenes/prototypes/camp_recruit_3d_demo.tscn \
 -- --no-profile-write --ignore-config-cache
