---
name: kunwu-map01-authoring
description: Safely create, edit, inspect, or validate KunWuGodot Map01 terrain and markers with Godot 4.7.1, TileMapLayer, TileMapDual v5.0.2, and godot-tilemap-mcp. Use for requests to draw Map01, change walkable or difficult cells, move the entry/enemy/story/chest markers, diagnose Map01 TileMap rendering, or expand the current D0 map scene.
---

# KunWu Map01 Authoring

## Preserve the map contract

Read `../../../AGENTS.md`, `../../../README.md`, `../../../MIGRATION.md`, and
[`references/map01-contract.md`](references/map01-contract.md) before editing. Treat
`scenes/maps/map_01.tscn` as the layout and coordinate fact source. Keep object copy,
rewards, encounters, and other product semantics in `data/maps/map_01_demo.json`.

Before preparing prompts, generating or inspecting candidate art, cleaning images,
choosing between ChatGPT and Meowa, or promoting any Map01 image, also read
`../../../Docs/ArtAssets/18_地图生成式美术生产与模型分工规范.md`. ChatGPT is the
default generation provider. Meowa is an explicitly approved, per-job escalation only;
never infer credit-spend approval from ordinary continuation language.

Use Godot 4.7.1-compatible APIs and `res://` paths. Never depend on the frozen parent
Cocos project. Preserve unrelated edits and never write a real player profile during
validation; pass `-- --no-profile-write`.

## Edit terrain safely

1. Inspect the scene and TileSet before changing cells.
2. Edit `Map01/Ground` only with the complete terrain tile `0xF`: source `0`, atlas
   `(2,1)`, alternative `0`. This TileMapLayer has the TileMapDual script attached.
3. Do not call Godot-native `terrain_connect` or `terrain_path` on `Ground`. TileMapDual
   derives its half-cell display from complete world-grid cells.
4. Use `Map01/DifficultTerrain` only to mark walkable cells with higher movement cost.
   Keep every difficult cell inside `Ground`.
5. Use godot-tilemap-mcp transactions in the fixed order: inspect, preview, review the
   cell diff and preview, then apply the exact returned transaction. Never enable
   legacy direct writes. Re-inspect and make a new preview if the revision is stale.
6. Keep marker coordinates in domain space: X grows right and Y grows up. Let the marker
   script convert them to the scene's downward screen Y.

The MCP image preview reads static TileMapLayer cells. It does not prove that the
TileMapDual-generated half-cell display is correct. Validate plugin behavior in Godot
after every shape change, especially diagonal contacts, concave corners, single-cell
islands, and holes.

## Validate and report

Run the project Map01 validator, a headless editor import, and a short headless project
run. Confirm that Ground is non-empty, all markers are walkable, difficult terrain is a
Ground subset, scene-derived movement agrees with `Game.tile_at()`, and TileMapDual
creates its runtime display.

Report any missing formal art instead of inventing it. Current ground art is a technical
Dual Grid brush; walls, roads, water/difficult terrain, decorations, props, and formal
entry/enemy/story/chest icons require user-provided or separately approved art.

Generated images are candidate masters, not layout facts or runtime-ready assets. Keep
them under `art/source_archive/` or `art/candidates/` until Alpha, size, anchor, palette,
state separation, normal-scale composition, and user visual approval pass. Build the
final map from TileMap layers, reusable components, and runtime overlays; never flatten
a generated full-map image over the formal scene.
