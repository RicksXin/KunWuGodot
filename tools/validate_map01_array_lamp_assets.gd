extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/array_lamp/map01_array_lamp_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/map01_array_lamp.tscn"
const DEMO_PATH := "res://scenes/map01_array_lamp_demo.tscn"
const STATE_IDS := ["LAMP_BROKEN", "LAMP_REVERSED", "LAMP_REPAIRED"]

var failures: Array[String] = []


func _init() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(str(manifest.get("source_sha256", "")) == "73e3ee65d37bfac053b0e0c915ae01af91c68ebcbf356ff47816d74f14b984ee", "Array-lamp source SHA-256 is not the approved master")
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(40, 40), "Array-lamp canvas must be 40x40")
	_check(_json_array_to_vector2i(manifest.get("subject_max_px", [])) == Vector2i(32, 32), "Array-lamp subject must fit 32x32")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(20, 36), "Array-lamp anchor must remain [20,36]")
	_check(_json_array_to_vector2i(manifest.get("visual_footprint_cells", [])) == Vector2i(2, 2), "Array-lamp visual footprint must remain 2x2 cells")
	_check(_json_array_to_vector2i(manifest.get("collision_size_source_px", [])) == Vector2i(24, 18), "Array-lamp collision must remain 24x18 source pixels")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "Array-lamp manifest must reference the reusable component")
	_check(is_equal_approx(float(manifest.get("map_scene_root_scale", 0.0)) * float(manifest.get("map_scene_instance_scale", 0.0)), 3.0), "Array-lamp Map01 scale must resolve to 3x")

	var states: Dictionary = manifest.get("states", {})
	_check(states.size() == 3, "Array-lamp manifest must define exactly three states")
	var images: Dictionary = {}
	for state_id in STATE_IDS:
		_check(states.has(state_id), "Missing array-lamp state %s" % state_id)
		if not states.has(state_id):
			continue
		var path := str(states[state_id].get("path", ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		images[state_id] = image
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		_check(image.get_size() == Vector2i(40, 40), "%s canvas must be 40x40" % state_id)
		_validate_hard_alpha(image, state_id)
		var subject_box := image.get_used_rect()
		_check(subject_box.size.x <= 32 and subject_box.size.y <= 32, "%s subject exceeds 32x32" % state_id)
		_check(subject_box.end.y == 36, "%s bottom edge must meet anchor baseline y=36" % state_id)
	_validate_silhouettes(images)
	_validate_broken_red(images.get("LAMP_BROKEN", Image.new()))
	await _validate_component_and_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Array-lamp manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Array-lamp manifest is invalid JSON")
		return {}
	return parsed


func _json_array_to_vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _validate_hard_alpha(image: Image, state_id: String) -> void:
	var values: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			values[roundi(image.get_pixel(x, y).a * 255.0)] = true
	_check(values.size() == 2 and values.has(0) and values.has(255), "%s must use binary alpha" % state_id)


func _validate_silhouettes(images: Dictionary) -> void:
	if images.size() != 3:
		return
	for pair in [["LAMP_BROKEN", "LAMP_REVERSED"], ["LAMP_BROKEN", "LAMP_REPAIRED"], ["LAMP_REVERSED", "LAMP_REPAIRED"]]:
		var first: Image = images[pair[0]]
		var second: Image = images[pair[1]]
		if first.is_empty() or second.is_empty():
			continue
		var intersection := 0
		var union := 0
		for y in first.get_height():
			for x in first.get_width():
				var first_opaque := first.get_pixel(x, y).a > 0.5
				var second_opaque := second.get_pixel(x, y).a > 0.5
				if first_opaque and second_opaque:
					intersection += 1
				if first_opaque or second_opaque:
					union += 1
		var iou := float(intersection) / float(maxi(1, union))
		_check(iou >= 0.98, "%s / %s silhouette IoU fell below 0.98: %.4f" % [pair[0], pair[1], iou])


func _validate_broken_red(image: Image) -> void:
	if image.is_empty():
		return
	var maximum_red_luma := 0.0
	for y in range(18, 32):
		for x in range(8, 32):
			var color := image.get_pixel(x, y)
			if color.a < 0.5 or not (color.r > color.g * 1.22 and color.r > color.b * 1.18):
				continue
			maximum_red_luma = maxf(maximum_red_luma, color.get_luminance() * 255.0)
	_check(maximum_red_luma <= 70.0, "LAMP_BROKEN red rune is too bright: %.2f" % maximum_red_luma)


func _validate_component_and_demo() -> void:
	_check(ResourceLoader.exists(COMPONENT_PATH, "PackedScene"), "Reusable array-lamp component is missing")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Array-lamp demo scene is missing")
	if not ResourceLoader.exists(COMPONENT_PATH, "PackedScene") or not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var component := (load(COMPONENT_PATH) as PackedScene).instantiate()
	root.add_child(component)
	await process_frame
	_check(str(component.call("get_state_id")) == "LAMP_BROKEN", "Array-lamp component must default to LAMP_BROKEN")
	var sprite := component.get_node_or_null("StateSprite") as Sprite2D
	var collision := component.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	_check(sprite != null and sprite.position == Vector2(-20.0, -36.0), "Array-lamp sprite must preserve the [20,36] anchor")
	_check(collision != null, "Array-lamp shared collision is missing")
	if collision != null:
		_check(collision.position == Vector2(0.0, -9.0), "Array-lamp collision center must remain [0,-9]")
		_check((collision.shape as RectangleShape2D).size == Vector2(24.0, 18.0), "Array-lamp collision must remain 24x18")
		_check(not collision.disabled, "Array-lamp collision must start enabled")
	var collision_shape := collision.shape if collision != null else null
	for state_id in STATE_IDS:
		_check(bool(component.call("set_state_id", state_id)), "Array-lamp component rejected %s" % state_id)
		_check(str(component.call("get_state_id")) == state_id, "Array-lamp component did not expose %s" % state_id)
		if collision != null:
			_check(collision.shape == collision_shape and not collision.disabled, "%s changed the shared collision" % state_id)
	_check(not bool(component.call("set_state_id", "NOT_A_LAMP_STATE")), "Array-lamp component must reject unknown external state IDs")
	component.queue_free()

	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	var demo_states := ["LAMP_BROKEN", "LAMP_REVERSED", "LAMP_REPAIRED"]
	for index in demo_states.size():
		var lamp := demo.get_child(index) as KWMap01ArrayLamp
		_check(lamp != null, "Demo lamp %d is not the reusable component" % index)
		if lamp == null:
			continue
		_check(lamp.scene_file_path == COMPONENT_PATH, "Demo lamp %d is not sourced from the reusable component" % index)
		_check(lamp.scale == Vector2(3.0, 3.0), "Demo lamp %d must use approved 3x display" % index)
		_check(lamp.get_state_id() == demo_states[index], "Demo lamp %d has the wrong frozen state" % index)
	var marker := demo.get_node_or_null("Marker") as CanvasItem
	_check(marker != null and marker.z_index > 5, "Demo Marker must render above all lamp sprites")
	demo.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Map01 array-lamp validation OK; 3 states, shared silhouette/anchor/collision and Marker layering verified")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
