extends SceneTree

const SOURCE_ATLAS := "res://art/source_archive/meowa/map01_road_dual_transition/2026-08-21/Background_is_gray_rocky_ground_foreground_is_an_old_ochre_dirt_road/tileset.png"
const OUTPUT_DIR := "res://art/review/map01/map01_road_dual_transition_candidate"
const OUTPUT_ATLAS := OUTPUT_DIR + "/tilemapdual_map01_road_dual_standard.png"
const TILESET_PATH := OUTPUT_DIR + "/tilemapdual_map01_road_dual_candidate.tres"
const SCENE_PATH := OUTPUT_DIR + "/map01_road_dual_candidate_patterns.tscn"
const GROUND_TILESET_PATH := "res://resources/tilemapdual_standard.tres"
const TILEMAP_DUAL_SCRIPT := "res://addons/TileMapDual/tile_map_dual.gd"
const SOURCE_TILE := Vector2i(64, 64)
const TILE := Vector2i(256, 256)
const FULL_TILE := Vector2i(2, 1)
const MAP_SCALE := Vector2(0.1875, 0.1875)

const MASK_TO_STANDARD := [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
]

const CORNER_BITS := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	assert(FileAccess.file_exists(TILEMAP_DUAL_SCRIPT), "TileMapDual plugin is missing")
	assert(ResourceLoader.exists(GROUND_TILESET_PATH), "Map01 ground TileSet is missing")
	var atlas_image := _prepare_project_atlas()
	var tile_set := _build_tileset(atlas_image)
	assert(ResourceSaver.save(tile_set, TILESET_PATH) == OK)
	var saved_tile_set := load(TILESET_PATH) as TileSet
	assert(saved_tile_set != null, "Unable to reload candidate TileSet")
	_build_pattern_scene(saved_tile_set)
	print("MAP01_ROAD_DUAL_CANDIDATE_BUILD_OK tileset=%s scene=%s" % [TILESET_PATH, SCENE_PATH])
	quit.call_deferred(0)


func _prepare_project_atlas() -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_ATLAS))
	assert(not image.is_empty(), "Unable to load Meowa atlas: %s" % SOURCE_ATLAS)
	assert(image.get_size() == SOURCE_TILE * 4, "Meowa atlas must be 256x256")
	assert(image.get_format() == Image.FORMAT_RGBA8, "Meowa atlas must be RGBA8")
	image.resize(TILE.x * 4, TILE.y * 4, Image.INTERPOLATE_NEAREST)
	assert(image.save_png(ProjectSettings.globalize_path(OUTPUT_ATLAS)) == OK)
	return image


func _build_tileset(atlas_image: Image) -> TileSet:
	var source := TileSetAtlasSource.new()
	var imported_texture := load(OUTPUT_ATLAS) as Texture2D if ResourceLoader.exists(OUTPUT_ATLAS) else null
	source.texture = imported_texture if imported_texture != null else ImageTexture.create_from_image(atlas_image)
	source.texture_region_size = TILE
	for mask in range(16):
		var cell: Vector2i = MASK_TO_STANDARD[mask]
		source.create_tile(cell)
		var data := source.get_tile_data(cell, 0)
		data.terrain_set = 0
		for bit in CORNER_BITS.size():
			data.set_terrain_peering_bit(CORNER_BITS[bit], 1 if (mask & (1 << bit)) else 0)
	source.get_tile_data(MASK_TO_STANDARD[0], 0).terrain = 0
	source.get_tile_data(MASK_TO_STANDARD[15], 0).terrain = 1

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE
	tile_set.add_terrain_set(0)
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "Map01 Gray Rocky Ground")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Map01 Old Ochre Road")
	tile_set.add_source(source, 0)
	return tile_set


func _build_pattern_scene(road_tile_set: TileSet) -> void:
	var root := Node2D.new()
	root.name = "Map01RoadDualCandidatePatterns"
	root.position = Vector2(24.0, 24.0)
	root.scale = MAP_SCALE

	var ground := _make_dual_layer("Ground", load(GROUND_TILESET_PATH) as TileSet, 0)
	for y in range(12):
		for x in range(16):
			ground.set_cell(Vector2i(x, y), 0, FULL_TILE)
	root.add_child(ground)
	ground.owner = root

	var road := _make_dual_layer("RoadCandidate", road_tile_set, 1)
	for cell in _pattern_cells():
		road.set_cell(cell, 0, FULL_TILE)
	root.add_child(road)
	road.owner = root

	var scene := PackedScene.new()
	assert(scene.pack(root) == OK)
	assert(ResourceSaver.save(scene, SCENE_PATH) == OK)
	root.free()


func _make_dual_layer(node_name: String, tile_set: TileSet, layer_z: int) -> TileMapLayer:
	assert(tile_set != null, "%s TileSet is missing" % node_name)
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = layer_z
	layer.tile_set = tile_set
	layer.set_script(load(TILEMAP_DUAL_SCRIPT))
	return layer


func _pattern_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [
		# Ring with a one-cell hole.
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		# T junction.
		Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
		Vector2i(7, 2), Vector2i(7, 3),
		# L bend.
		Vector2i(11, 1), Vector2i(11, 2), Vector2i(11, 3),
		Vector2i(12, 3), Vector2i(13, 3),
		# One-cell island and straight corridors.
		Vector2i(2, 7),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
		Vector2i(11, 6), Vector2i(11, 7), Vector2i(11, 8), Vector2i(11, 9),
		# Both diagonal contacts.
		Vector2i(14, 6), Vector2i(15, 7),
		Vector2i(15, 9), Vector2i(14, 10),
	]
	return cells
