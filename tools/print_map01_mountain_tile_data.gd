extends SceneTree

const TILE := Vector2i(2, 1)

func _init() -> void:
	var packed := load("res://scenes/maps/map_01_d1_environment.tscn") as PackedScene
	assert(packed != null)
	var instance := packed.instantiate()
	var ground := instance.get_node("Ground") as TileMapLayer
	assert(ground != null)
	var underlay := TileMapLayer.new()
	var mountain := TileMapLayer.new()
	for y in 64:
		for x in 48:
			var cell := Vector2i(x, y)
			underlay.set_cell(cell, 0, TILE)
			if ground.get_cell_source_id(cell) < 0:
				mountain.set_cell(cell, 0, TILE)
	print("UNDERLAY=" + Marshalls.raw_to_base64(underlay.get_tile_map_data_as_array()))
	print("MOUNTAIN=" + Marshalls.raw_to_base64(mountain.get_tile_map_data_as_array()))
	print("UNDERLAY_COUNT=" + str(underlay.get_used_cells().size()))
	print("MOUNTAIN_COUNT=" + str(mountain.get_used_cells().size()))
	quit(0)
