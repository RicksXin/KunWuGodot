extends SceneTree

## Candidate-only Map01 board demo.
##
## This intentionally does not load the formal map scene or any forest/mountain
## boundary art. It renders the formal 48x64 Map01 greybox mask as a flat board
## with cell state fills, a restrained grid, and one-cell marker symbols. The
## demo is a visual direction test; it does not change layout, collision, or UI.

const MASK_PATH := "res://art/candidates/map01_layout/map01_d1_environment_mask_20260820.json"
const REVIEW_DIR := "res://art/review/map01/board_demo"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_board_grid_48x64_demo_overview.png"
const FIT_PATH := REVIEW_DIR + "/map01_board_grid_48x64_demo_viewport_375x817.png"
const MANIFEST_PATH := REVIEW_DIR + "/map01_board_grid_48x64_demo_manifest.json"

const BOARD_SIZE := Vector2i(48, 64)
const FULL_CELL := 16.0
const FIT_CELL := 7.5

const COLOR_CANVAS := Color("#182126")
const COLOR_BOARD := Color("#858b91")
const COLOR_WALKABLE := Color("#858b91")
const COLOR_ROAD := Color("#b3aa90")
const COLOR_BLOCKED := Color("#343b43")
const COLOR_BLOCKED_HIGHLIGHT := Color("#555e67")
const COLOR_RIDGE := Color("#555e67")
const COLOR_FOREGROUND := Color("#20272f")
const COLOR_DIFFICULT := Color("#746f68")
const COLOR_GRID := Color(0.88, 0.92, 0.89, 0.24)
const COLOR_BORDER := Color(0.88, 0.92, 0.89, 0.52)
const COLOR_TEXT := Color("#dce4df")


