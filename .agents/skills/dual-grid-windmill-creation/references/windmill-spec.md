# Windmill Specification

## Logical occupancy

The fixed master uses these terrain cells, from top to bottom:

```text
0 1 0 0
0 1 1 1
1 1 1 0
0 0 1 0
```

Each cell is `256px` when the canvas is `1024px`.

## Dual Grid rule

The logic grid is painted in full cells. The visible grid is moved half a cell in X and Y. At each visual intersection:

```text
NW = 1   NE = 2
SW = 4   SE = 8
mask = NW + NE + SW + SE
```

Masks `0x1` to `0xF` are the 15 visible pieces. `0x0` is empty.

The compiler samples a `256x256` window centered on every logical-grid intersection. This is why the source must be one continuous image with exact cell alignment.

## Clean-reference requirement

The repository's reference PNG has purple verification lines. A user-facing Agent must supply a clean copy of the same silhouette for image generation, with no purple lines or labels.

## Rejection rules

Reject any source with:

- diagonal X geometry;
- 15 disconnected mini-tiles;
- non-square or non-1024px master;
- terrain boundaries that drift away from the 256px grid;
- opaque blank background when transparency was requested;
- text, guide lines, checkerboard, UI, margins, crop, or perspective;
- visually unrelated texture per arm or visible internal seams.
