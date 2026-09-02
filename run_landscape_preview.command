#!/bin/zsh

# Launch the isolated landscape project. The working directory must stay
# outside KunWuGodot so Godot does not auto-discover the vertical project.godot.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd /private/tmp
exec /Applications/Godot.app/Contents/MacOS/Godot \
  --path "$PROJECT_DIR/landscape_preview_project" \
  --rendering-method gl_compatibility \
  --rendering-driver opengl3 \
  -- \
  --no-profile-write \
  --ignore-config-cache
