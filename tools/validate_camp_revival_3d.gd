extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
func run_check() -> void:
	var demo = load("res://scenes/prototypes/camp_revival_3d_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var cloth: Array[MeshInstance3D] = []
	for node in demo.building_visual.find_children("SoulBanner_*", "MeshInstance3D", true, false):
		cloth.append(node)
	assert(cloth.size() == 8, "Expected eight separately deforming soul banners")
	assert(demo.model.find_children("*", "Skeleton3D", true, false).is_empty(), "No guards may return")
	for item in cloth: assert(item.mesh.get_blend_shape_count() == 4)
	var flames: Array[MeshInstance3D] = []
	for node in demo.building_visual.find_children("SoulFlame_*", "MeshInstance3D", true, false):
		flames.append(node)
	assert(flames.size() == 3)
	for item in flames: assert(item.mesh.get_blend_shape_count() == 4)
	assert(not demo.banners.players.is_empty())
	for player in demo.banners.players:
		assert(is_equal_approx(player.current_animation_length, 8.0))
	demo.banners.seek_preview(0)
	var initial: Array[float] = []
	for item in cloth: initial.append(item.get_blend_shape_value(0))
	var initial_fire: Array[float] = []
	for item in flames: initial_fire.append(item.get_blend_shape_value(0))
	assert(demo.banners.embers.size() == 7)
	var initial_ember: Vector3 = demo.banners.embers[1].position
	var initial_light: float = demo.banners.soul_light.light_energy
	demo.banners.seek_preview(1.6)
	for i in range(cloth.size()):assert(absf(cloth[i].get_blend_shape_value(0)-initial[i]) > 0.1)
	for i in range(flames.size()):assert(absf(flames[i].get_blend_shape_value(0)-initial_fire[i]) > 0.1)
	assert(absf(demo.banners.soul_light.light_energy-initial_light) > 0.01)
	assert(demo.banners.embers[1].position.distance_to(initial_ember) > 0.02)
	demo.banners.set_playing(false)
	for player in demo.banners.players:assert(not player.is_playing())
	var paused_ember: Vector3 = demo.banners.embers[1].position
	var paused_light: float = demo.banners.soul_light.light_energy
	await process_frame
	await process_frame
	assert(is_equal_approx(demo.banners.soul_light.light_energy, paused_light))
	assert(demo.banners.embers[1].position.is_equal_approx(paused_ember))
	demo.banners.set_playing(true)
	for player in demo.banners.players:assert(player.is_playing())
	demo.banners.seek_preview(8.0)
	for i in range(cloth.size()):assert(is_equal_approx(cloth[i].get_blend_shape_value(0),initial[i]))
	for i in range(flames.size()):assert(is_equal_approx(flames[i].get_blend_shape_value(0),initial_fire[i]))
	assert(is_equal_approx(demo.banners.soul_light.light_energy,initial_light))
	assert(demo.banners.embers[1].position.is_equal_approx(initial_ember))
	for step in range(65):
		demo.banners.seek_preview(step / 8.0)
		assert(demo.banners.soul_light.light_energy > 0.25)
		for material in demo.banners.flame_materials: assert(float(material.get_shader_parameter("pulse")) > 0.9)
	demo.set_yaw(90)
	assert(demo.model.basis.y.is_equal_approx(Vector3.UP))
	assert(is_equal_approx(demo.model.rotation_degrees.y,90.0))
	print("PASS revival: 8 cloth banners + 3 deforming flames; fixed-cycle morph changes; positive blue light pulse; shared pause/resume; 8s loop; upright yaw; no guards")
	demo.queue_free()
	await process_frame
	quit()
