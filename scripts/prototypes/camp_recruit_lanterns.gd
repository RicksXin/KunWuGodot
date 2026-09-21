extends Node3D
## Shared 24-second scene clock: authored visitors, pennants and local lantern flicker.
var materials: Array[StandardMaterial3D] = []
var lights: Array[OmniLight3D] = []
var playing := true
var seconds := 0.0
var player: AnimationPlayer
var clip: StringName
func attach(building: Node3D) -> void:
	for node in building.find_children("LanternLight_*", "MeshInstance3D", true, false):
		var material := node.get_active_material(0).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		node.set_surface_override_material(0, material)
		materials.append(material)
		var light := OmniLight3D.new()
		light.name = "RecruitLanternLight_%02d" % lights.size()
		# Geometry is model-space; each pane's AABB locates the lantern center.
		light.position = node.transform * node.get_aabb().get_center()
		light.light_color = Color(1.0, 0.48, 0.13)
		light.omni_range = 0.62
		light.shadow_enabled = false
		add_child(light)
		lights.append(light)
	assert(materials.size() == 9)
	for node in building.find_children("*", "AnimationPlayer", true, false):
		for name in node.get_animation_list():
			if name == "RESET": continue
			if node.get_animation(name).length < 23.9: continue
			player = node
			clip = name
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			player.advance(0)
			break
	assert(player != null, "RecruitmentLife animation missing")
	apply_light()
func apply_light() -> void:
	var phase := TAU * seconds / 8.0
	for index in range(materials.size()):
		var pulse := 0.94 + 0.045 * sin(phase * 3.0 + index * 0.83) + 0.015 * sin(phase * 7.0 + index)
		materials[index].emission_energy_multiplier = 1.1 * pulse
		lights[index].light_energy = 0.28 * pulse
func _process(_delta: float) -> void:
	if playing:
		seconds = player.current_animation_position
		apply_light()
func set_playing(enabled: bool) -> void:
	playing = enabled
	if enabled: player.play(clip)
	else: player.pause()
func seek_preview(time: float) -> void:
	seconds = fposmod(time, 24.0)
	player.play(clip)
	player.seek(seconds, true)
	player.pause()
	playing = false
	apply_light()
