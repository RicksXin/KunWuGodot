extends SceneTree

const SCENE_PATH := "res://art/review/map01/map01_road_dual_transition_candidate/map01_road_dual_candidate_patterns.tscn"
const ATLAS_PATH := "res://art/review/map01/map01_road_dual_transition_candidate/tilemapdual_map01_road_dual_standard.png"
const TILESET_PATH := "res://art/review/map01/map01_road_dual_transition_candidate/tilemapdual_map01_road_dual_candidate.tres"
const MASK_TO_STANDARD := [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
]

const PATTERNS := {
	"solid_block": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"horizontal_corridor": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"vertical_corridor": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"l_bend": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"concave_notch": [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	],
	"one_cell_island": [Vector2i(0, 0)],
	"one_cell_hole": [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	],
	"diagonal_nw_se": [Vector2i(0, 0), Vector2i(1, 1)],
	"diagonal_ne_sw": [Vector2i(1, 0), Vector2i(0, 1)],
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	assert(not atlas.is_empty(), "Candidate atlas is missing")
	assert(atlas.get_size() == Vector2i(1024, 1024), "Candidate atlas must be 1024x1024")
	assert(atlas.get_format() == Image.FORMAT_RGBA8, "Candidate atlas must be RGBA8")
	assert(not atlas.detect_alpha(), "Dual-terrain atlas must be fully opaque")
	assert(ResourceLoader.exists(TILESET_PATH), "Candidate TileSet is missing")
	var packed := load(SCENE_PATH) as PackedScene
	assert(packed != null, "Candidate pattern scene is missing")
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var world := instance.get_node("RoadCandidate") as TileMapLayer
	assert(world != null, "RoadCandidate node was not created")
	assert(world.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd")
	assert(world.get_child_count() == 1, "TileMapDual display was not created")
	var display := world.get_child(0)
	assert(display.get_child_count() == 1, "Expected one square-grid display layer")
	var display_layer := display.get_child(0) as TileMapLayer
	assert(display_layer != null)
	assert(display_layer.position == Vector2(-128, -128), "Display layer is not half-cell offset")

	var seen_masks: Dictionary[int, bool] = {}
	for pattern_name: String in PATTERNS:
		world.clear()
		for cell: Vector2i in PATTERNS[pattern_name]:
			world.call("draw_cell", cell, 1)
		await process_frame
		await process_frame
		var masks := _visible_masks(display_layer)
		assert(not masks.is_empty(), "%s produced no display tiles" % pattern_name)
		for mask: int in masks:
			seen_masks[mask] = true
		print("road_dual_", pattern_name, " masks=", masks)

	var diagonal_nw_se := await _visible_masks_for(PATTERNS.diagonal_nw_se, world, display_layer)
	var diagonal_ne_sw := await _visible_masks_for(PATTERNS.diagonal_ne_sw, world, display_layer)
	assert(9 in diagonal_nw_se)
	assert(6 in diagonal_ne_sw)
	var missing: Array[int] = []
	for mask in range(1, 16):
		if mask not in seen_masks:
			missing.append(mask)
	assert(missing.is_empty(), "Candidate masks not exercised: %s" % [missing])
	print("MAP01_ROAD_DUAL_CANDIDATE_VALIDATION_OK masks=0x1-0xF")
	instance.queue_free()
	_finish.call_deferred()


func _finish() -> void:
	await process_frame
	await process_frame
	quit(0)


func _visible_masks_for(cells: Array, world: TileMapLayer, display_layer: TileMapLayer) -> Array[int]:
	world.clear()
	for cell: Vector2i in cells:
		world.call("draw_cell", cell, 1)
	await process_frame
	await process_frame
	return _visible_masks(display_layer)


func _visible_masks(display_layer: TileMapLayer) -> Array[int]:
	var masks: Array[int] = []
	for cell: Vector2i in display_layer.get_used_cells():
		var atlas := display_layer.get_cell_atlas_coords(cell)
		var mask := MASK_TO_STANDARD.find(atlas)
		if mask > 0 and mask not in masks:
			masks.append(mask)
	masks.sort()
	return masks
