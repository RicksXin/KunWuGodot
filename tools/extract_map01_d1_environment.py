#!/usr/bin/env python3
"""Extract the Map01 48x64 D1 environment masks from the approved graybox candidate.

This is an authoring tool. The generated JSON/QA files document the extraction, while
the Godot scene remains the runtime layout fact source after the masks are applied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


MAP_WIDTH = 48
MAP_HEIGHT = 64
QA_CELL_SIZE = 16

SEMANTIC_COLORS = {
    "ground": (133, 139, 145),
    "road": (179, 170, 144),
    "danger": (116, 111, 104),
    "blocked": (52, 59, 67),
    "ridge": (85, 94, 103),
    "foreground": (32, 39, 47),
}

SEMANTIC_CHARS = {
    "ground": ".",
    "road": "=",
    "danger": "~",
    "blocked": "#",
    "ridge": "R",
    "foreground": "F",
}

WALKABLE = {"ground", "road", "danger"}

ANCHORS = {
    "A_safe_entry": (24, 61),
    "B_derelict_camp": (31, 49),
    "C_stele_split": (24, 36),
    "D_mountain_tunnel": (12, 21),
    "E_east_wall_route": (38, 23),
    "F_north_merge": (24, 12),
    "G_wanxiu_gate": (24, 4),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="art/source_archive/map01_layout/map01_layout_collision_candidate_20260820.png",
    )
    parser.add_argument(
        "--json",
        default="art/candidates/map01_layout/map01_d1_environment_mask_20260820.json",
    )
    parser.add_argument(
        "--qa",
        default="art/candidates/map01_layout/map01_d1_environment_mask_qa_20260820.png",
    )
    parser.add_argument(
        "--routes-qa",
        default="art/candidates/map01_layout/map01_d1_environment_routes_qa_20260820.png",
    )
    parser.add_argument(
        "--rock-base",
        default="assets/maps/map_01/environment/map01_d1_rock_base.png",
    )
    parser.add_argument(
        "--foreground",
        default="assets/maps/map_01/environment/map01_d1_foreground.png",
    )
    return parser.parse_args()


def nearest_semantic(color: tuple[int, int, int]) -> tuple[str, int]:
    distances = {
        name: sum((color[index] - target[index]) ** 2 for index in range(3))
        for name, target in SEMANTIC_COLORS.items()
    }
    semantic = min(distances, key=distances.get)
    return semantic, distances[semantic]


def extract_cells(image: Image.Image) -> tuple[list[list[str]], list[dict[str, object]]]:
    if image.size[0] % MAP_WIDTH or image.size[1] % MAP_HEIGHT:
        raise ValueError(f"Graybox size {image.size} is not divisible by {MAP_WIDTH}x{MAP_HEIGHT}")
    cell_width = image.size[0] // MAP_WIDTH
    cell_height = image.size[1] // MAP_HEIGHT
    if cell_width != cell_height:
        raise ValueError(f"Graybox cells are not square: {cell_width}x{cell_height}")

    rows: list[list[str]] = []
    samples: list[dict[str, object]] = []
    inset = max(2, cell_width // 16)
    rgb = image.convert("RGB")
    for y in range(MAP_HEIGHT):
        row: list[str] = []
        for x in range(MAP_WIDTH):
            bounds = (
                x * cell_width + inset,
                y * cell_height + inset,
                (x + 1) * cell_width - inset,
                (y + 1) * cell_height - inset,
            )
            colors = Counter(rgb.crop(bounds).get_flattened_data())
            dominant, pixel_count = colors.most_common(1)[0]
            semantic, distance = nearest_semantic(dominant)
            row.append(semantic)
            samples.append(
                {
                    "cell": [x, y],
                    "dominantColor": "#%02X%02X%02X" % dominant,
                    "dominantPixels": pixel_count,
                    "semantic": semantic,
                    "prototypeDistanceSquared": distance,
                }
            )
        rows.append(row)
    return rows, samples


def cells_for(rows: list[list[str]], semantics: set[str]) -> list[list[int]]:
    return [
        [x, y]
        for y, row in enumerate(rows)
        for x, semantic in enumerate(row)
        if semantic in semantics
    ]


def connected_components(walkable: set[tuple[int, int]]) -> list[set[tuple[int, int]]]:
    remaining = set(walkable)
    components: list[set[tuple[int, int]]] = []
    while remaining:
        start = next(iter(remaining))
        component = {start}
        queue = deque([start])
        remaining.remove(start)
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        components.append(component)
    return sorted(components, key=len, reverse=True)


def shortest_path(
    walkable: set[tuple[int, int]], start: tuple[int, int], end: tuple[int, int]
) -> list[tuple[int, int]]:
    if start not in walkable or end not in walkable:
        return []
    queue = deque([start])
    parents: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
    while queue:
        cell = queue.popleft()
        if cell == end:
            break
        x, y = cell
        for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if neighbor in walkable and neighbor not in parents:
                parents[neighbor] = cell
                queue.append(neighbor)
    if end not in parents:
        return []
    result: list[tuple[int, int]] = []
    current: tuple[int, int] | None = end
    while current is not None:
        result.append(current)
        current = parents[current]
    result.reverse()
    return result


def make_qa(rows: list[list[str]], output: Path, paths: list[list[tuple[int, int]]] | None = None) -> None:
    qa = Image.new("RGB", (MAP_WIDTH * QA_CELL_SIZE, MAP_HEIGHT * QA_CELL_SIZE))
    draw = ImageDraw.Draw(qa)
    for y, row in enumerate(rows):
        for x, semantic in enumerate(row):
            color = SEMANTIC_COLORS[semantic]
            draw.rectangle(
                (
                    x * QA_CELL_SIZE,
                    y * QA_CELL_SIZE,
                    (x + 1) * QA_CELL_SIZE - 1,
                    (y + 1) * QA_CELL_SIZE - 1,
                ),
                fill=color,
            )
    for x in range(0, MAP_WIDTH + 1, 4):
        draw.line((x * QA_CELL_SIZE, 0, x * QA_CELL_SIZE, qa.height), fill=(27, 33, 40), width=1)
    for y in range(0, MAP_HEIGHT + 1, 4):
        draw.line((0, y * QA_CELL_SIZE, qa.width, y * QA_CELL_SIZE), fill=(27, 33, 40), width=1)
    if paths:
        route_colors = [(115, 181, 197), (213, 174, 92)]
        for index, path in enumerate(paths):
            points = [
                (x * QA_CELL_SIZE + QA_CELL_SIZE // 2, y * QA_CELL_SIZE + QA_CELL_SIZE // 2)
                for x, y in path
            ]
            if len(points) > 1:
                draw.line(points, fill=route_colors[index % len(route_colors)], width=3)
        for cell in ANCHORS.values():
            x, y = cell
            draw.rectangle(
                (
                    x * QA_CELL_SIZE + 4,
                    y * QA_CELL_SIZE + 4,
                    x * QA_CELL_SIZE + 11,
                    y * QA_CELL_SIZE + 11,
                ),
                outline=(239, 232, 216),
                width=2,
            )
    output.parent.mkdir(parents=True, exist_ok=True)
    qa.save(output)


def semantic_mask(rows: list[list[str]], semantics: set[str]) -> Image.Image:
    mask = Image.new("L", (MAP_WIDTH * QA_CELL_SIZE, MAP_HEIGHT * QA_CELL_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    for y, row in enumerate(rows):
        for x, semantic in enumerate(row):
            if semantic in semantics:
                draw.rectangle(
                    (
                        x * QA_CELL_SIZE,
                        y * QA_CELL_SIZE,
                        (x + 1) * QA_CELL_SIZE - 1,
                        (y + 1) * QA_CELL_SIZE - 1,
                    ),
                    fill=255,
                )
    return mask


def paste_clipped(canvas: Image.Image, sprite: Image.Image, position: tuple[int, int], clip: Image.Image) -> None:
    temp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    temp.alpha_composite(sprite, position)
    alpha = ImageChops.multiply(temp.getchannel("A"), clip)
    temp.putalpha(alpha)
    canvas.alpha_composite(temp)


def make_environment_overlays(rows: list[list[str]], rock_output: Path, foreground_output: Path) -> None:
    size = (MAP_WIDTH * QA_CELL_SIZE, MAP_HEIGHT * QA_CELL_SIZE)
    rock = Image.new("RGBA", size, (0, 0, 0, 0))
    foreground = Image.new("RGBA", size, (0, 0, 0, 0))
    rock_draw = ImageDraw.Draw(rock)
    foreground_draw = ImageDraw.Draw(foreground)
    blocked_color = (39, 50, 59, 255)
    ridge_color = (46, 58, 68, 255)
    foreground_color = (34, 44, 53, 255)

    for y, row in enumerate(rows):
        for x, semantic in enumerate(row):
            rect = (
                x * QA_CELL_SIZE,
                y * QA_CELL_SIZE,
                (x + 1) * QA_CELL_SIZE - 1,
                (y + 1) * QA_CELL_SIZE - 1,
            )
            if semantic == "blocked":
                rock_draw.rectangle(rect, fill=blocked_color)
            elif semantic == "ridge":
                rock_draw.rectangle(rect, fill=ridge_color)
            elif semantic == "foreground":
                foreground_draw.rectangle(rect, fill=foreground_color)

    # Break up broad rock masses with sparse source-pixel clusters instead of a
    # per-cell checkerboard. The pattern stays crisp after 3x nearest scaling.
    rock_noise = Image.new("RGBA", size, (0, 0, 0, 0))
    rock_noise_draw = ImageDraw.Draw(rock_noise)
    for y in range(3, size[1] - 3, 5):
        for x in range(3, size[0] - 3, 5):
            value = (x * 37 + y * 61 + x * y * 3) % 29
            if value not in {0, 1}:
                continue
            color = (85, 99, 108, 255) if value == 0 else (36, 45, 54, 255)
            rock_noise_draw.point((x, y), fill=color)
            if (x * 13 + y * 7) % 3 == 0:
                rock_noise_draw.point((x + 1, y), fill=color)
    paste_clipped(rock, rock_noise, (0, 0), semantic_mask(rows, {"blocked", "ridge"}))

    foreground_noise = Image.new("RGBA", size, (0, 0, 0, 0))
    foreground_noise_draw = ImageDraw.Draw(foreground_noise)
    for y in range(4, size[1] - 4, 7):
        for x in range(4, size[0] - 4, 7):
            if (x * 19 + y * 23) % 31 == 0:
                foreground_noise_draw.point((x, y), fill=(48, 58, 67, 255))
    paste_clipped(foreground, foreground_noise, (0, 0), semantic_mask(rows, {"foreground"}))

    project_root = Path(__file__).resolve().parents[1]
    blocker_dir = project_root / "assets/maps/map_01/blockers"
    ridge_mask = semantic_mask(rows, {"ridge"})
    ridge_assets = [
        (blocker_dir / "ridge_ne_sw_static.png", False),
        (blocker_dir / "ridge_ne_sw_base.png", False),
        (blocker_dir / "ridge_nw_se_static.png", True),
        (blocker_dir / "ridge_nw_se_base.png", True),
    ]
    ridge_sprites = []
    for path, flip_horizontal in ridge_assets:
        if not path.exists():
            continue
        sprite = Image.open(path).convert("RGBA")
        if flip_horizontal:
            sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        ridge_sprites.append(sprite)
    if ridge_sprites:
        # Follow the authored southwest-running ridge with overlapping approved
        # variants. Use only the longest run in each row so the isolated east-wall
        # ridge cell never pulls the main chain away from its frozen footprint.
        for index, anchor_y in enumerate(range(30, 56, 2)):
            xs = [x for x in range(MAP_WIDTH) if rows[anchor_y][x] == "ridge"]
            if not xs:
                continue
            runs: list[list[int]] = []
            for x in xs:
                if not runs or x != runs[-1][-1] + 1:
                    runs.append([x])
                else:
                    runs[-1].append(x)
            xs = max(runs, key=len)
            sprite = ridge_sprites[index % len(ridge_sprites)]
            scale = (1.0, 0.9, 1.05, 0.95, 1.0)[index % 5]
            if scale != 1.0:
                sprite = sprite.resize(
                    (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))),
                    Image.Resampling.NEAREST,
                )
            anchor_x = round(sum(xs) / len(xs))
            jitter = (-2, 1, 0, 2, -1)[index % 5]
            position = (
                anchor_x * QA_CELL_SIZE + QA_CELL_SIZE // 2 - sprite.width // 2 + jitter,
                (anchor_y + 1) * QA_CELL_SIZE - sprite.height,
            )
            paste_clipped(rock, sprite, position, ridge_mask)

    blocker_assets = [
        blocker_dir / "blocker_1x1_a.png",
        blocker_dir / "blocker_1x1_b.png",
        blocker_dir / "blocker_1x2.png",
        blocker_dir / "blocker_2x2.png",
        blocker_dir / "blocker_2x3.png",
        blocker_dir / "blocker_irregular.png",
    ]
    blocker_sprites = [Image.open(path).convert("RGBA") for path in blocker_assets if path.exists()]
    blocked_mask = semantic_mask(rows, {"blocked"})
    if blocker_sprites:
        # Add a restrained line of rocks only along walkable boundaries. These
        # sit under Ground at runtime, so the Dual Grid edge naturally occludes them.
        edge_sprites = blocker_sprites[:5]
        for y, row in enumerate(rows):
            for x, semantic in enumerate(row):
                if semantic != "blocked":
                    continue
                touches_walkable = any(
                    0 <= next_x < MAP_WIDTH
                    and 0 <= next_y < MAP_HEIGHT
                    and rows[next_y][next_x] in WALKABLE
                    for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                )
                if not touches_walkable or (x * 29 + y * 31) % 23:
                    continue
                sprite = edge_sprites[(x + y) % len(edge_sprites)]
                position = (
                    x * QA_CELL_SIZE + QA_CELL_SIZE // 2 - sprite.width // 2,
                    (y + 1) * QA_CELL_SIZE - sprite.height,
                )
                paste_clipped(rock, sprite, position, blocked_mask)

        # The east-wall ridge is a separate narrow four-cell strip; one vertical
        # approved cluster gives it a distinct landmark without repeating the main chain.
        east_sprite = blocker_sprites[4]
        east_position = (
            45 * QA_CELL_SIZE + QA_CELL_SIZE // 2 - east_sprite.width // 2,
            48 * QA_CELL_SIZE - east_sprite.height,
        )
        paste_clipped(rock, east_sprite, east_position, ridge_mask)

    # One-pixel hard boundaries keep the walkable valley readable at 3x nearest scale.
    # Draw them last so decorative clusters never obscure the collision silhouette.
    for y, row in enumerate(rows):
        for x, semantic in enumerate(row):
            if semantic not in {"blocked", "ridge", "foreground"}:
                continue
            target = foreground_draw if semantic == "foreground" else rock_draw
            color = (88, 102, 111, 255) if semantic == "ridge" else (61, 73, 83, 255)
            left = x * QA_CELL_SIZE
            top = y * QA_CELL_SIZE
            if x > 0 and rows[y][x - 1] in WALKABLE:
                target.line((left, top, left, top + QA_CELL_SIZE - 1), fill=color, width=1)
            if x + 1 < MAP_WIDTH and rows[y][x + 1] in WALKABLE:
                target.line((left + QA_CELL_SIZE - 1, top, left + QA_CELL_SIZE - 1, top + QA_CELL_SIZE - 1), fill=color, width=1)
            if y > 0 and rows[y - 1][x] in WALKABLE:
                target.line((left, top, left + QA_CELL_SIZE - 1, top), fill=color, width=1)
            if y + 1 < MAP_HEIGHT and rows[y + 1][x] in WALKABLE:
                target.line((left, top + QA_CELL_SIZE - 1, left + QA_CELL_SIZE - 1, top + QA_CELL_SIZE - 1), fill=color, width=1)

    rock_output.parent.mkdir(parents=True, exist_ok=True)
    foreground_output.parent.mkdir(parents=True, exist_ok=True)
    rock.save(rock_output)
    foreground.save(foreground_output)


def main() -> None:
    args = parse_args()
    source = Path(args.input)
    image = Image.open(source).convert("RGBA")
    rows, samples = extract_cells(image)
    walkable = set(map(tuple, cells_for(rows, WALKABLE)))
    components = connected_components(walkable)
    anchor_status = {
        name: {"cell": list(cell), "walkable": cell in walkable}
        for name, cell in ANCHORS.items()
    }
    west_path = shortest_path(walkable, ANCHORS["D_mountain_tunnel"], ANCHORS["F_north_merge"])
    east_path = shortest_path(walkable, ANCHORS["E_east_wall_route"], ANCHORS["F_north_merge"])
    if len(components) != 1:
        raise ValueError(f"Expected one walkable component, found {len(components)}")
    if not all(status["walkable"] for status in anchor_status.values()):
        raise ValueError(f"One or more zone anchors are blocked: {anchor_status}")
    if not west_path or not east_path:
        raise ValueError("Both west and east branches must reach the north merge")

    semantic_counts = Counter(semantic for row in rows for semantic in row)
    result = {
        "version": 1,
        "status": "D1_environment_candidate_no_objects",
        "mapId": "map_01",
        "mapSize": [MAP_WIDTH, MAP_HEIGHT],
        "coordinateContract": "top-left scene cells; x grows right; y grows down",
        "source": {
            "path": str(source),
            "sizePx": list(image.size),
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "cellSizePx": image.size[0] // MAP_WIDTH,
        },
        "classification": {
            "method": "dominant inset cell color mapped to nearest approved semantic prototype",
            "semanticColors": {name: "#%02X%02X%02X" % color for name, color in SEMANTIC_COLORS.items()},
            "semanticChars": SEMANTIC_CHARS,
            "counts": dict(sorted(semantic_counts.items())),
        },
        "rows": ["".join(SEMANTIC_CHARS[semantic] for semantic in row) for row in rows],
        "groundCells": cells_for(rows, WALKABLE),
        "roadCells": cells_for(rows, {"road"}),
        "difficultCells": cells_for(rows, {"danger"}),
        "blockedCells": cells_for(rows, {"blocked"}),
        "ridgeCells": cells_for(rows, {"ridge"}),
        "foregroundCells": cells_for(rows, {"foreground"}),
        "collisionBlockedCells": cells_for(rows, {"blocked", "ridge", "foreground"}),
        "qa": {
            "walkableComponents": [len(component) for component in components],
            "anchors": anchor_status,
            "westBranchToNorthMergeSteps": len(west_path) - 1,
            "eastBranchToNorthMergeSteps": len(east_path) - 1,
            "difficultIsGroundSubset": True,
            "roadIsGroundSubset": True,
        },
        "dominantCellSamples": samples,
        "notes": [
            "Object markers and landmark state colors are intentionally excluded from the semantic palette.",
            "This extraction does not freeze formal object coordinates or resolve the two known shared-cell conflicts.",
            "The generated Godot D1 environment scene is a no-object visual/layout candidate and does not replace the D0 playable scene.",
        ],
    }
    output = Path(args.json)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    make_qa(rows, Path(args.qa))
    make_qa(rows, Path(args.routes_qa), [west_path, east_path])
    make_environment_overlays(rows, Path(args.rock_base), Path(args.foreground))
    print(
        "MAP01_D1_MASK_OK "
        f"ground={len(result['groundCells'])} road={len(result['roadCells'])} "
        f"danger={len(result['difficultCells'])} blocked={len(result['collisionBlockedCells'])} "
        f"west_steps={len(west_path) - 1} east_steps={len(east_path) - 1}"
    )


if __name__ == "__main__":
    main()
