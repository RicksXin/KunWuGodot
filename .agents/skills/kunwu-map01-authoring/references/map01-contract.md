# Map01 authoring contract

## Paths

- Editable layout: `res://scenes/maps/map_01.tscn`
- Layout reader: `res://scripts/maps/map_scene_layout.gd`
- Marker component: `res://scripts/maps/map_marker.gd`
- Product configuration: `res://data/maps/map_01_demo.json`
- TileSet: `res://resources/tilemapdual_standard.tres`
- TileMapDual script: `res://addons/TileMapDual/tile_map_dual.gd`
- Validation: `res://tools/validate_map01_scene.gd`

## D0 coordinate contract

- Active area: `15×15`; the future formal map remains `48×64`.
- Logical display tile: `48×48` pixels.
- Source TileSet tile: `256×256` pixels.
- Map scene root scale: `0.1875`.
- Domain coordinates grow upward; scene cell coordinates grow downward.
- Convert with `screen_y = active_height - 1 - domain_y` and the inverse formula.

Initial domain markers:

| Marker | Kind | Domain cell | Scene cell |
|---|---|---:|---:|
| `Entry` | `entry` | `(2,2)` | `(2,12)` |
| `Enemy` | `enemy_group` | `(9,9)` | `(9,5)` |
| `Story` | `story_event` | `(7,8)` | `(7,6)` |
| `Chest` | `treasure_chest` | `(5,4)` | `(5,10)` |

## Layer responsibilities

- `Ground`: all walkable cells. Paint only source `0`, atlas `(2,1)`, alternative `0`.
- `DifficultTerrain`: the three current `~` cells and future high-cost walkable cells.
- `Markers`: editor-visible semantic nodes. Their IDs join to objects in JSON.
- Runtime overlay: fog, grid, entry/object/player markers, and interaction hit feedback.

Do not duplicate product text, rewards, or encounter payloads into the scene. Do not use
JSON `terrainRows` as the normal runtime layout when `visual.scenePath` is available;
retain it only as a compatibility fallback for remote configuration without a scene.
