extends TileMapLayer
## Four logical corners select one Meowa atlas tile. No collision inferred from art.
const ATLAS := [Vector2i(0,3), Vector2i(3,3), Vector2i(0,0), Vector2i(3,2),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,3), Vector2i(3,1),
	Vector2i(1,3), Vector2i(0,1), Vector2i(3,0), Vector2i(2,0),
	Vector2i(1,0), Vector2i(2,2), Vector2i(1,1), Vector2i(2,1)]
var stone: Dictionary = {}
var extent := Vector2i(5, 4)

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(128, 64)
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/prototypes/camp_terrain/stone_dirt.png")
	atlas.texture_region_size = Vector2i(128, 64)
	for y in range(4):
		for x in range(4):
			atlas.create_tile(Vector2i(x, y))
	tile_set.add_source(atlas, 0)

func mask_at(cell: Vector2i) -> int:
	var mask := 0
	for i in range(4):
		var offset: Vector2i = [Vector2i(-1,-1), Vector2i(-1,0), Vector2i(0,-1), Vector2i.ZERO][i]
		if stone.has(cell + offset): mask |= 1 << i
	return mask

func rebuild() -> void:
	clear()
	for y in range(extent.y + 1):
		for x in range(extent.x + 1):
			var cell := Vector2i(x,y)
			set_cell(cell, 0, ATLAS[mask_at(cell)])

func paint(cell: Vector2i, enabled: bool) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= extent.x or cell.y >= extent.y:
		return false
	if enabled: stone[cell] = true
	else: stone.erase(cell)
	# A logical point influences four surrounding display cells only.
	for offset in [Vector2i.ZERO, Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
		var display: Vector2i = cell + offset
		set_cell(display, 0, ATLAS[mask_at(display)])
	return true

func load_fixture(index: int) -> void:
	stone.clear()
	extent = Vector2i(5,4)
	for y in range(extent.y):
		for x in range(extent.x):
			var on := false
			match index:
				0: on = (x >= 1 and x <= 3 and y <= 1) or (x == 2 and y >= 2)
				1: on = x >= 1 and x <= 3 and y >= 1 and y <= 2
				2: on = y == 1
				3: on = x == 2
				4: on = (x == 1 and y <= 2) or (y == 2 and x >= 1)
				5: on = (x >= 1 and y <= 2) and not (x >= 3 and y >= 1)
				6: on = x == 2 and y == 1
				7: on = not (x == 2 and y == 1)
				8: on = (x == 1 and y == 1) or (x == 2 and y == 2)
				9: on = (x == 2 and y == 1) or (x == 1 and y == 2)
			if on: stone[Vector2i(x,y)] = true
	rebuild()
