---
name: dual-grid-windmill-creation
description: Help a user create a Godot 4 Dual Grid terrain brush from a fixed windmill reference: discover game style and gameplay context, return a TaoNier image-generation prompt for 1K 1:1 Nano Banana, inspect the returned windmill master, compile it into 15 masks, and build a TileMapDual-ready Godot terrain brush. Use when a user asks for Dual Grid, TileMapDual, 15-piece terrain, windmill tiles, AI terrain generation, or a Godot autotile brush.
---

# Dual Grid Windmill Creation

## Outcome

Turn one AI-generated continuous windmill master into a Godot 4 Dual Grid brush. Do not ask the user to make 15 independent tiles.

## First response: discover the art direction

Ask only for missing information:

1. What game is this and what does the terrain mean in gameplay? Examples: walkable grass, lava hazard, water boundary, dungeon floor.
2. What visual style is wanted? Examples: pixel art, hand-painted cartoon, dark fantasy, low-poly rendered, cozy farm.
3. Is there a reference image, existing palette, or screenshot that must match?
4. Does the terrain sit over a separate map background? Default to yes and request transparent output.

If the user already gave a clear description or reference image, infer the answers and give the prompt without repeating questions.

## Fixed geometry contract

Use `../../assets/windmill-reference-guide.png` as the topology check.

- Canvas is exactly `1024x1024`, square `1:1`.
- Logical grid is `4x4`; each logical cell is `256x256`.
- The terrain is one continuous orthogonal stepped windmill/pinwheel.
- It is not a diagonal X, a collage, 15 independent tiles, or a completed game map.
- Purple guide lines are only for human checking. Never put guides, labels, text, UI, or a checkerboard into the generated source image.
- Returned file must be the full original PNG, not a screenshot, crop, thumbnail, or compressed chat preview.

See [references/windmill-spec.md](references/windmill-spec.md) for masks and acceptance.

## TaoNier generation handoff

Tell the user to use the TaoNier art tool with all three fixed parameters:

```text
Resolution: 1K
Aspect ratio: 1:1
Model: Nano Banana
```

Provide both a clean windmill reference image and the following prompt shape. Keep the contract paragraphs; replace only bracketed fields.

```text
DUAL GRID WINDMILL MASTER SOURCE
Generate one square 1024 by 1024 top-down 2D terrain master for "[terrain]".
Match the supplied clean reference silhouette exactly: one continuous orthogonal four-arm stepped windmill centered in a strict 4 by 4 logical crop grid. It is made from full and empty square regions with half-cell dual-grid alignment.
It is not a diagonal X, not 15 or 16 separate tiles, not a collage, and not a completed game map.

Game context: [gameplay and mood].
Visual style: [style, rendering language, palette, reference-image traits].
Lighting: [direction and mood].
Use one consistent terrain material, edge line, texture scale, lighting, and visual language across the complete silhouette. Texture must continue naturally across every internal join.

[For a separate game background: Output the non-terrain area as truly transparent alpha. Do not use white, cream, black, checkerboard, or fake transparency.]
[For a baked backing layer: Fill the non-terrain area with one clean, flat "[base]" layer; no gradients or scenery.]

Do not render crop lines, guide lines, labels, text, UI, checkerboard, magenta key color, isolated props, detached islands, characters, shadows outside terrain, camera perspective, margins, cropping, resizing, or a tile-sheet collage.
Return the original full-canvas RGBA PNG.
```

## Inspect the returned image

Before compiling, verify:

- exact `1024x1024` pixels and RGBA PNG;
- silhouette matches the fixed stepped windmill, not an X;
- edges fall on the `256px` logical grid;
- no text, grid, UI, watermark, gutter, crop, or perspective;
- one material continues over all internal joins;
- output alpha agrees with the requested background mode.

Reject and regenerate if the geometry contract fails. Do not try to repair an arbitrary image by guessing cuts.

## Compile the 15-piece intermediate atlas

Copy `scripts/compile_dual_grid_windmill.py` into the target project's `tools/` folder and run:

```powershell
python .\tools\compile_dual_grid_windmill.py .\art\windmill_master.png `
  --out-dir .\assets\compiled `
  --tile-size 256 `
  --background-mode transparent
```

Background modes:

- `transparent`: source already has a real alpha background. Default.
- `sample`: preserve a baked flat source background.
- `key-top-left`: remove a flat opaque background matching top-left pixels. Use only when it cannot remove terrain edge colors.

Inspect `dual_grid_15piece_check.png` and its manifest. `0x6` and `0x9` are synthesized diagonal masks and need real seam testing.

## Build the Godot brush

Use `scripts/build_tilemapdual_scene.gd` after TileMapDual is installed. Adjust its constants for the target project, then run it with Godot headless.

The output is a persistent 4x4 TileSet and a scene with a `TileMapDual` node. In Godot, select that node, open TileMap > `Tiles`, select the full tile (`0xF`), and paint ordinary logic cells. TileMapDual creates the half-cell-offset display.

Normal Godot Terrain painting is not the world-map painting path for this plugin.

## Acceptance

- Draw a solid block, thin horizontal/vertical corridors, L bend, concave notch, one-cell island, one-cell hole, and two diagonal cells.
- No gaps, opaque background rectangle, blurred pixels, incorrect convex/concave corners, or disconnected diagonal artifacts.
- Validate in the Godot editor or runtime; the compiler check image alone is insufficient.

For deployment failures, hand off to `../godot-tilemapdual-deployment/SKILL.md`.
