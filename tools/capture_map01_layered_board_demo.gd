extends SceneTree

## Candidate-only Map01 layered-board preview.
##
## Loads deterministic images from art/candidates with Image.load_from_file(),
## then composes Base -> Grid -> optional BlockedDebug in an isolated
## SubViewport. It never loads or modifies the formal map scene.

const BASE_PATH := "res://art/candidates/map01_layered_board/compiled/map01_board_base_2304x3072.png"
const GRID_PATH := "res://art/candidates/map01_layered_board/compiled/map01_grid_overlay_2304x3072.png"
const BLOCKED_PATH := "res://art/candidates/map01_layered_board/compiled/map01_blocked_debug_overlay_2304x3072.png"
const REVIEW_DIR := "res://art/review/map01/layered_board_demo"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_layered_board_overview.png"
const OVERVIEW_DEBUG_PATH := REVIEW_DIR + "/map01_layered_board_blocked_debug.png"
const VIEWPORT_PATH := REVIEW_DIR + "/map01_layered_board_viewport_375x817.png"
const VIEWPORT_DEBUG_PATH := REVIEW_DIR + "/map01_layered_board_viewport_blocked_debug_375x817.png"
const MANIFEST_PATH := REVIEW_DIR + "/manifest.json"

const BOARD_SIZE := Vector2i(2304, 3072)
const OVERVIEW_SIZE := Vector2i(768, 1024)
const EXPLORATION_VIEWPORT_SIZE := Vector2i(375, 817)
const OVERVIEW_SCALE := 1.0 / 3.0
const CELL_SIZE := 48.0
const FOCUS_CELL := Vector2(24.0, 36.0)
const CLEAR_COLOR := Color("#151c22")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(CLEAR_COLOR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))

	var textures := {
		"base": _load_candidate_texture(BASE_PATH),
		"grid": _load_candidate_texture(GRID_PATH),
		"blocked": _load_candidate_texture(BLOCKED_PATH),
	}
	for key in textures:
		if textures[key] == null:
			push_error("Map01 layered-board preview could not load %s" % key)
			quit(1)
			return

	var overview_error := await _capture(
		OVERVIEW_SIZE,
		Vector2.ZERO,
		OVERVIEW_SCALE,
		false,
		OVERVIEW_PATH,
		textures
	)
	var overview_debug_error := await _capture(
		OVERVIEW_SIZE,
		Vector2.ZERO,
		OVERVIEW_SCALE,
		true,
		OVERVIEW_DEBUG_PATH,
		textures
	)

	var focus := (FOCUS_CELL + Vector2.ONE * 0.5) * CELL_SIZE
	var viewport_offset := Vector2(EXPLORATION_VIEWPORT_SIZE) * 0.5 - focus
	var viewport_error := await _capture(
		EXPLORATION_VIEWPORT_SIZE,
		viewport_offset,
		1.0,
		false,
		VIEWPORT_PATH,
		textures
	)
	var viewport_debug_error := await _capture(
		EXPLORATION_VIEWPORT_SIZE,
		viewport_offset,
		1.0,
		true,
		VIEWPORT_DEBUG_PATH,
		textures
	)

	var errors := [overview_error, overview_debug_error, viewport_error, viewport_debug_error]
	for error in errors:
		if error != OK:
			push_error("Map01 layered-board capture failed: %s" % error_string(error))
			quit(1)
			return

	var manifest := {
		"schema_version": 1,
		"status": "candidate_layered_board_preview",
		"layer_order": ["base", "grid", "optional_blocked_debug"],
		"overview": "complete 48x64 board rendered at one third scale",
		"runtime_viewport": "real 375x817 crop at 48 pixels per logical cell",
		"runtime_viewport_focus_cell": [int(FOCUS_CELL.x), int(FOCUS_CELL.y)],
		"marker_or_building_layers_included": false,
		"formal_scene_modified": false,
		"meowa_points_spent": 0,
		"outputs": [OVERVIEW_PATH, OVERVIEW_DEBUG_PATH, VIEWPORT_PATH, VIEWPORT_DEBUG_PATH],
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not write Map01 layered-board preview manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	print("MAP01_LAYERED_BOARD_CAPTURE_OK overview=%s viewport=%s" % [OVERVIEW_PATH, VIEWPORT_PATH])
	quit(0)


func _load_candidate_texture(path: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	if image.get_size() != BOARD_SIZE:
		push_error("Unexpected image size for %s: %s" % [path, image.get_size()])
		return null
	return ImageTexture.create_from_image(image)


func _capture(
	size: Vector2i,
	world_offset: Vector2,
	world_scale: float,
	show_blocked_debug: bool,
	output_path: String,
	textures: Dictionary
) -> Error:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	root.add_child(viewport)

	var holder := Node2D.new()
	holder.position = world_offset
	holder.scale = Vector2.ONE * world_scale
	viewport.add_child(holder)
	_add_layer(holder, textures["base"] as Texture2D)
	_add_layer(holder, textures["grid"] as Texture2D)
	if show_blocked_debug:
		_add_layer(holder, textures["blocked"] as Texture2D)

	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var error := ERR_CANT_CREATE
	if image != null and not image.is_empty():
		error = image.save_png(ProjectSettings.globalize_path(output_path))

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	return error


func _add_layer(parent: Node2D, texture: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(sprite)
