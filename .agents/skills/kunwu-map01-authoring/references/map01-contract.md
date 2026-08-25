# Map01 formal authoring contract

## Paths

- Editable layout: `res://scenes/maps/map_01.tscn`
- Visual background: `res://assets/maps/map_01/map01_background.png`
- Runtime adapter: `res://scripts/maps/map01_runtime.gd`
- Map and coordinate fact source: `res://data/maps/map_01_formal.json`
- Combat payload: `res://data/config/combat_map01_formal.json`
- Manifest: `res://data/maps/map_01_manifest.json`
- Validation: `res://tools/validate_map01_formal.gd`

## Coordinate contract

- Active area: `28×64`.
- Logical display tile: `48×48` pixels.
- Background: `1344×3072` pixels.
- Domain coordinates grow upward; scene cell coordinates grow downward.
- Convert with `screen_y = active_height - 1 - domain_y` and the inverse formula.
- Entry: `(13,6)`.
- Base walkable cells: `834`; blocked cells: `958`.
- Formal objects: `31`; direct battle markers: `13`; encounter definitions: `14`;
  dynamic blockers: `7`.

## Layer responsibilities

- `HDBackground`: approved full-map visual only; linear texture filtering.
- `terrainRows`: all base walkability and movement-cost facts.
- `dynamicBlockers`: state-dependent passability.
- `objects`: object IDs, domain coordinates, interactions, rewards, and state effects.
- Runtime overlay: fog, grid, entry/object/player markers, and interaction hit feedback.

Do not duplicate product text, rewards, collision, or coordinates into the scene. There is no
Map01 TileMap, TileSet, component preview, candidate scene, or compatibility map version.
