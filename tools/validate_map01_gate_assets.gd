extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/wanxiu_gate/wanxiu_gate_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/wanxiu_gate.tscn"
const DEMO_PATH := "res://scenes/map01_gate_demo.tscn"
const IVORY := Color8(238, 224, 181, 255)

var failures: Array[String] = []


func _init() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(128, 40), "Gate canvas must be 128x40 source pixels")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(64, 36), "Gate anchor must remain bottom-center")
	_check(int(manifest.get("source_pixel_per_logical_cell", 0)) == 16, "Gate source scale must be 16px per logical cell")
	var map_root_scale := float(manifest.get("map_scene_root_scale", 0.0))
	var map_instance_scale := float(manifest.get("map_scene_instance_scale", 0.0))
	_check(is_equal_approx(map_root_scale * map_instance_scale, 3.0), "Gate Map01 instance scale must resolve to the approved 3x runtime display")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "Gate manifest must reference the reusable component scene")
	_check(int(manifest.get("notch_count", 0)) == 13, "Gate must define exactly thirteen notches")
	var layers: Dictionary = manifest.get("layers", {})
	_check(layers.size() == 6, "Expected six Wanxiu Gate visual layers")
	for asset_id in layers:
		var path := str(layers[asset_id])
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		_check(image.get_size() == Vector2i(128, 40), "%s canvas must be 128x40" % asset_id)
		var alpha_values: Dictionary = {}
		for y in image.get_height():
			for x in image.get_width():
				alpha_values[roundi(image.get_pixel(x, y).a * 255.0)] = true
		_check(alpha_values.size() <= 2 and alpha_values.has(0), "%s must use hard transparent alpha" % asset_id)
		_check(alpha_values.has(255), "%s must contain opaque artwork" % asset_id)
	_validate_notches(str(layers.get("gate_title_marks", "")), manifest)
	_validate_state_contract(manifest)
	_validate_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Wanxiu Gate manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Wanxiu Gate manifest is invalid JSON")
		return {}
	return parsed


func _json_array_to_vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _validate_notches(path: String, manifest: Dictionary) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image.is_empty():
		return
	var y := int(manifest.get("notch_sample_y", -1))
	var runs := 0
	var inside_run := false
	for x in image.get_width():
		var pixel := image.get_pixel(x, y)
		var is_notch := pixel.is_equal_approx(IVORY)
		if is_notch and not inside_run:
			runs += 1
		inside_run = is_notch
	_check(runs == 13, "Gate title layer must contain exactly 13 visible notch runs, got %d" % runs)


func _validate_state_contract(manifest: Dictionary) -> void:
	var states: Dictionary = manifest.get("state_contract", {})
	_check(states.size() == 3, "Gate must define three runtime states")
	_check(not bool(states.get("GATE_LOCKED", {}).get("center_passage_walkable", true)), "GATE_LOCKED center must remain blocked")
	_check(not bool(states.get("GATE_BOSS_READY", {}).get("center_passage_walkable", true)), "GATE_BOSS_READY center must remain blocked")
	_check(bool(states.get("GATE_OPEN", {}).get("center_passage_walkable", false)), "GATE_OPEN center must be walkable")


func _validate_demo() -> void:
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Wanxiu Gate demo scene is missing")
	if not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var scene := load(DEMO_PATH) as PackedScene
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	var gate := instance.get_node_or_null("WanxiuGate")
	_check(gate != null, "Demo must instantiate the reusable Wanxiu Gate component")
	if gate == null:
		instance.queue_free()
		return
	_check(gate.scene_file_path == COMPONENT_PATH, "Demo gate is not sourced from the reusable component scene")
	_check(gate.get_node_or_null("GateStayBase") != null, "Reusable gate base layer is missing")
	_check(gate.get_node_or_null("GateTopForeground") != null, "Reusable gate foreground layer is missing")
	_check(gate.get_node_or_null("GateTitleMarks") != null, "Reusable gate title layer is missing")
	_check(gate.get_node_or_null("CenterBarrier/CollisionShape2D") != null, "Reusable gate center barrier is missing")
	_check(gate.scale == Vector2(3.0, 3.0), "Demo must display the 16px source art at 3x scale")
	var base := gate.get_node("GateStayBase") as Sprite2D
	_check(base.position == Vector2(-64.0, -36.0), "Reusable gate must preserve the manifest bottom-center anchor")
	var left_foundation := gate.get_node("OuterWalls/LeftCollision") as CollisionShape2D
	var right_foundation := gate.get_node("OuterWalls/RightCollision") as CollisionShape2D
	var center := gate.get_node("CenterBarrier/CollisionShape2D") as CollisionShape2D
	_check((left_foundation.shape as RectangleShape2D).size == Vector2(46.0, 17.0), "Left foundation collision differs from the manifest")
	_check((right_foundation.shape as RectangleShape2D).size == Vector2(46.0, 17.0), "Right foundation collision differs from the manifest")
	_check((center.shape as RectangleShape2D).size == Vector2(28.0, 14.0), "Center barrier collision differs from the manifest")
	_check(not left_foundation.disabled and not right_foundation.disabled, "Outer foundation collisions must always remain enabled")
	_check(not bool(instance.call("is_center_passage_open")), "Demo initial locked state must block the center")
	_check(str(gate.call("get_state_id")) == "GATE_LOCKED", "Reusable gate must expose GATE_LOCKED")
	_check(not center.disabled, "Demo center collision shape must remain enabled in GATE_LOCKED")
	instance.call("set_gate_state", 1)
	await physics_frame
	_check(not bool(instance.call("is_center_passage_open")), "Demo boss-ready state must block the center")
	_check(str(gate.call("get_state_id")) == "GATE_BOSS_READY", "Reusable gate must expose GATE_BOSS_READY")
	_check(not center.disabled, "Demo center collision shape must remain enabled in GATE_BOSS_READY")
	instance.call("set_gate_state", 2)
	await physics_frame
	_check(bool(instance.call("is_center_passage_open")), "Demo open state must release the center")
	_check(str(gate.call("get_state_id")) == "GATE_OPEN", "Reusable gate must expose GATE_OPEN")
	_check(center.disabled, "Demo center collision shape must disable in GATE_OPEN")
	_check(not bool(gate.call("set_state_id", "NOT_A_GATE_STATE")), "Reusable gate must reject unknown external state IDs")
	gate.call("set_occluder_faded", true, true)
	_check(is_equal_approx(float(gate.call("get_foreground_alpha")), 0.22), "Reusable gate must expose the approved 0.22 foreground fade")
	gate.call("set_occluder_faded", false, true)
	var foreground := gate.get_node("GateTopForeground") as CanvasItem
	var title := gate.get_node("GateTitleMarks") as CanvasItem
	var boss_marker := instance.get_node("BossMarker") as CanvasItem
	_check(foreground.z_index < title.z_index, "Gate title marks must render above the fadeable foreground")
	_check(gate.z_index + title.z_index < boss_marker.z_index, "Boss marker must render above gate foreground/title layers")
	instance.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Wanxiu Gate validation OK; 6 layers, 3 states, 13 notches, collision contract verified")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
