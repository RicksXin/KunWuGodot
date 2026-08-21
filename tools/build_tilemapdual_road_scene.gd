extends SceneTree

const TILE := Vector2i(256, 256)
const INPUT_ATLAS := "res://assets/compiled/map01_road/dual_grid_15piece.png"
const BACKGROUND_TILE := "res://assets/compiled/map01_road/dual_background_tile.png"
const OUTPUT_ATLAS := "res://assets/compiled/map01_road/tilemapdual_standard.png"
const TILESET_PATH := "res://resources/tilemapdual_map01_road.tres"
const SCENE_PATH := "res://scenes/tilemapdual_road_demo.tscn"
const TILEMAP_DUAL_SCRIPT := "res://addons/TileMapDual/tile_map_dual.gd"
const EMPTY_COLOR := Color(0, 0, 0, 0)

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources"))
	var atlas_image := _build_standard_atlas()
	var tile_set := _build_tileset(atlas_image)
	assert(ResourceSaver.save(tile_set, TILESET_PATH) == OK)
	var saved_tile_set := load(TILESET_PATH) as TileSet
	assert(saved_tile_set != null, "Unable to reload TileSet: %s" % TILESET_PATH)
	assert(FileAccess.file_exists(TILEMAP_DUAL_SCRIPT), "TileMapDual plugin is missing")
	_build_scene(saved_tile_set)
	quit.call_deferred(0)

func _build_standard_atlas() -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(INPUT_ATLAS))
	assert(not image.is_empty(), "Unable to load input atlas: %s" % INPUT_ATLAS)
	var output := Image.create(TILE.x * 4, TILE.y * 4, false, Image.FORMAT_RGBA8)
	var background := Image.load_from_file(ProjectSettings.globalize_path(BACKGROUND_TILE))
	if not background.is_empty():
		assert(background.get_size() == TILE, "Road background tile must be 256x256")
	for mask in range(16):
		var destination: Vector2i = MASK_TO_STANDARD[mask]
		if mask == 0:
			if background.is_empty():
				output.fill_rect(Rect2i(destination * TILE, TILE), EMPTY_COLOR)
			else:
				output.blit_rect(background, Rect2i(Vector2i.ZERO, TILE), destination * TILE)
			continue
		var index := mask - 1
		var source := Vector2i(index % 5, index / 5)
		output.blit_rect(image, Rect2i(source * TILE, TILE), destination * TILE)
	assert(output.save_png(ProjectSettings.globalize_path(OUTPUT_ATLAS)) == OK)
	return output

func _build_tileset(atlas_image: Image) -> TileSet:
	var source := TileSetAtlasSource.new()
	var imported_texture := load(OUTPUT_ATLAS) as Texture2D
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

func _build_scene(tile_set: TileSet) -> void:
	var root := Node2D.new()
	root.name = "TileMapDualRoadDemo"
	var world := TileMapLayer.new()
	world.name = "TileMapDual"
	world.set_script(load(TILEMAP_DUAL_SCRIPT))
	world.tile_set = tile_set
	world.position = Vector2(160, 96)
	for cell in _world_cells():
		world.set_cell(cell, 0, MASK_TO_STANDARD[15])
	root.add_child(world)
	world.owner = root

	var scene := PackedScene.new()
	assert(scene.pack(root) == OK)
	assert(ResourceSaver.save(scene, SCENE_PATH) == OK)
	root.free()

func _world_cells() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(2, 3),
	]
