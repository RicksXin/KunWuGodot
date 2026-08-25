---
name: kunwu-map01-authoring
description: Safely edit, inspect, or validate the sole formal KunWuGodot Map01: a 28x64 approved HD background scene with JSON-authored walkability, blockers, objects, interactions, and runtime markers. Use for Map01 terrain, object, marker, rendering, or validation work.
---

# KunWu Map01 Authoring

## Preserve the formal map contract

Read `../../../AGENTS.md`, `../../../README.md`, `../../../MIGRATION.md`, and
[`references/map01-contract.md`](references/map01-contract.md) before editing. There is one
formal Map01 only. Treat `data/maps/map_01_formal.json` as the sole movement, blocker,
object-coordinate, interaction, and map-copy fact source. Treat
`scenes/maps/map_01.tscn` and `assets/maps/map_01/map01_background.png` as visual-only.

Before preparing prompts, generating or inspecting candidate art, cleaning images,
choosing between ChatGPT and Meowa, or promoting any Map01 image, also read
`../../../Docs/ArtAssets/18_地图生成式美术生产与模型分工规范.md`. ChatGPT is the
default generation provider. Meowa is an explicitly approved, per-job escalation only;
never infer credit-spend approval from ordinary continuation language.

Use Godot 4.7.1-compatible APIs and `res://` paths. Never depend on the frozen parent
Cocos project. Preserve unrelated edits and never write a real player profile during
validation; pass `-- --no-profile-write`.

## Edit terrain and objects safely

1. Inspect `terrainRows`, `dynamicBlockers`, `objects`, the scene, and the background before editing.
2. Keep the fixed boundary at `28×64` and logical tile size at `48×48` pixels unless the user
   explicitly approves a new formal-map migration.
3. Edit base walkability only in `terrainRows`: `#` blocked, `.` normal walkable, `~` difficult,
   `E` entry. JSON rows grow downward; domain coordinates grow upward, so
   `row_index = activeHeight - 1 - domain_y`.
4. Keep state-dependent collision in `dynamicBlockers`; do not bake it into the background.
5. Keep object coordinates in `objects`. Every object and additional marker cell must stay inside
   the boundary and on base walkable terrain unless its product rule explicitly requires otherwise.
6. Do not add TileMapLayer, TileMapDual, legacy tilesets, Map01 components, candidate scenes, Demo,
   Preview, scheme-numbered files, or a second Map01 data source.

The background is an approved visual layer, not a collision authoring surface. If background
composition and JSON walkability diverge, report the mismatch and update them as one explicitly
reviewed formal change; never infer collision by sampling pixels.

## Validate and report

Run `tools/validate_map01_formal.gd`, the formal combat validator, project-data validation,
a headless editor import, and a short headless project run. Always pass
`-- --no-profile-write --ignore-config-cache`. Confirm the background is `1344×3072`,
the map is `28×64`, counts remain correct, all object/marker coordinates are legal,
dynamic blockers work, and `Game.tile_at()` reads JSON `terrainRows` directly.

Report any missing formal art instead of inventing it. Current ground art is a technical
Dual Grid brush; walls, roads, water/difficult terrain, decorations, props, and formal
entry/enemy/story/chest icons require user-provided or separately approved art.

Generated images remain candidates until user approval. A replacement must first live outside
the formal runtime path, pass technical and visual review, and then replace the single formal
background through an explicit migration. Never keep candidate, Preview, Demo, scheme-numbered,
or superseded Map01 files inside the project after promotion.
