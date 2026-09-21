extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(1440,900)
	root.size = Vector2i(1440,900)
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	# Retain the 2D-image interaction fixture; live 3D has its own validation.
	for item in panel.model.data.buildings: item.erase("model_3d")
	panel.canvas.refresh()
	panel.canvas.fit()
	panel.select(1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/camp-layout-editor-ui.png")
	# Exercise UI handlers without writing the production JSON.
	var before: Dictionary = panel.model.data.duplicate(true)
	var canvas = panel.canvas
	var sprite: Sprite2D = canvas.sprites[1]
	var click: Vector2 = canvas.pan+(sprite.transform*(Vector2(580,450)+sprite.offset))*canvas.zoom
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = click
	press.pressed = true
	canvas._gui_input(press)
	assert(canvas.drag and canvas.active==1)
	var motion := InputEventMouseMotion.new()
	motion.position = click+Vector2(0,1280)*canvas.zoom
	canvas._gui_input(motion)
	press.position = motion.position
	press.pressed = false
	canvas._gui_input(press)
	assert(not canvas.drag)
	assert(panel.model.data.buildings[1].origin[0]==before.buildings[1].origin[0]+20)
	assert(panel.model.data.buildings[1].origin[1]==before.buildings[1].origin[1]+20)
	assert(not panel.save_button.disabled)
	assert(panel.model.dirty)
	panel.model.undo()
	panel.sync()
	panel.report()
	assert(panel.model.data==before)
	assert(panel.model.validate().is_empty())
	var previous_zoom: float = canvas.zoom
	var gesture := InputEventMagnifyGesture.new()
	gesture.factor = 1.5
	gesture.position = canvas.size*0.5
	canvas._gui_input(gesture)
	assert(is_equal_approx(canvas.zoom,previous_zoom*1.5))
	canvas.zoom_at(1.25,canvas.size*0.5)
	assert(canvas.zoom>previous_zoom*1.5)
	panel.mirror.button_pressed = not panel.mirror.button_pressed
	assert(panel.model.data.buildings[1].mirror_x==panel.mirror.button_pressed)
	panel.model.undo()
	panel.select(3)
	panel.angle_field.value = 17.5
	assert(is_equal_approx(canvas.sprites[3].rotation_degrees,17.5))
	var anchor: Array = panel.model.data.buildings[3].door_anchor
	var pivot: Vector2 = canvas.sprites[3].transform*(Vector2(anchor[0],anchor[1])+canvas.sprites[3].offset)
	assert(pivot.is_equal_approx(canvas.sprites[3].position))
	var runtime = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	runtime.definition_override = panel.model.data.duplicate(true)
	root.add_child(runtime)
	assert(runtime.buildings.get_node("recruit").transform.is_equal_approx(canvas.sprites[3].transform))
	runtime.queue_free()
	panel.change_view(0)
	assert("camp_west_buildings_v4/recruit" in panel.model.data.buildings[3].texture)
	panel.change_view(1)
	assert("recruit-rear" in panel.model.data.buildings[3].texture)
	assert(Vector2(panel.model.data.buildings[3].visual_offset[0],panel.model.data.buildings[3].visual_offset[1]).length()<0.001)
	panel.angle_field.value = 0.0
	assert(is_zero_approx(canvas.sprites[3].rotation_degrees))
	panel.model.undo()
	panel.sync()
	assert(is_equal_approx(canvas.sprites[3].rotation_degrees,17.5))
	print("PASS rotation 0.1-degree input, pivot, runtime match, reset/undo; camp editor: unrestricted drag, undo, pinch/buttons zoom, mirror, front/back switch")
	quit()
