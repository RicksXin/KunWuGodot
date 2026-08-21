extends SceneTree

const TILE := Vector2i(256, 256)
const INPUT_ATLAS := "res://art/candidates/map01_mountain_windmill/compiled_v2c/atlas/dual_grid_15piece.png"
const OUTPUT_DIR := "res://art/review/map01/map01_mountain_candidate"
const OUTPUT_ATLAS := OUTPUT_DIR + "/tilemapdual_mountain_standard.png"
const TILESET_PATH := OUTPUT_DIR + "/tilemapdual_map01_mountain_candidate.tres"
const SCENE_PATH := OUTPUT_DIR + "/map01_mountain_candidate_preview.tscn"
const GROUND_TILESET_PATH := "res://resources/tilemapdual_standard.tres"
const ROAD_TILESET_PATH := "res://resources/tilemapdual_map01_road.tres"
const TILEMAP_DUAL_SCRIPT := "res://addons/TileMapDual/tile_map_dual.gd"
const EMPTY_COLOR := Color(0, 0, 0, 0)
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
	assert(ResourceLoader.exists(ROAD_TILESET_PATH), "Map01 road TileSet is missing")
	var atlas_image := _build_standard_atlas()
	var tile_set := _build_tileset(atlas_image)
	assert(ResourceSaver.save(tile_set, TILESET_PATH) == OK)
	var saved_tile_set := load(TILESET_PATH) as TileSet
	assert(saved_tile_set != null, "Unable to reload candidate TileSet")
	_build_scene(saved_tile_set)
	print("MAP01_MOUNTAIN_CANDIDATE_BUILD_OK tileset=%s scene=%s" % [TILESET_PATH, SCENE_PATH])
	quit.call_deferred(0)


func _build_standard_atlas() -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(INPUT_ATLAS))
	assert(not image.is_empty(), "Unable to load candidate atlas: %s" % INPUT_ATLAS)
	assert(image.get_size() == Vector2i(TILE.x * 5, TILE.y * 3), "Unexpected 15-piece atlas size")
	var output := Image.create(TILE.x * 4, TILE.y * 4, false, Image.FORMAT_RGBA8)
	for mask in range(16):
		var destination: Vector2i = MASK_TO_STANDARD[mask]
		if mask == 0:
			output.fill_rect(Rect2i(destination * TILE, TILE), EMPTY_COLOR)
			continue
		var index := mask - 1
		var source := Vector2i(index % 5, index / 5)
		output.blit_rect(image, Rect2i(source * TILE, TILE), destination * TILE)
	assert(output.save_png(ProjectSettings.globalize_path(OUTPUT_ATLAS)) == OK)
	return output


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
	tile_set.set_terrain_name(0, 0, "Empty")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Map01 Mountain Candidate")
	tile_set.add_source(source, 0)
	return tile_set


func _build_scene(mountain_tile_set: TileSet) -> void:
	var root := Node2D.new()
	root.name = "Map01MountainCandidatePreview"
	root.position = Vector2(24.0, 24.0)
	root.scale = MAP_SCALE

	var ground := _make_dual_layer("Ground", load(GROUND_TILESET_PATH) as TileSet, 0)
	for y in range(17):
		for x in range(7):
			ground.set_cell(Vector2i(x, y), 0, FULL_TILE)
	root.add_child(ground)
	ground.owner = root

	var road := _make_dual_layer("Road", load(ROAD_TILESET_PATH) as TileSet, 2)
	for y in range(2, 16):
		road.set_cell(Vector2i(3, y), 0, FULL_TILE)
	root.add_child(road)
	road.owner = root

	var mountain := _make_dual_layer("MountainCandidate", mountain_tile_set, 4)
	for cell in _mountain_cells():
		mountain.set_cell(cell, 0, FULL_TILE)
	root.add_child(mountain)
	mountain.owner = root

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


func _mountain_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(2):
		for x in range(7):
			cells.append(Vector2i(x, y))
	for y in range(2, 8):
		cells.append(Vector2i(0, y))
		cells.append(Vector2i(1, y))
	for y in range(10, 17):
		cells.append(Vector2i(5, y))
		cells.append(Vector2i(6, y))
	for y in range(12, 17):
		cells.append(Vector2i(4, y))
	for y in range(5, 8):
		cells.append(Vector2i(5, y))
	cells.append(Vector2i(4, 7))
	return cells
