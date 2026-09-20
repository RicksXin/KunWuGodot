extends VBoxContainer
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var angle: SpinBox
var slider: HSlider
var billboard: Sprite2D
var camp: Node2D
var map_canvas: Control
var guards: Node3D
var lanterns: Node3D
var building_visual: Node3D
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440,900)
	get_window().size = Vector2i(1440,900)
	var title := Label.new()
	title.text = "百宝库 · 修仙守卫与灯火（独立试验）"
	title.add_theme_font_size_override("font_size",24)
	add_child(title)
	var bar := HBoxContainer.new()
	add_child(bar)
	var label := Label.new()
	label.text = "建筑朝向 Y轴（°）"
	bar.add_child(label)
	angle = SpinBox.new()
	angle.min_value = -180
	angle.max_value = 180
	angle.step = 0.1
	angle.custom_minimum_size.x = 120
	bar.add_child(angle)
	slider = HSlider.new()
	slider.min_value = -180
	slider.max_value = 180
	slider.step = 0.1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(slider)
	for degree in [0,45,90,180]:
		var button := Button.new()
		button.text = "%d°" % degree
		button.pressed.connect(func(): set_yaw(degree))
		bar.add_child(button)
	var guard_motion := CheckButton.new()
	guard_motion.text = "守卫待机"
	guard_motion.button_pressed = true
	guard_motion.toggled.connect(func(enabled: bool): guards.set_playing(enabled))
	bar.add_child(guard_motion)
	var lantern_motion := CheckButton.new()
	lantern_motion.text = "灯笼明暗"
	lantern_motion.button_pressed = true
	lantern_motion.toggled.connect(func(enabled: bool): lanterns.set_flicker_enabled(enabled))
	bar.add_child(lantern_motion)
	var help := Label.new()
	help.text = "左侧：实时3D模型　|　右侧：营地对照。守卫错开呼吸与巡视；灯笼暖光缓缓明暗。两个开关可分别对比。"
	add_child(help)
	var views := HBoxContainer.new()
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(views)
	var closeup := TextureRect.new()
	closeup.custom_minimum_size.x = 470
	closeup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	closeup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	views.add_child(closeup)
	map_canvas = Control.new()
	map_canvas.clip_contents = true
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views.add_child(map_canvas)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,960)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08,0.1,0.13,0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.70,0.72,0.73)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color(0.98,0.95,0.90)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	model = Node3D.new()
	world.add_child(model)
	building_visual = load("res://resources/prototypes/camp_treasury_3d/treasury.glb").instantiate()
	model.add_child(building_visual)
	guards = load("res://scripts/prototypes/camp_treasury_guards.gd").new()
	guards.name = "Guards"
	model.add_child(guards)
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var material: StandardMaterial3D = node.get_active_material(surface).duplicate()
			# Preserve bronze/ceramic roughness and the authored untextured colours.
			# A single restrained tint keeps the candidate close to the camp palette.
			material.albedo_color *= Color(0.73, 0.72, 0.69)
			if material.emission_enabled:
				material.emission = Color(0.7, 0.23, 0.025)
				material.emission_energy_multiplier = 0.45
			node.set_surface_override_material(surface,material)
	lanterns = load("res://scripts/prototypes/camp_treasury_lanterns.gd").new()
	lanterns.name = "Lanterns"
	model.add_child(lanterns)
	lanterns.attach(building_visual)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.8
	world.add_child(camera)
	camera.position = Vector3(10,9.565,10)
	camera.look_at(Vector3(0,1.4,0))
	closeup.texture = viewport.get_texture()
	camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	map_canvas.add_child(camp)
	camp.buildings.get_node("treasury").hide()
	camp.actor.hide()
	camp.overlay.hide()
	camp.set_process(false)
	billboard = Sprite2D.new()
	billboard.texture = viewport.get_texture()
	billboard.centered = false
	billboard.scale = Vector2.ONE*0.24
	billboard.position = camp.buildings.get_node("treasury").position
	camp.buildings.add_child(billboard)
	angle.value_changed.connect(set_yaw)
	slider.value_changed.connect(set_yaw)
	map_canvas.resized.connect(fit_map)
	call_deferred("fit_map")
	# glTF front (-Y Blender) becomes +Z Godot; view from +X/+Z shows entrance.
	set_yaw(0)
	if OS.get_cmdline_user_args().has("--capture-3d"): call_deferred("capture_views")
	if OS.get_cmdline_user_args().has("--capture-guards"): call_deferred("capture_guards")
func fit_map() -> void:
	if not is_instance_valid(camp): return
	var scale_factor := minf(map_canvas.size.x/1200.0,map_canvas.size.y/1050.0)
	camp.scale = Vector2.ONE*scale_factor
	camp.position = Vector2(map_canvas.size.x*0.53,map_canvas.size.y*0.08)
	# Focus on the west court for a readable comparison to the existing buildings.
	camp.position.x += 180*scale_factor
func set_yaw(value: float) -> void:
	if not is_instance_valid(model): return
	model.rotation_degrees.y = value
	angle.set_value_no_signal(value)
	slider.set_value_no_signal(value)
	billboard.offset = -camera.unproject_position(Vector3.ZERO)
func capture_views() -> void:
	for value in [0,90,180,270]:
		set_yaw(value)
		assert(model.basis.y.is_equal_approx(Vector3.UP))
		assert(is_equal_approx(model.rotation_degrees.y,float(value)))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/treasury-3d-%d.png" % value)
		viewport.get_texture().get_image().save_png("res://art/candidates/camp-treasury-3d-v1/preview-%d.png" % value)
	print("PASS treasury 3D: loaded GLB; yaw 0/90/180/270 captured; upright model with fixed camera")
	get_tree().quit()

func capture_guards() -> void:
	set_yaw(0)
	var directory := "res://art/candidates/camp-treasury-3d-v1/guard-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	# One full shared cycle, with separate starting phases; seamless preview loop.
	for frame in range(64):
		guards.seek_preview(float(frame) / 8.0)
		lanterns.seek_preview(float(frame) / 8.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("%s/frame-%03d.png" % [directory, frame])
		if frame == 0:
			get_viewport().get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/treasury-guards-ingame.png")
	# Offline portrait only; the live camp camera retains the normal building view.
	building_visual.hide()
	lanterns.hide()
	guards.guards[1].hide()
	camera.size = 2.35
	camera.position = Vector3(0.58, 1.90, 9.14)
	camera.look_at(Vector3(-1.62, 0.94, 3.14))
	guards.seek_preview(0.0)
	lanterns.seek_preview(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://art/candidates/camp-treasury-3d-v1/guard-v3-closeup.png")
	print("PASS guard capture: 64 frames at 8 FPS; two independently phased skeletons")
	get_tree().quit()
