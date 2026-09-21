@tool
extends Node3D
## A single seekable clock drives imported craft animations and local smoke/water/fire.
var player: AnimationPlayer
var clip: StringName
var playing := true
var seconds := 0.0
var kind := ""
var building: Node3D
var smoke: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var droplets: Array[MeshInstance3D] = []
var lantern_materials: Array[StandardMaterial3D] = []
var lantern_lights: Array[OmniLight3D] = []
var coal_materials: Array[StandardMaterial3D] = []
var water_materials: Array[ShaderMaterial] = []
var smoke_origin := Vector3.ZERO
var strike_origin := Vector3.ZERO
var fall_origin := Vector3.ZERO
var fire: OmniLight3D
var strike: OmniLight3D
func find_marker(prefix: String) -> Node3D:
	return building.find_child(prefix+"*", true, false) as Node3D
func local_marker(prefix: String) -> Vector3:
	return building.transform * find_marker(prefix).position
func light_at(pos: Vector3, color: Color, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.omni_range = radius
	light.shadow_enabled = false
	add_child(light)
	return light
func dot_mesh(color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	node.material_override = mat
	add_child(node)
	return node
func attach(source: Node3D) -> void:
	building = source
	kind = "forge" if find_marker("SmokeSource") != null else ("garden" if find_marker("Waterwheel") != null else "market")
	for node in building.find_children("*", "AnimationPlayer", true, false):
		for name in node.get_animation_list():
			if name == "RESET": continue
			player = node
			clip = name
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			player.advance(0)
	assert(player != null, "Craft building animation missing")
	for node in building.find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(surface)
			if mat is StandardMaterial3D and "living coals" in mat.resource_name:
				var own = mat.duplicate()
				node.set_surface_override_material(surface,own)
				coal_materials.append(own)
		if str(node.name).begins_with("LanternLight_"):
			var mat = node.get_active_material(0).duplicate()
			node.set_surface_override_material(0,mat)
			lantern_materials.append(mat)
			lantern_lights.append(light_at(node.transform*node.get_aabb().get_center(),Color(1,.40,.08),.85))
		if str(node.name).begins_with("FlowingWater"):
			var water := ShaderMaterial.new()
			water.shader = preload("res://shaders/prototypes/craft_water.gdshader")
			node.material_override = water
			water_materials.append(water)
	if kind == "forge":
		smoke_origin = local_marker("SmokeSource")
		strike_origin = local_marker("StrikeSource")
		fire = light_at(local_marker("ForgeGlow"),Color(1,.19,.025),1.5)
		strike = light_at(strike_origin,Color(1,.55,.13),1.0)
		for i in range(12):
			var puff := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			puff.mesh = quad
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/prototypes/craft_smoke.gdshader")
			puff.material_override = mat
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(puff)
			smoke.append(puff)
		for i in range(9): sparks.append(dot_mesh(Color(1,.38,.045),.017))
	if kind == "garden":
		fall_origin = local_marker("WaterFallSource")
		for i in range(20): droplets.append(dot_mesh(Color(.18,.40,.40),.022))
	apply_effects()
func apply_effects() -> void:
	for i in range(lantern_materials.size()):
		var pulse := .92+.055*sin(seconds*TAU/4+i)+.025*sin(seconds*TAU*7/16+i)
		lantern_materials[i].emission_energy_multiplier = pulse
		lantern_lights[i].light_energy = .22*pulse
	if kind == "forge":
		var phase := fposmod(seconds,2.0)
		var flash := exp(-pow((phase-1.0)/.055,2))
		fire.light_energy = .55+.09*sin(seconds*TAU*13/16)+.05*sin(seconds*TAU*23/16)
		strike.light_energy = flash*1.8
		for mat in coal_materials: mat.emission_energy_multiplier = 1.4+fire.light_energy*.5
		for i in range(smoke.size()):
			var t := fposmod(seconds/4.0+i/12.0,1.0)
			smoke[i].position = smoke_origin+Vector3(.40*t*t+.08*sin(TAU*t+i),1.8*t,.12*sin(TAU*t+i))
			smoke[i].scale = Vector3.ONE*(.24+.70*t)
			smoke[i].material_override.set_shader_parameter("opacity",sin(PI*t)*.32)
			smoke[i].material_override.set_shader_parameter("drift",t*.5+i)
		var age := fposmod(seconds-1.0,2.0)
		for i in range(sparks.size()):
			var a := i*2.399
			sparks[i].visible = age < .42
			sparks[i].position = strike_origin+Vector3(cos(a)*age*.9,age*(1.1+i*.04)-3*age*age,sin(a)*age*.65)
			sparks[i].scale = Vector3.ONE*maxf(.1,1.0-age*2.0)
	if kind == "garden":
		for water in water_materials: water.set_shader_parameter("flow_time",seconds)
		for i in range(droplets.size()):
			var t := fposmod(seconds*2+i/20.0,1.0)
			droplets[i].position = fall_origin+Vector3(.10*sin(i*2.4),-1.75*t*t,.08+0.30*t)
			droplets[i].scale = Vector3(.65,1.8,.65)
func _process(_delta: float) -> void:
	if not playing: return
	seconds = player.current_animation_position
	apply_effects()
func seek_preview(time: float) -> void:
	seconds = fposmod(time,16.0)
	player.play(clip)
	player.seek(seconds,true)
	player.pause()
	playing = false
	apply_effects()
func set_playing(enabled: bool) -> void:
	playing = enabled
	if enabled:
		player.play(clip)
		player.seek(seconds,true)
	else: player.pause()
