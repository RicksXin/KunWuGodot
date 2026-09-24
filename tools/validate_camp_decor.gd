extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	var original: Dictionary = panel.model.data.duplicate(true)
	var building_count: int = original.buildings.size()
	assert(building_count == 7 and original.decorations.size() >= 25)
	var prop_types := {}
	for item in original.decorations: prop_types[item.prop] = true
	for required in ["formation_banner","formation_lamp","soul_shrine"]: assert(prop_types.has(required))
	assert(panel.choice.item_count == panel.model.items().size())
	assert(panel.canvas.sprites.size() == panel.model.items().size())
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	var shared: Texture2D
	for i in range(original.decorations.size()):
		var item: Dictionary = original.decorations[i]
		var visual: Sprite2D = panel.canvas.sprites[building_count+i]
		assert(visual.z_index >= 0)
		var parent: Node2D = camp.ground_decorations if item.ground_decal else camp.decorations
		var live: Sprite2D = parent.get_node(item.id)
		assert(live.transform.is_equal_approx(visual.transform))
		assert(visual.texture is AtlasTexture)
		if shared == null: shared = visual.texture.atlas
		assert(visual.texture.atlas == shared and live.texture.atlas == shared)
		var img := visual.texture.get_image()
		assert(img.get_pixel(0,0).a == 0.0)
		var opaque := false
		for y in range(0,img.get_height(),5):
			for x in range(0,img.get_width(),5):
				if img.get_pixel(x,y).a > 0.9:
					assert(visual.is_pixel_opaque(Vector2(x,y)+visual.offset))
					opaque = true
					break
			if opaque: break
		assert(opaque)
		if item.prop in ["lantern","formation_lamp","soul_shrine"]:
			assert(visual.material is ShaderMaterial)
			assert(visual.material.get_shader_parameter("spirit_light") == (item.prop != "lantern"))
	var index := building_count+3
	panel.select(index)
	var before: Vector2 = panel.canvas.sprites[index].position
	panel.nudge(index,Vector2(3.2,-1.4))
	assert(panel.canvas.sprites[index].position.is_equal_approx(before+Vector2(3.2,-1.4)))
	assert(panel.model.data.buildings == original.buildings)
	panel.model.undo()
	panel.sync()
	assert(panel.model.data == original)
	panel.move(index,Vector2i(1,0))
	assert(panel.model.data.decorations[3].origin[0] == original.decorations[3].origin[0]+1)
	panel.model.undo()
	panel.sync()
	panel.mirror.button_pressed = not panel.mirror.button_pressed
	assert(panel.canvas.sprites[index].position.is_equal_approx(before))
	panel.model.undo()
	panel.sync()
	assert(panel.model.data == original)
	# Persistence is tested in a disposable file, never the user's layout or profile.
	var temp := "user://camp-decor-validation.json"
	var f := FileAccess.open(temp,FileAccess.WRITE)
	f.store_string(panel.model.disk_text)
	f.close()
	assert(panel.model.save(temp).is_empty())
	var roundtrip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(temp))
	assert(roundtrip == original)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	for i in range(building_count):
		assert(panel.canvas.sprites[i].player.is_playing())
	# Visual props do not change existing navigation; NPC avoidance comes separately.
	var bare = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	bare.definition_override = original.duplicate(true)
	bare.definition_override.erase("decorations")
	root.add_child(bare)
	assert(bare.ids == camp.ids and bare.blocked == camp.blocked)
	assert(bare.graph.get_point_count() == camp.graph.get_point_count())
	print("PASS %d props / one shared atlas / alpha picking / editor-runtime transforms / pixel and grid placement / mirror / undo / JSON roundtrip / seven animations / unchanged navigation" % original.decorations.size())
	quit()
