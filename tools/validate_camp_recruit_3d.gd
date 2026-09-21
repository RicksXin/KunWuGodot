extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
func run_check() -> void:
	var demo = load("res://scenes/prototypes/camp_recruit_3d_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	assert(demo.building_visual != null)
	assert(demo.building_visual.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(demo.banners.materials.size() == 9)
	assert(demo.banners.lights.size() == 9)
	assert(is_equal_approx(demo.banners.player.current_animation_length, 24.0))
	var visitor: Node3D = demo.building_visual.find_child("ArrivingCultivator", true, false)
	assert(visitor != null)
	assert(demo.building_visual.find_child("WaitingCultivator", true, false) != null)
	assert(demo.building_visual.find_child("RecruitReceptionist", true, false) != null)
	var pennants: Array[Node] = demo.building_visual.find_children("RecruitWindBanner_*", "MeshInstance3D", true, false)
	assert(pennants.size() == 2)
	demo.banners.seek_preview(0.0)
	var initial_position: Vector3 = visitor.position
	var initial_flag: float = pennants[0].get_blend_shape_value(0)
	demo.banners.seek_preview(3.0)
	assert(visitor.position.y > initial_position.y + 0.4)
	demo.banners.seek_preview(7.0)
	assert(visitor.position.z < 0.0, "Visitor must enter the hall interior")
	demo.banners.seek_preview(19.0)
	assert(visitor.position.distance_to(initial_position) < 0.002, "Visitor must return outside")
	demo.banners.seek_preview(1.0)
	assert(absf(pennants[0].get_blend_shape_value(0)-initial_flag) > 0.1)
	var paused_position: Vector3 = visitor.position
	await process_frame
	await process_frame
	assert(visitor.position.is_equal_approx(paused_position))
	demo.banners.seek_preview(24.0)
	assert(visitor.position.is_equal_approx(initial_position))
	assert(not demo.camp.buildings.get_node("recruit").visible)
	demo.banners.seek_preview(0.0)
	var initial: float = demo.banners.lights[0].light_energy
	demo.banners.seek_preview(0.6)
	assert(absf(demo.banners.lights[0].light_energy - initial) > 0.005)
	var paused: float = demo.banners.lights[0].light_energy
	await process_frame
	await process_frame
	assert(is_equal_approx(demo.banners.lights[0].light_energy, paused))
	demo.banners.seek_preview(24.0)
	assert(is_equal_approx(demo.banners.lights[0].light_energy, initial))
	demo.banners.set_playing(true)
	assert(demo.banners.playing)
	for angle in [0,90,180,270]:
		demo.set_yaw(angle)
		assert(demo.model.basis.y.is_equal_approx(Vector3.UP))
	for step in range(65):
		demo.banners.seek_preview(step / 8.0)
		for light in demo.banners.lights:assert(light.light_energy > 0.2 and light.light_energy < 0.32)
	print("PASS recruit: GLB loaded; 3 cultivators; enter/interior/exit; rising stairs; 2 wind banners; 9 lights; shared pause/resume/24s loop; 4-way rotation; preview only")
	demo.queue_free()
	await process_frame
	quit()
