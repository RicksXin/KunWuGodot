extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func bone_pose(skeleton: Skeleton3D, bone_name: String) -> Transform3D:
	var bone_index := skeleton.find_bone(bone_name)
	assert(bone_index >= 0, "Missing guard bone: " + bone_name)
	return skeleton.get_bone_global_pose(bone_index)

func validate() -> void:
	var building := Node3D.new()
	root.add_child(building)
	var guards = load("res://scripts/prototypes/camp_treasury_guards.gd").new()
	building.add_child(guards)
	await process_frame
	assert(guards.guards.size() == 2)
	assert(guards.players.size() == 2)
	assert(guards.skeletons.size() == 2)
	for player in guards.players:
		assert(is_equal_approx(player.get_animation(player.current_animation).length, 8.0))
	guards.seek_preview(0.0)
	await process_frame
	var feet: Array[Transform3D] = []
	var head_start: Array[Transform3D] = []
	for skeleton in guards.skeletons:
		assert(skeleton.get_bone_count() == 18)
		feet.append(bone_pose(skeleton, "FootL"))
		feet.append(bone_pose(skeleton, "FootR"))
		head_start.append(bone_pose(skeleton, "Head"))
	for seconds in [1.0, 2.2, 4.0, 6.0, 8.0, 12.0, 16.0]:
		guards.seek_preview(seconds)
		await process_frame
		for index in range(2):
			assert(feet[index * 2].is_equal_approx(bone_pose(guards.skeletons[index], "FootL")), "Left foot drift")
			assert(feet[index * 2 + 1].is_equal_approx(bone_pose(guards.skeletons[index], "FootR")), "Right foot drift")
	guards.seek_preview(2.2)
	await process_frame
	for index in range(2):
		assert(not head_start[index].is_equal_approx(bone_pose(guards.skeletons[index], "Head")), "Head animation is static")
	assert(not bone_pose(guards.skeletons[0], "Head").is_equal_approx(bone_pose(guards.skeletons[1], "Head")), "Guards unexpectedly in sync")
	# Test source-clip continuity independently from the per-instance playback rate.
	for index in range(2):
		var player: AnimationPlayer = guards.players[index]
		var clip: Animation = player.get_animation(guards.clips[index])
		clip.loop_mode = Animation.LOOP_NONE
		player.play(guards.clips[index]); player.seek(0.0, true); player.pause()
		await process_frame
		var start_poses: Array[Transform3D] = []
		for bone_index in range(18):
			start_poses.append(guards.skeletons[index].get_bone_global_pose(bone_index))
		player.seek(clip.length, true)
		await process_frame
		for bone_index in range(18):
			assert(start_poses[bone_index].is_equal_approx(guards.skeletons[index].get_bone_global_pose(bone_index)), "Idle loop seam")
		clip.loop_mode = Animation.LOOP_LINEAR
	guards.seek_preview(1.0)
	var paused_position: float = guards.players[0].current_animation_position
	await create_timer(0.10).timeout
	assert(is_equal_approx(paused_position, guards.players[0].current_animation_position), "Pause failed")
	guards.set_playing(true)
	await create_timer(0.10).timeout
	assert(not is_equal_approx(paused_position, guards.players[0].current_animation_position), "Resume failed")
	building.rotation_degrees.y = 90.0
	await process_frame
	for guard in guards.guards:
		assert(guard.global_basis.y.is_equal_approx(Vector3.UP))
		assert(guard.global_position.is_equal_approx(building.global_transform * guard.position))
	var visual := load("res://resources/prototypes/camp_treasury_3d/treasury.glb").instantiate() as Node3D
	building.add_child(visual)
	var steady_materials: Array[StandardMaterial3D] = []
	var steady_energies: Array[float] = []
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material.emission_enabled and not "LanternGlass" in material.resource_name:
				steady_materials.append(material)
				steady_energies.append(material.emission_energy_multiplier)
	assert(not steady_materials.is_empty(), "Expected steady window glass")
	var lanterns = load("res://scripts/prototypes/camp_treasury_lanterns.gd").new()
	building.add_child(lanterns)
	lanterns.attach(visual)
	assert(lanterns.panes.size() == 2 and lanterns.lights.size() == 2)
	assert(lanterns.panes[0] != lanterns.panes[1])
	var minima: Array[float] = [INF, INF]
	var maxima: Array[float] = [0.0, 0.0]
	for sample in range(65):
		lanterns.seek_preview(float(sample) / 8.0)
		for index in range(2):
			var energy: float = lanterns.lights[index].light_energy
			assert(energy > 0.4 and energy < 1.31, "Lamp should breathe, never flash off")
			minima[index] = minf(minima[index], energy)
			maxima[index] = maxf(maxima[index], energy)
	for index in range(2):
		assert(maxima[index] - minima[index] > 0.30)
		assert(is_equal_approx(lanterns.brightness(index, 0.0), lanterns.brightness(index, 8.0)))
	assert(not is_equal_approx(lanterns.brightness(0, 0.0), lanterns.brightness(1, 0.0)))
	for index in range(steady_materials.size()):
		assert(is_equal_approx(steady_materials[index].emission_energy_multiplier, steady_energies[index]), "Window glass must remain steady")
	lanterns.set_flicker_enabled(false)
	lanterns.seek_preview(0.0)
	var steady_light: float = lanterns.lights[0].light_energy
	lanterns.seek_preview(1.7)
	assert(is_equal_approx(steady_light, lanterns.lights[0].light_energy))
	print("PASS treasury guards: two 18-bone instances; 8s loop; asynchronous head motion; planted feet; pause/resume; follow yaw")
	print("PASS lanterns: independent panes and lights; smooth positive pulse; loop continuity; steady windows; steady-light toggle")
	quit()
