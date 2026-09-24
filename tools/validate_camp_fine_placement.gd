extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.canvas.fit()
	assert(not panel.canvas.snap_to_grid)
	var index := -1
	for i in range(panel.model.data.buildings.size()):
		if panel.model.data.buildings[i].id == "forge": index = i
	panel.select(index)
	var original: Dictionary = panel.model.data.duplicate(true)
	var before: Vector2 = panel.canvas.sprites[index].position
	# Exercise a real sub-grid drag through alpha picking at multiple zooms.
	for zoom in [0.5,2.0]:
		panel.canvas.zoom = zoom
		var sprite: Sprite2D = panel.canvas.sprites[index]
		var click: Vector2 = panel.canvas.pan+(sprite.transform*(Vector2(900,800)+sprite.offset))*zoom
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = click
		press.pressed = true
		panel.canvas._gui_input(press)
		assert(panel.canvas.drag and panel.canvas.active == index)
		var motion := InputEventMouseMotion.new()
		motion.position = click+Vector2(3,-2)*zoom
		panel.canvas._gui_input(motion)
		press.position = motion.position
		press.pressed = false
		panel.canvas._gui_input(press)
		assert(panel.canvas.sprites[index].position.is_equal_approx(before+Vector2(3,-2)))
		assert(panel.model.data.buildings[index].origin == original.buildings[index].origin)
		assert(panel.model.data.buildings[index].door == original.buildings[index].door)
		panel.model.undo()
		panel.sync()
		assert(panel.model.data == original)
	panel.offset_x_field.value = 0.1
	panel.offset_y_field.value = -0.2
	assert(panel.canvas.sprites[index].position.is_equal_approx(before+Vector2(0.1,-0.2)))
	var path := "user://camp-fine-placement-test.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(panel.model.disk_text)
	file.close()
	assert(panel.model.save(path).is_empty())
	var reloaded = load("res://addons/camp_layout_editor/model.gd").new()
	assert(reloaded.load_file(path).is_empty())
	assert(is_equal_approx(reloaded.data.buildings[index].visual_offset[0],0.1))
	assert(is_equal_approx(reloaded.data.buildings[index].visual_offset[1],-0.2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	camp.definition_override = reloaded.data
	root.add_child(camp)
	assert(camp.buildings.get_node("forge").position.is_equal_approx(panel.canvas.sprites[index].position))
	panel.set_visual_offset(index,Vector2.ZERO)
	assert(panel.canvas.sprites[index].position.is_equal_approx(before))
	camp.visible = false
	if DisplayServer.get_name() != "headless":
		panel.canvas.fit()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-fine-placement.png")
	print("PASS fine placement: 1px drag at two zooms, unchanged navigation, undo, 0.1px input, save/reload, runtime parity, reset")
	quit()
