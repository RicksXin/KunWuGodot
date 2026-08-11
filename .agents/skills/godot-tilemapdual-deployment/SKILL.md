---
name: godot-tilemapdual-deployment
description: Deploy the Godot Dual Grid Terrain Kit into a Godot 4.7.1 project: verify or install Godot, install Pillow, fetch or copy TileMapDual v5.0.2, enable the plugin, and fall back to an offline bundle or the user-provided Feishu download page when network installation fails. Use when a user needs to install, deploy, repair, or bootstrap the dual-grid terrain kit.
---

# Godot TileMapDual Deployment

## Preconditions

Need:

- Godot `4.7.1` preferred (Godot 4.7 compatible APIs only).
- Python 3 and Pillow.
- TileMapDual `v5.0.2`.

## 1. Verify Godot

```powershell
godot --version
```

If no compatible Godot is available, install Godot 4.7.1 from the official download page:

```text
https://godotengine.org/download/archive/4.7.1-stable/
```

If GitHub access is needed but blocked, check the Tsinghua University Open Source Mirror site for an available Godot or GitHub-related mirror entry:

```text
https://mirrors.tuna.tsinghua.edu.cn/
```

If no suitable Tsinghua mirror is available, do not keep retrying network sources. Tell the user to download the local package from:

```text
https://kcnz41bksl1c.feishu.cn/wiki/NZo0wb9Sci1TkekZSJBcFZunnjd
```

## 2. Install Python dependency

```powershell
python -m pip install Pillow
python -c "from PIL import Image; print('Pillow OK')"
```

## 3. Install TileMapDual

Preferred source:

```powershell
git clone https://github.com/pablogila/TileMapDual.git .\_downloads\TileMapDual
Copy-Item .\_downloads\TileMapDual\addons\TileMapDual .\addons\TileMapDual -Recurse -Force
```

If GitHub is inaccessible and the Tsinghua mirror does not provide this repository, tell the user to download the complete local package from the Feishu page in step 1. The local ZIP includes the offline TileMapDual plugin.

## 4. Enable and verify plugin

1. Open the project in Godot.
2. Go to `Project > Project Settings > Plugins`.
3. Enable `TileMapDual`.
4. Confirm `addons/TileMapDual/plugin.cfg` says `version="v5.0.2"`.

Ensure `project.godot` includes:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/TileMapDual/plugin.cfg")

[rendering]
textures/canvas_textures/default_texture_filter=0
```

Use nearest filtering and disable mipmaps for pixel art textures.

## 5. Install kit scripts

Copy these into the target Godot project:

```text
skills/dual-grid-windmill-creation/scripts/compile_dual_grid_windmill.py
skills/dual-grid-windmill-creation/scripts/build_tilemapdual_scene.gd
```

Put the windmill master at `art/windmill_master.png`. Change the path constants at the top of the GDScript if the project uses different asset folders.

## Failure boundary

- `No target node selected` / `No scene selected for painting`: those describe Godot scene-painting tooling, not TileMapDual installation. Select the `TileMapDual` node and paint with the TileMap `Tiles` tab.
- The normal Godot `Terrains` tab can appear empty; TileMapDual reads Terrain Set 0 internally.
- A white/cream rectangle around terrain is opaque art background, not an import setting problem. Rebuild from a transparent source or use `key-top-left` only after checking color safety.
