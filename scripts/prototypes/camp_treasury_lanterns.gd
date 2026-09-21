@tool
extends Node3D
## Two independent lantern panes and nearby warm lights; window glass stays steady.
const MATERIAL_KEYS := ["LanternGlass_Left", "LanternGlass_Right"]
var panes: Array[StandardMaterial3D] = []
var lights: Array[OmniLight3D] = []
var flicker_enabled := true
var elapsed := 0.0
var manual_preview := false

func attach(building: Node3D) -> void:
	for index in range(2):
		var pane: StandardMaterial3D
		for node in building.find_children("*", "MeshInstance3D", true, false):
			for surface in range(node.mesh.get_surface_count()):
				var source := node.get_active_material(surface) as StandardMaterial3D
				if source != null and source.resource_name == MATERIAL_KEYS[index]:
					pane = source.duplicate()
					pane.emission_enabled = true
					pane.emission = Color(0.90, 0.31, 0.035)
					node.set_surface_override_material(surface, pane)
		assert(pane != null, "Lantern needs a dedicated pane material: " + MATERIAL_KEYS[index])
		panes.append(pane)
		var light := OmniLight3D.new()
		light.name = "LeftLanternLight" if index == 0 else "RightLanternLight"
		# Blender source x=+/-1.27 *1.035; z=2.08 *.92; front -Y becomes +Z.
		light.position = Vector3(-1.31445 if index == 0 else 1.31445, 1.9136, 2.72)
		light.light_color = Color(1.0, 0.48, 0.14)
		light.omni_range = 1.9
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		add_child(light)
		lights.append(light)
	apply_time(0.0)

func brightness(index: int, seconds: float) -> float:
	if not flicker_enabled:
		return 0.64
	var phase := TAU * seconds / 4.0 + float(index) * 1.37
	# Low-frequency breathing plus a small smooth irregularity. Never flashes off.
	return 0.60 + 0.25 * sin(phase) + 0.075 * sin(phase * 3.0 + 0.8) + 0.025 * sin(phase * 7.0 + 0.4)

func apply_time(seconds: float) -> void:
	for index in range(panes.size()):
		var value := brightness(index, seconds)
		panes[index].emission_energy_multiplier = 0.15 + 0.9 * value
		lights[index].light_energy = 0.4 + 0.9 * value

func _process(delta: float) -> void:
	if manual_preview:
		return
	elapsed += delta
	apply_time(elapsed)

func set_flicker_enabled(enabled: bool) -> void:
	flicker_enabled = enabled
	apply_time(elapsed)

func seek_preview(seconds: float) -> void:
	manual_preview = true
	elapsed = seconds
	apply_time(seconds)
