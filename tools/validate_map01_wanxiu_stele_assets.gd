extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/wanxiu_stele/map01_wanxiu_stele_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/map01_wanxiu_stele.tscn"
const DEMO_PATH := "res://scenes/map01_wanxiu_stele_demo.tscn"
const APPROVED_SHA256 := "ac444400eccc60e00ed07ccf3de741c9b76bb71e4e4062870feceb4dfb23c7c3"
const STATE_IDS := ["STELE_DEFAULT", "STELE_INTERACTED", "STELE_C07_RESERVED"]
const GROOVE := Vector3i(27, 42, 49)
const GROOVE_SOFT := Vector3i(39, 55, 61)
const OLD_GOLD := Vector3i(151, 126, 82)
const ACTIVE_GOLD := Vector3i(197, 163, 91)
const WARM_IVORY := Vector3i(238, 224, 181)
const RESERVED_CYAN := Vector3i(155, 179, 189)
const RESERVED_HIGHLIGHT := Vector3i(203, 225, 226)
const INSET := Rect2i(24, 14, 13, 16)

var failures: Array[String] = []


func _init() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(str(manifest.get("source_sha256", "")) == APPROVED_SHA256, "Wanxiu stele source SHA-256 is not the approved master")
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(56, 56), "Wanxiu stele canvas must be 56x56")
	_check(_json_array_to_vector2i(manifest.get("subject_max_px", [])) == Vector2i(48, 48), "Wanxiu stele subject must fit 48x48")
	_check(_json_array_to_vector2i(manifest.get("normalized_subject_px", [])) == Vector2i(43, 48), "Wanxiu stele normalized subject size changed")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(28, 52), "Wanxiu stele anchor must remain [28,52]")
	_check(_json_array_to_vector2i(manifest.get("visual_footprint_cells", [])) == Vector2i(3, 3), "Wanxiu stele visual footprint must remain 3x3 cells")
	_check(_json_array_to_vector2i(manifest.get("collision_size_source_px", [])) == Vector2i(32, 20), "Wanxiu stele collision must remain 32x20 source pixels")
	_check(_json_array_to_vector2i(manifest.get("collision_center_source_px", [])) == Vector2i(0, -10), "Wanxiu stele collision center must remain [0,-10]")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "Wanxiu stele manifest must reference the reusable component")
	_check(not bool(manifest.get("formal_map_coordinate_frozen", true)), "Wanxiu stele must not claim a frozen formal Map01 coordinate")
	_check(is_equal_approx(float(manifest.get("map_scene_root_scale", 0.0)) * float(manifest.get("map_scene_instance_scale", 0.0)), 3.0), "Wanxiu stele Map01 scale must resolve to 3x")

	var states: Dictionary = manifest.get("states", {})
	_check(states.size() == 3, "Wanxiu stele manifest must define exactly three states")
	var images: Dictionary = {}
	for state_id in STATE_IDS:
		_check(states.has(state_id), "Missing Wanxiu stele state %s" % state_id)
		if not states.has(state_id):
			continue
		var path := str(states[state_id].get("path", ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		images[state_id] = image
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		_check(image.get_size() == Vector2i(56, 56), "%s canvas must be 56x56" % state_id)
		_validate_hard_alpha(image, state_id)
		var subject_box := image.get_used_rect()
		_check(subject_box.size == Vector2i(43, 48), "%s subject must remain 43x48" % state_id)
		_check(subject_box.end.y == 52, "%s bottom edge must meet anchor baseline y=52" % state_id)
		_check(subject_box.position.x + (subject_box.size.x - 1) / 2 == 28, "%s subject must remain centered on anchor x=28" % state_id)
	_validate_exact_silhouettes(images)
	_validate_inset_semantics(images)
	await _validate_component_and_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Wanxiu stele manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Wanxiu stele manifest is invalid JSON")
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


func _validate_exact_silhouettes(images: Dictionary) -> void:
	if images.size() != 3:
		return
	var reference: Image = images.get("STELE_DEFAULT", Image.new())
	if reference.is_empty():
		return
	for state_id in ["STELE_INTERACTED", "STELE_C07_RESERVED"]:
		var candidate: Image = images.get(state_id, Image.new())
		if candidate.is_empty():
			continue
		for y in reference.get_height():
			for x in reference.get_width():
				var same_alpha := (reference.get_pixel(x, y).a > 0.5) == (candidate.get_pixel(x, y).a > 0.5)
				if not same_alpha:
					_check(false, "%s must share the exact STELE_DEFAULT alpha silhouette" % state_id)
					return


func _validate_inset_semantics(images: Dictionary) -> void:
	var default_image: Image = images.get("STELE_DEFAULT", Image.new())
	var interacted_image: Image = images.get("STELE_INTERACTED", Image.new())
	var reserved_image: Image = images.get("STELE_C07_RESERVED", Image.new())
	if default_image.is_empty() or interacted_image.is_empty() or reserved_image.is_empty():
		return
	_check(_count_colors(default_image, [GROOVE]) == 12, "STELE_DEFAULT must contain twelve interrupted dormant groove pixels")
	_check(_count_colors(default_image, [OLD_GOLD, ACTIVE_GOLD, WARM_IVORY, RESERVED_CYAN, RESERVED_HIGHLIGHT]) == 0, "STELE_DEFAULT inset must remain inert")
	_check(_count_colors(interacted_image, [OLD_GOLD, ACTIVE_GOLD, WARM_IVORY]) == 13, "STELE_INTERACTED must contain thirteen disconnected response notches")
	_check(_count_colors(interacted_image, [RESERVED_CYAN, RESERVED_HIGHLIGHT]) == 0, "STELE_INTERACTED must not reveal the C07 reservation trace")
	_check(_count_colors(reserved_image, [RESERVED_CYAN, RESERVED_HIGHLIGHT]) == 3, "STELE_C07_RESERVED must keep the silver-cyan trace to three pixels")
	_check(_count_colors(reserved_image, [OLD_GOLD, ACTIVE_GOLD, WARM_IVORY]) == 0, "STELE_C07_RESERVED must not show the interacted total-seal response")
	_check(not _has_cross_center(default_image, [GROOVE]), "STELE_DEFAULT inset contains a cross-like mark")
	_check(not _has_cross_center(interacted_image, [OLD_GOLD, ACTIVE_GOLD, WARM_IVORY]), "STELE_INTERACTED inset contains a cross-like mark")
	_check(not _has_cross_center(reserved_image, [GROOVE_SOFT, RESERVED_CYAN, RESERVED_HIGHLIGHT]), "STELE_C07_RESERVED inset contains a cross-like mark")


func _count_colors(image: Image, colors: Array[Vector3i]) -> int:
	var total := 0
	for y in range(INSET.position.y, INSET.end.y):
		for x in range(INSET.position.x, INSET.end.x):
			if colors.has(_rgb8(image.get_pixel(x, y))):
				total += 1
	return total


func _has_cross_center(image: Image, colors: Array[Vector3i]) -> bool:
	for y in range(INSET.position.y + 1, INSET.end.y - 1):
		for x in range(INSET.position.x + 1, INSET.end.x - 1):
			if not colors.has(_rgb8(image.get_pixel(x, y))):
				continue
			if (
				colors.has(_rgb8(image.get_pixel(x - 1, y)))
				and colors.has(_rgb8(image.get_pixel(x + 1, y)))
				and colors.has(_rgb8(image.get_pixel(x, y - 1)))
				and colors.has(_rgb8(image.get_pixel(x, y + 1)))
			):
				return true
	return false


func _rgb8(color: Color) -> Vector3i:
	return Vector3i(roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0))


func _validate_component_and_demo() -> void:
	_check(ResourceLoader.exists(COMPONENT_PATH, "PackedScene"), "Reusable Wanxiu stele component is missing")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Wanxiu stele demo scene is missing")
	if not ResourceLoader.exists(COMPONENT_PATH, "PackedScene") or not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var component := (load(COMPONENT_PATH) as PackedScene).instantiate()
	root.add_child(component)
	await process_frame
	_check(str(component.call("get_state_id")) == "STELE_DEFAULT", "Wanxiu stele component must default to STELE_DEFAULT")
	var sprite := component.get_node_or_null("StateSprite") as Sprite2D
	var collision := component.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	_check(sprite != null and sprite.position == Vector2(-28.0, -52.0), "Wanxiu stele sprite must preserve the [28,52] anchor")
	_check(collision != null, "Wanxiu stele shared collision is missing")
	if collision != null:
		_check(collision.position == Vector2(0.0, -10.0), "Wanxiu stele collision center must remain [0,-10]")
		_check((collision.shape as RectangleShape2D).size == Vector2(32.0, 20.0), "Wanxiu stele collision must remain 32x20")
		_check(not collision.disabled, "Wanxiu stele collision must start enabled")
	var collision_shape := collision.shape if collision != null else null
	for state_id in STATE_IDS:
		_check(bool(component.call("set_state_id", state_id)), "Wanxiu stele component rejected %s" % state_id)
		_check(str(component.call("get_state_id")) == state_id, "Wanxiu stele component did not expose %s" % state_id)
		if collision != null:
			_check(collision.shape == collision_shape and not collision.disabled, "%s changed the shared collision" % state_id)
	_check(not bool(component.call("set_state_id", "NOT_A_STELE_STATE")), "Wanxiu stele component must reject unknown external state IDs")
	component.queue_free()

	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	var demo_names := ["SteleDefault", "SteleInteracted", "SteleC07Reserved"]
	for index in demo_names.size():
		var stele := demo.get_node_or_null(demo_names[index]) as KWMap01WanxiuStele
		_check(stele != null, "Demo stele %d is not the reusable component" % index)
		if stele == null:
			continue
		_check(stele.scene_file_path == COMPONENT_PATH, "Demo stele %d is not sourced from the reusable component" % index)
		_check(stele.scale == Vector2(3.0, 3.0), "Demo stele %d must use approved 3x display" % index)
		_check(stele.get_state_id() == STATE_IDS[index], "Demo stele %d has the wrong frozen state" % index)
	var marker := demo.get_node_or_null("Marker") as CanvasItem
	_check(marker != null and marker.z_index > 5, "Demo Marker must render above all stele sprites")
	demo.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Map01 Wanxiu stele validation OK; 3 clean states, exact silhouette/anchor/collision and C07 boundary verified")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
