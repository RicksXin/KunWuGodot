extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(1440,900)
	root.size = Vector2i(1440,900)
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.canvas.fit()
	panel.canvas.snap_to_grid = true
	var index := -1
	for i in range(panel.model.data.buildings.size()):
		if panel.model.data.buildings[i].id == "forge": index = i
	assert(index >= 0)
	panel.select(index)
	var sprite = panel.canvas.sprites[index]
	assert(sprite.player.sprite_frames.get_frame_count("default") == 22)
	assert(sprite.texture.get_size() == Vector2(1632,1216))
	var first: int = sprite.player.frame
	await create_timer(0.3).timeout
	assert(sprite.player.frame != first)
	sprite.player.set_frame_and_progress(21,0.0)
	await create_timer(0.16).timeout
	assert(sprite.player.frame < 3)
	var item: Dictionary = panel.model.data.buildings[index]
	var original: Dictionary = panel.model.data.duplicate(true)
	panel.rotate_building(17.5)
	panel.mirror.button_pressed = true
	sprite = panel.canvas.sprites[index]
	var anchor := Vector2(item.door_anchor[0],item.door_anchor[1])
	assert((sprite.transform*(anchor+sprite.offset)).is_equal_approx(sprite.position))
	assert(sprite.scale.x < 0)
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	camp.definition_override = panel.model.data.duplicate(true)
	root.add_child(camp)
	var runtime = camp.buildings.get_node("forge")
	assert(runtime.transform.is_equal_approx(sprite.transform))
	assert(runtime.player.is_playing())
	await create_timer(0.2).timeout
	camp.queue_free()
	# Picking and dragging use the visible atlas frame, including transparent margins.
	panel.model.data = original.duplicate(true)
	panel.sync()
	sprite = panel.canvas.sprites[index]
	var opaque: Vector2 = Vector2(900,800)+sprite.offset
	assert(sprite.is_pixel_opaque(opaque))
	assert(not sprite.is_pixel_opaque(Vector2(0,0)+sprite.offset))
	var click: Vector2 = panel.canvas.pan+(sprite.transform*opaque)*panel.canvas.zoom
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = click
	press.pressed = true
	panel.canvas._gui_input(press)
	assert(panel.canvas.drag and panel.canvas.active == index)
	var motion := InputEventMouseMotion.new()
	motion.position = click+Vector2(128,64)*panel.canvas.zoom
	panel.canvas._gui_input(motion)
	press.position = motion.position
	press.pressed = false
	panel.canvas._gui_input(press)
	assert(panel.model.data.buildings[index].door[0] == original.buildings[index].door[0]+2)
	panel.model.undo()
	assert(panel.model.data == original)
	panel.model.dirty = false
	panel.sync()
	panel.canvas.show_grid = false
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-forge-sequence-editor.png")
	print("PASS forge sequence: 22 frames, playback, loop, anchor, mirror, rotation, editor/runtime parity, alpha picking, drag, undo")
	panel.queue_free()
	await process_frame
	quit()
