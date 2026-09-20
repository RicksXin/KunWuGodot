extends SceneTree
## Offline blueprint integration check only. Never loaded by the game or reads profile data.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var atlas_image := Image.load_from_file(ProjectSettings.globalize_path("res://Docs/Artifacts/camp-tilemap-exploration/cliff-kit/blueprint-atlas.png"))
	assert(atlas_image != null)
	var texture := ImageTexture.create_from_image(atlas_image)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(144,128)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(128,64)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tiles.add_source(atlas,0)
	for y in range(2):
		for x in range(4):
			var coords := Vector2i(x,y)
			atlas.create_tile(coords)
			atlas.get_tile_data(coords,0).texture_origin = Vector2i(0,-24)
	var rendered: Array[SubViewport] = []
	for i in range(2):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256,256)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		rendered.append(viewport)
	for row in range(2):
		for col in range(4):
			var layer := TileMapLayer.new()
			layer.tile_set = tiles
			layer.position = Vector2(128,96)
			layer.set_cell(Vector2i.ZERO,0,Vector2i(col,row))
			rendered[0].add_child(layer)
			var reference := Sprite2D.new()
			reference.texture = texture
			reference.region_enabled = true
			reference.region_rect = Rect2(col*144,row*128,144,128)
			reference.centered = false
			reference.position = layer.position+layer.map_to_local(Vector2i.ZERO)-Vector2(72,40)
			rendered[1].add_child(reference)
			await process_frame
			await RenderingServer.frame_post_draw
			var actual := rendered[0].get_texture().get_image()
			var expected := rendered[1].get_texture().get_image()
			if actual.get_data() != expected.get_data():
				push_error("TileMap atlas anchor mismatch at %s" % Vector2i(col,row))
				quit(1)
				return
			layer.free()
			reference.free()
	print("PASS: all 8 blueprint tiles match Sprite anchor (72,40), Godot texture_origin=(0,-24)")
	quit()