class BoardLayer extends Node2D:
    var rows: Array = []
    var markers: Array = []
    var cell_size := 48.0
    var board_origin := Vector2.ZERO
    var show_header := true
    var show_legend := true

    func configure(payload: Dictionary, origin: Vector2, cell: float, header: bool, legend: bool) -> void:
        rows = payload.get("rows", [])
        markers = payload.get("markers", []).duplicate(true)
        board_origin = origin
        cell_size = cell
        show_header = header
        show_legend = legend
        queue_redraw()

    func _draw() -> void:
        var board_rect := Rect2(board_origin, Vector2(BOARD_SIZE.x, BOARD_SIZE.y) * cell_size)
        draw_rect(Rect2(Vector2.ZERO, Vector2(1200.0, 1200.0)), COLOR_CANVAS)
        draw_rect(board_rect.grow(8.0), Color(0.08, 0.11, 0.13, 0.85))
        draw_rect(board_rect, COLOR_BOARD)

        for screen_y in range(BOARD_SIZE.y):
            var row_text: String = rows[screen_y] if screen_y < rows.size() else "################################################"
            for cell_x in range(BOARD_SIZE.x):
                var cell_code := row_text.substr(cell_x, 1) if cell_x < row_text.length() else "#"
                var rect := Rect2(
                    board_origin + Vector2(cell_x, screen_y) * cell_size,
                    Vector2.ONE * cell_size
                )
                _draw_cell(rect, cell_code, cell_x, screen_y)

        draw_rect(board_rect, COLOR_BORDER, false, maxf(1.0, cell_size / 24.0))
        for marker in markers:
            _draw_marker(marker)

        if show_header:
            var font := ThemeDB.fallback_font
            draw_string(font, board_origin + Vector2(0.0, -18.0), "MAP01  BOARD DEMO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, COLOR_TEXT)
            draw_string(font, board_origin + Vector2(0.0, -3.0), "48 x 64  |  flat plane + cell state + one-cell markers", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.69, 0.76, 0.73, 0.9))

        if show_legend:
            _draw_legend(board_rect.position + Vector2(0.0, board_rect.size.y + 32.0))

    func _draw_cell(rect: Rect2, cell_code: String, cell_x: int, screen_y: int) -> void:
        var fill := COLOR_WALKABLE
        if cell_code == "#":
            fill = COLOR_BLOCKED
        elif cell_code == "F":
            fill = COLOR_FOREGROUND
        elif cell_code == "R":
            fill = COLOR_RIDGE
        elif cell_code == "=":
            fill = COLOR_ROAD
        elif cell_code == "~":
            fill = COLOR_DIFFICULT
        draw_rect(rect, fill)

        if cell_code == "#" or cell_code == "F":
            # A tiny contained diagonal stamp makes blocked cells readable as a
            # category without turning them into oversized scenery.
            var inset := cell_size * 0.22
            draw_line(
                rect.position + Vector2(inset, rect.size.y - inset),
                rect.position + Vector2(rect.size.x - inset, inset),
                COLOR_BLOCKED_HIGHLIGHT if cell_code == "#" else Color(0.08, 0.11, 0.12, 0.42),
                maxf(1.0, cell_size / 24.0)
            )
            draw_line(
                rect.position + Vector2(inset * 1.4, rect.size.y - inset * 1.4),
                rect.position + Vector2(rect.size.x - inset * 1.4, inset * 1.4),
                Color(0.12, 0.17, 0.19, 0.42),
                maxf(1.0, cell_size / 32.0)
            )
        elif cell_code == "~":
            draw_line(
                rect.position + Vector2(cell_size * 0.2, cell_size * 0.72),
                rect.position + Vector2(cell_size * 0.8, cell_size * 0.28),
                Color(0.98, 0.86, 0.60, 0.42),
                maxf(1.0, cell_size / 24.0)
            )

        draw_rect(rect, COLOR_GRID, false, maxf(1.0, cell_size / 48.0))

    func _draw_marker(marker: Dictionary) -> void:
        var domain_x := int(marker.get("x", 0))
        var domain_y := int(marker.get("y", 0))
        var screen_y := BOARD_SIZE.y - 1 - domain_y
        if domain_x < 0 or domain_x >= BOARD_SIZE.x or screen_y < 0 or screen_y >= BOARD_SIZE.y:
            return

        var cell_rect := Rect2(
            board_origin + Vector2(domain_x, screen_y) * cell_size,
            Vector2.ONE * cell_size
        )
        var center := cell_rect.position + cell_rect.size * 0.5
        var kind := String(marker.get("kind", ""))
        var marker_color := Color("#d9c26c")
        var symbol := "E"
        if kind == "enemy_group":
            marker_color = Color("#d26863")
            symbol = "!"
        elif kind == "story_event":
            marker_color = Color("#b797d8")
            symbol = "?"
        elif kind == "treasure_chest":
            marker_color = Color("#e0b75c")
            symbol = "C"

        draw_rect(cell_rect.grow(-3.0), Color(marker_color, 0.18))
        draw_rect(cell_rect.grow(-3.0), marker_color, false, maxf(2.0, cell_size / 16.0))
        draw_circle(center, cell_size * 0.22, marker_color)
        draw_arc(center, cell_size * 0.28, 0.0, TAU, 16, Color(0.08, 0.11, 0.12, 0.9), maxf(1.0, cell_size / 24.0))
        var font := ThemeDB.fallback_font
        draw_string(font, center + Vector2(-cell_size * 0.08, cell_size * 0.12), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(6, int(cell_size * 0.38)), Color("#192127"))

    func _draw_legend(position: Vector2) -> void:
        var font := ThemeDB.fallback_font
        var swatch := maxf(16.0, cell_size * 0.55)
        var label_size := maxi(10, int(cell_size * 0.26))
        _draw_legend_item(position, swatch, COLOR_WALKABLE, "walkable", font, label_size)
        var step := maxf(112.0, cell_size * 7.2)
        _draw_legend_item(position + Vector2(step, 0.0), swatch, COLOR_BLOCKED, "blocked", font, label_size)
        _draw_legend_item(position + Vector2(step * 2.0, 0.0), swatch, COLOR_DIFFICULT, "difficult", font, label_size)
        draw_string(font, position + Vector2(step * 3.0, swatch * 0.72), "E / ! / ? / C = one-cell markers", HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, COLOR_TEXT)

    func _draw_legend_item(position: Vector2, swatch: float, fill: Color, label: String, font: Font, font_size: int) -> void:
        draw_rect(Rect2(position, Vector2.ONE * swatch), fill)
        draw_rect(Rect2(position, Vector2.ONE * swatch), COLOR_GRID, false, 1.0)
        draw_string(font, position + Vector2(swatch + 6.0, swatch * 0.72), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, COLOR_TEXT)


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    RenderingServer.set_default_clear_color(COLOR_CANVAS)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
    var payload := JSON.parse_string(FileAccess.get_file_as_string(MASK_PATH)) as Dictionary
    if payload.is_empty():
        push_error("Map01 board demo could not load the 48x64 mask")
        quit(1)
        return

    # These are greybox sample anchors only. They demonstrate one-cell marker
    # scale without freezing the still-unverified 1.0 object table.
    payload["markers"] = [
        # The greybox anchors are recorded in top-left scene coordinates;
        # markers use the project's upward-growing domain Y, so convert here.
        {"kind": "entry", "x": 24, "y": 2},
        {"kind": "enemy_group", "x": 31, "y": 14},
        {"kind": "story_event", "x": 24, "y": 27},
        {"kind": "treasure_chest", "x": 38, "y": 40},
    ]

    var overview_error := await _capture(Vector2i(800, 1140), Vector2(16.0, 24.0), FULL_CELL, OVERVIEW_PATH, true, true, payload)
    if overview_error != OK:
        push_error("Could not capture board overview: %s" % error_string(overview_error))
        quit(1)
        return

    var fit_error := await _capture(Vector2i(375, 817), Vector2(7.5, 120.0), FIT_CELL, FIT_PATH, false, false, payload)
    if fit_error != OK:
        push_error("Could not capture board viewport: %s" % error_string(fit_error))
        quit(1)
        return

    var manifest := {
        "schema_version": 1,
        "status": "candidate_board_direction_demo",
        "source_data": MASK_PATH,
        "board": "48x64 Map01 greybox boundary; 3:4 portrait rectangle",
        "d0_note": "The current 15x15 active area is a D0 gameplay crop, not the formal Map01 boundary.",
        "display_cell_size": 16,
        "visual_model": "flat plane + low-contrast grid + per-cell state fills + one-cell marker samples",
        "marker_policy": "markers are centered in one logical cell; state is not baked into the image",
        "marker_coordinates": "greybox sample anchors only; UNVERIFIED for 1.0",
        "generation": "none",
        "meowa_points_spent": 0,
        "formal_scene_modified": false,
        "outputs": [OVERVIEW_PATH, FIT_PATH]
    }
    FileAccess.open(ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  ") + "\n")
    print("MAP01_BOARD_GRID_DEMO_CAPTURE_OK overview=%s fit=%s" % [OVERVIEW_PATH, FIT_PATH])
    quit(0)


func _capture(size: Vector2i, origin: Vector2, cell_size: float, output_path: String, show_header: bool, show_legend: bool, payload: Dictionary) -> Error:
    var viewport := SubViewport.new()
    viewport.size = size
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)

    var layer := BoardLayer.new()
    layer.configure(payload, origin, cell_size, show_header, show_legend)
    viewport.add_child(layer)
    await process_frame
    await process_frame
    await process_frame

    var image := viewport.get_texture().get_image()
    var error := ERR_CANT_CREATE
    if image != null and not image.is_empty():
        error = image.save_png(ProjectSettings.globalize_path(output_path))
    viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    viewport.remove_child(layer)
    layer.free()
    root.remove_child(viewport)
    viewport.free()
    await process_frame
    return error
