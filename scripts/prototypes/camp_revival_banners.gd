@tool
extends Node3D
## Authored banner/fire morphs and gentle blue altar illumination share one clock.
var players: Array[AnimationPlayer] = []
var clips: Array[StringName] = []
var playing := true
var flame_materials: Array[ShaderMaterial] = []
var embers: Array[MeshInstance3D] = []
var soul_light: OmniLight3D

func attach(building: Node3D) -> void:
	for node in building.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for name in player.get_animation_list():
			if name == "RESET": continue
			var animation := player.get_animation(name)
			if animation.length < 7.9: continue
			animation.loop_mode = Animation.LOOP_LINEAR
			players.append(player)
			clips.append(name)
			player.play(name)
			player.advance(0)
			break
	assert(not players.is_empty(), "Revival GLB must contain its authored 8-second animation")
	for node in building.find_children("SoulFlame_*", "MeshInstance3D", true, false):
		var flame := node as MeshInstance3D
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/prototypes/revival_soul_fire.gdshader")
		material.set_shader_parameter("tongue", float(flame_materials.size()))
		flame.set_surface_override_material(0, material)
		flame_materials.append(material)
	assert(flame_materials.size() == 3, "Expected three independently deforming soul flames")
	soul_light = OmniLight3D.new()
	soul_light.name = "BlueSoulLight"
	soul_light.position = Vector3(0, 1.22, 1.10)
	soul_light.light_color = Color(0.06, 0.65, 1.0)
	soul_light.omni_range = 1.2
	soul_light.shadow_enabled = false
	add_child(soul_light)
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(0.14, 0.68, 1.0)
	ember_material.emission_enabled = true
	ember_material.emission = Color(0.06, 0.46, 1.0)
	ember_material.emission_energy_multiplier = 1.2
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.009
	ember_mesh.height = 0.026
	ember_mesh.radial_segments = 8
	ember_mesh.rings = 4
	for index in range(7):
		var ember := MeshInstance3D.new()
		ember.name = "SoulEmber_%02d" % index
		ember.mesh = ember_mesh
		ember.material_override = ember_material
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ember)
		embers.append(ember)
	apply_fire_light(0.0)

func apply_fire_light(seconds: float) -> void:
	var phase := TAU * seconds / 8.0
	for index in range(flame_materials.size()):
		var pulse := 0.84 + 0.12 * sin(phase * 4 + index * 1.1) + 0.04 * sin(phase * 9 + index * 0.7)
		flame_materials[index].set_shader_parameter("pulse", 1.4 * pulse)
		flame_materials[index].set_shader_parameter("phase", phase)
	for index in range(embers.size()):
		var age := fposmod(seconds / 2.0 + index / 7.0, 1.0)
		var angle := phase * 2.0 + index * 2.4
		embers[index].position = Vector3(sin(angle) * (0.035 + age * 0.085), 1.10 + age * 0.61, 1.10 + cos(angle) * 0.055)
		embers[index].scale = Vector3.ONE * sin(age * PI) * 0.85
	soul_light.light_energy = 0.40 + 0.08 * sin(phase * 4) + 0.025 * sin(phase * 9)

func _process(_delta: float) -> void:
	if not players.is_empty():
		apply_fire_light(players[0].current_animation_position)

func set_playing(enabled: bool) -> void:
	playing = enabled
	for index in range(players.size()):
		if enabled: players[index].play(clips[index])
		else: players[index].pause()

func seek_preview(seconds: float) -> void:
	for index in range(players.size()):
		var player := players[index]
		player.play(clips[index])
		player.seek(fposmod(seconds, 8.0), true)
		player.pause()
	apply_fire_light(fposmod(seconds, 8.0))
