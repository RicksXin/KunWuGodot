extends SceneTree

const ENVIRONMENT_SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const MOUNTAIN_TILESET_PATH := "res://resources/tilemapdual_map01_mountain.tres"
const TILEMAP_DUAL_SCRIPT_PATH := "res://addons/TileMapDual/tile_map_dual.gd"
const REVIEW_DIR := "res://art/review/map01/map01_d1_mountain_body_candidate"
const CURRENT_PATH := REVIEW_DIR + "/map01_current_rockbase_viewport_375x817.png"
const CANDIDATE_PATH := REVIEW_DIR + "/map01_mountain_body_viewport_375x817.png"
const COMPARISON_PATH := REVIEW_DIR + "/map01_current_vs_mountain_body.png"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_mountain_body_overview.png"
const MANIFEST_PATH := REVIEW_DIR + "/review_manifest.json"

const COMPLETE_TILE := Vector2i(2, 1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var viewport_size := Vector2i(375, 817)
	var center := Vector2(24.0 * 48.0, 37.0 * 48.0)
	var world_offset := Vector2(viewport_size) * 0.5 - center

	var current := await _capture_environment(viewport_size, world_offset, false)
	var candidate := await _capture_environment(viewport_size, world_offset, true)
	var overview := await _capture_environment(Vector2i(2352, 3120), Vector2(24.0, 24.0), true)
	assert(not current.is_empty(), "Could not capture current D1 environment")
	assert(not candidate.is_empty(), "Could not capture D1 mountain-body candidate")
	assert(not overview.is_empty(), "Could not capture D1 mountain-body overview")
	assert(current.save_png(ProjectSettings.globalize_path(CURRENT_PATH)) == OK)
	assert(candidate.save_png(ProjectSettings.globalize_path(CANDIDATE_PATH)) == OK)
	assert(overview.save_png(ProjectSettings.globalize_path(OVERVIEW_PATH)) == OK)

	var comparison := Image.create(viewport_size.x * 2, viewport_size.y, false, Image.FORMAT_RGBA8)
	comparison.blit_rect(current, Rect2i(Vector2i.ZERO, viewport_size), Vector2i.ZERO)
	comparison.blit_rect(candidate, Rect2i(Vector2i.ZERO, viewport_size), Vector2i(viewport_size.x, 0))
	assert(comparison.save_png(ProjectSettings.globalize_path(COMPARISON_PATH)) == OK)
	_write_manifest()
	print("MAP01_D1_MOUNTAIN_BODY_CANDIDATE_OK comparison=%s" % COMPARISON_PATH)
	quit(0)


func _capture_environment(size: Vector2i, world_offset: Vector2, with_mountain_body: bool) -> Image:
	var viewport := _make_viewport(size)
	var holder := Node2D.new()
	holder.position = world_offset
	viewport.add_child(holder)
	var packed := load(ENVIRONMENT_SCENE_PATH) as PackedScene
	assert(packed != null, "Map01 D1 environment scene is missing")
	var environment := packed.instantiate()
	if with_mountain_body:
		_add_mountain_body(environment)
	holder.add_child(environment)
	var image := await _read_viewport(viewport)
	await _dispose_viewport(viewport)
	return image


func _add_mountain_body(environment: Node2D) -> void:
	var ground := environment.get_node("Ground") as TileMapLayer
	assert(ground != null, "Ground layer is missing")
	var rock_base := environment.get_node("RockBase") as Sprite2D
	var foreground_visual := environment.get_node("ForegroundVisual") as Sprite2D
	var difficult_visual := environment.get_node("DifficultVisual") as TileMapLayer
	assert(rock_base != null and foreground_visual != null, "Legacy blocker sprites are missing")
	assert(difficult_visual != null, "DifficultVisual layer is missing")
	rock_base.visible = false
	foreground_visual.visible = false
	difficult_visual.visible = false
	var mountain_tile_set := load(MOUNTAIN_TILESET_PATH) as TileSet
	assert(mountain_tile_set != null, "Map01 mountain TileSet is missing")
	var width := int(environment.get("active_width"))
	var height := int(environment.get("active_height"))
	assert(width == 48 and height == 64, "Unexpected D1 active bounds")

	var underlay := TileMapLayer.new()
	underlay.name = "GroundUnderlayCandidate"
	underlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	underlay.z_index = -4
	underlay.tile_set = ground.tile_set
	underlay.set_script(load(TILEMAP_DUAL_SCRIPT_PATH))
	for y in height:
		for x in width:
			underlay.set_cell(Vector2i(x, y), 0, COMPLETE_TILE)
	environment.add_child(underlay)

	var mountain := TileMapLayer.new()
	mountain.name = "MountainBodyCandidate"
	mountain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mountain.z_index = 3
	mountain.tile_set = mountain_tile_set
	mountain.set_script(load(TILEMAP_DUAL_SCRIPT_PATH))
	var blocked_count := 0
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if ground.get_cell_source_id(cell) >= 0:
				continue
			mountain.set_cell(cell, 0, COMPLETE_TILE)
			blocked_count += 1
	assert(blocked_count == 888, "D1 blocked-cell count changed: %d" % blocked_count)
	environment.add_child(mountain)


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport


func _read_viewport(viewport: SubViewport) -> Image:
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	assert(image != null and not image.is_empty(), "SubViewport returned an empty image")
	return image


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame


func _write_manifest() -> void:
	var manifest := {
		"schema_version": 1,
		"status": "candidate_pending_user_visual_gate",
		"purpose": "Replace flat D1 RockBase and foreground blocker sprites with the approved Map01 mountain Dual Grid body",
		"source_scene": ENVIRONMENT_SCENE_PATH,
		"source_tileset": MOUNTAIN_TILESET_PATH,
		"mountain_cells": 888,
		"cell_derivation": "exact complement of Ground inside the 48x64 active bounds",
		"ground_underlay_cells": 3072,
		"ground_underlay_role": "visual seam fill only; does not own walkability or collision",
		"legacy_rock_base_visible": false,
		"legacy_foreground_visual_visible": false,
		"difficult_visual_visible": false,
		"ground_cells_changed": false,
		"road_cells_changed": false,
		"collision_changed": false,
		"product_data_modified": false,
		"meowa_points_spent": 0,
		"review_outputs": [CURRENT_PATH, CANDIDATE_PATH, COMPARISON_PATH, OVERVIEW_PATH],
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	assert(file != null, "Could not create D1 mountain-body candidate manifest")
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
