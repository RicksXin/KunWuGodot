extends SceneTree
## Generates only the explicitly named experiment. Existing work requires --rebuild-camp-lab.
const OUTPUT := "res://scenes/prototypes/camp_tilemap_lab.tscn"

func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT) and not OS.get_cmdline_user_args().has("--rebuild-camp-lab"):
		push_error("Lab already exists. Preserve editor changes; explicit --rebuild-camp-lab required.")
		quit(1)
		return
	var image := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	var colors := [Color("526553"), Color("858b7a"), Color("84745a"), Color("335e68")]
	for tile in range(4):
		for y in range(32):
			for x in range(32):
				var color: Color = colors[tile]
				var noise := ((x * 17 + y * 37 + x * y * 3) % 23) / 230.0 - 0.05
				color = color.lightened(noise) if noise > 0 else color.darkened(-noise)
				if tile == 1 and (y % 16 == 0 or (x + (16 if y >= 16 else 0)) % 32 == 0): color = Color("59675e")
				if tile == 0 and (x * 11 + y * 7) % 67 == 0: color = Color("718368")
				image.set_pixel(tile * 32 + x, y, color)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(32, 32)
	for tile in range(4): atlas.create_tile(Vector2i(tile, 0))
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_source(atlas, 0)
	ResourceSaver.save(tiles, "res://resources/prototypes/camp_lab_tileset.tres")
	var root := Control.new()
	root.name = "CampTileMapLab"
	root.set_script(load("res://scripts/prototypes/camp_tilemap_lab.gd"))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Theme.new()
	root.theme.default_font = load("res://assets/fonts/NotoSansSC.ttf")
	var world := Node2D.new()
	world.name = "World"
	world.position = Vector2(-135.5, 44)
	world.scale = Vector2(0.85, 0.85)
	attach(root, world, root)
	var layers: Array[TileMapLayer] = []
	for layer_name in ["Ground", "Paths", "Water"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tiles
		attach(world, layer, root)
		layers.append(layer)
	for y in range(12):
		for x in range(40):
			var cell := Vector2i(x, y)
			layers[0].set_cell(cell, 0, Vector2i.ZERO)
			if (y >= 6 and y <= 7) or (x >= 12 and x <= 14 and y >= 3 and y <= 8):
				layers[1].set_cell(cell, 0, Vector2i(1, 0))
			elif y >= 4 and y <= 5 and x >= 19 and x <= 23:
				layers[1].set_cell(cell, 0, Vector2i(2, 0))
			if Vector2(x - 30, (y - 8) * 2).length() < 4.5:
				layers[1].erase_cell(cell)
				layers[2].set_cell(cell, 0, Vector2i(3, 0))
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform bool animated = true;\nvarying vec2 local_point;\nvoid vertex() { local_point = VERTEX; }\nvoid fragment() { vec4 base = texture(TEXTURE, UV); float t = animated ? TIME : 0.0; float ripple = sin(local_point.y * 0.35 + sin(local_point.x * 0.08 + t) * 1.5 - t * 2.0); base.rgb += vec3(0.035, 0.065, 0.065) * smoothstep(0.8, 1.0, ripple); COLOR = base; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	layers[2].material = material
	var buildings := Node2D.new()
	buildings.name = "Buildings"
	attach(world, buildings, root)
	# Standalone layout proposals, not formal camp coordinates or product data.
	for info in [
		["Council", "yi_shi_dian", Vector2(430, 115), Vector2(247, 165)],
		["Recruit", "zhao_xian_tai", Vector2(170, 180), Vector2(247, 165)],
		["Forge", "lian_qi_fang", Vector2(720, 170), Vector2(247, 165)],
		["Garden", "ling_pu", Vector2(1030, 130), Vector2(247, 165)],
		["Portal", "portal", Vector2(430, 270), Vector2(206, 139)]]:
		var sprite := Sprite2D.new()
		sprite.name = info[0]
		var filename: String = "env_camp_portal" if info[1] == "portal" else "env_camp_building_" + info[1]
		sprite.texture = load("res://assets/camp/buildings/" + filename + ".png")
		sprite.position = info[2]
		sprite.scale = info[3] / sprite.texture.get_size()
		attach(buildings, sprite, root)
	var effects := Node2D.new()
	effects.name = "Effects"
	effects.set_script(load("res://scripts/prototypes/camp_tilemap_effects.gd"))
	attach(world, effects, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var result := ResourceSaver.save(packed, OUTPUT)
	root.free()
	print("Camp TileMap lab saved: ", result)
	quit(result)

func attach(parent: Node, child: Node, scene_root: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root
