extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/derelict_camp/map01_derelict_camp_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/map01_derelict_camp.tscn"
const DEMO_PATH := "res://scenes/map01_derelict_camp_demo.tscn"
const APPROVED_SHA256 := "3f79b9111c2a8706e8fac707dd9b2e2dd978d0ff9b5140162a3196e397ba3b01"
const STATE_IDS := ["CAMP_CORPSES_DEFAULT", "CAMP_CORPSES_PROCESSED"]

var failures: Array[String] = []


func _init() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(str(manifest.get("source_sha256", "")) == APPROVED_SHA256, "Derelict-camp source SHA-256 is not the approved master")
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(96, 56), "Derelict-camp canvas must remain 96x56")
	_check(_json_array_to_vector2i(manifest.get("base_subject_px", [])) == Vector2i(64, 43), "Derelict-camp base must remain 64x43")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(48, 52), "Derelict-camp anchor must remain [48,52]")
	_check(_json_array_to_vector2i(manifest.get("visual_footprint_cells", [])) == Vector2i(5, 3), "Derelict-camp footprint must remain 5x3 cells")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "Derelict-camp manifest must reference its reusable component")
	_check(not bool(manifest.get("formal_map_coordinate_frozen", true)), "Derelict camp must not claim a frozen formal Map01 coordinate")
	_check(is_equal_approx(float(manifest.get("map_scene_root_scale", 0.0)) * float(manifest.get("map_scene_instance_scale", 0.0)), 3.0), "Derelict-camp Map01 scale must resolve to 3x")
	_check("independent" in str(manifest.get("ledger_contract", "")), "Ledger must remain an independent map object")

	var layers: Dictionary = manifest.get("layers", {})
	_check(layers.size() == 3, "Derelict camp must define one base and two corpse overlays")
	var base := _load_layer_image(layers, "CAMP_STAY_BASE")
	var default_overlay := _load_layer_image(layers, "CAMP_CORPSES_DEFAULT")
	var processed_overlay := _load_layer_image(layers, "CAMP_CORPSES_PROCESSED")
	_validate_layer(base, "CAMP_STAY_BASE")
	_validate_layer(default_overlay, "CAMP_CORPSES_DEFAULT")
	_validate_layer(processed_overlay, "CAMP_CORPSES_PROCESSED")
	if not base.is_empty():
		_check(base.get_used_rect() == Rect2i(16, 9, 64, 43), "CAMP_STAY_BASE used rect must remain [16,9,64,43]")
	if not default_overlay.is_empty():
		var used := default_overlay.get_used_rect()
		_check(used.position.x >= 80 and used.end.x <= 95, "Default corpse evidence must stay in the right-side evidence slot")
		_check(used.position.y >= 29 and used.end.y <= 49, "Default corpse evidence moved outside its approved vertical slot")
	if not processed_overlay.is_empty():
		var used := processed_overlay.get_used_rect()
		_check(used.position.x >= 80 and used.end.x <= 94, "Processed remnants must stay in the right-side evidence slot")
		_check(_count_red_pixels(processed_overlay) == 0, "Processed corpse overlay must not contain red droplets or blood specks")
	if not base.is_empty() and not default_overlay.is_empty():
		_check(_count_alpha_overlap(base, default_overlay) == 0, "Default evidence must not overwrite the shared camp base")
	if not base.is_empty() and not processed_overlay.is_empty():
		_check(_count_alpha_overlap(base, processed_overlay) == 0, "Processed remnants must not overwrite the shared camp base")
	await _validate_component_and_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Derelict-camp manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Derelict-camp manifest is invalid JSON")
		return {}
	return parsed


func _json_array_to_vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _load_layer_image(layers: Dictionary, layer_id: String) -> Image:
	_check(layers.has(layer_id), "Missing derelict-camp layer %s" % layer_id)
	if not layers.has(layer_id):
		return Image.new()
	var path := str(layers[layer_id].get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(not image.is_empty(), "Could not load %s" % path)
	return image


func _validate_layer(image: Image, layer_id: String) -> void:
	if image.is_empty():
		return
	_check(image.get_size() == Vector2i(96, 56), "%s canvas must remain 96x56" % layer_id)
	var alpha_values: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var alpha := roundi(color.a * 255.0)
			alpha_values[alpha] = true
			if alpha == 0:
				_check(color.r == 0.0 and color.g == 0.0 and color.b == 0.0, "%s has non-black RGB under transparent pixels" % layer_id)
	_check(alpha_values.size() == 2 and alpha_values.has(0) and alpha_values.has(255), "%s must use binary alpha" % layer_id)


func _count_red_pixels(image: Image) -> int:
	var total := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.r > color.g * 1.18 and color.r > color.b * 1.15 and color.r > 0.3:
				total += 1
	return total


func _count_alpha_overlap(first: Image, second: Image) -> int:
	var total := 0
	for y in first.get_height():
		for x in first.get_width():
			if first.get_pixel(x, y).a > 0.5 and second.get_pixel(x, y).a > 0.5:
				total += 1
	return total


func _validate_component_and_demo() -> void:
	_check(ResourceLoader.exists(COMPONENT_PATH, "PackedScene"), "Reusable derelict-camp component is missing")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Derelict-camp demo scene is missing")
	if not ResourceLoader.exists(COMPONENT_PATH, "PackedScene") or not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var component := (load(COMPONENT_PATH) as PackedScene).instantiate()
	root.add_child(component)
	await process_frame
	_check(component is KWMap01DerelictCamp, "Derelict-camp component does not expose KWMap01DerelictCamp")
	_check(str(component.call("get_state_id")) == "CAMP_CORPSES_DEFAULT", "Derelict camp must default to CAMP_CORPSES_DEFAULT")
	_check(not component.has_method("set_ledger_state"), "Derelict-camp component must not expose a ledger state API")
	var base_sprite := component.get_node_or_null("StayBaseSprite") as Sprite2D
	var evidence_sprite := component.get_node_or_null("CorpseEvidenceSprite") as Sprite2D
	_check(base_sprite != null and base_sprite.position == Vector2(-48.0, -52.0), "Camp base must preserve the [48,52] anchor")
	_check(evidence_sprite != null and evidence_sprite.position == Vector2(-48.0, -52.0), "Corpse overlay must share the camp anchor")
	var base_texture := base_sprite.texture if base_sprite != null else null
	var expected_collision := {
		"LeftTentCollision": [Vector2(-15.0, -21.0), Vector2(20.0, 14.0)],
		"RightTentCollision": [Vector2(14.0, -14.0), Vector2(22.0, 16.0)],
	}
	for collision_name in expected_collision:
		var collision := component.get_node_or_null("StaticBody2D/%s" % collision_name) as CollisionShape2D
		_check(collision != null, "%s is missing" % collision_name)
		if collision == null:
			continue
		_check(collision.position == expected_collision[collision_name][0], "%s center changed" % collision_name)
		_check((collision.shape as RectangleShape2D).size == expected_collision[collision_name][1], "%s size changed" % collision_name)
		_check(not collision.disabled, "%s must start enabled" % collision_name)
	for state_id in STATE_IDS:
		_check(bool(component.call("set_state_id", state_id)), "Derelict-camp component rejected %s" % state_id)
		_check(str(component.call("get_state_id")) == state_id, "Derelict-camp component did not expose %s" % state_id)
		if base_sprite != null:
			_check(base_sprite.texture == base_texture, "%s changed the shared base texture" % state_id)
	_check(not bool(component.call("set_state_id", "CAMP_LEDGER_READ")), "Derelict-camp component must reject ledger state IDs")
	component.queue_free()

	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	for index in STATE_IDS.size():
		var camp_name := "CampDefault" if index == 0 else "CampProcessed"
		var camp := demo.get_node_or_null(camp_name) as KWMap01DerelictCamp
		_check(camp != null, "Demo %s is not the reusable camp component" % camp_name)
		if camp == null:
			continue
		_check(camp.scene_file_path == COMPONENT_PATH, "Demo %s is not sourced from the reusable component" % camp_name)
		_check(camp.scale == Vector2(3.0, 3.0), "Demo %s must use approved 3x display" % camp_name)
		_check(camp.get_state_id() == STATE_IDS[index], "Demo %s has the wrong frozen state" % camp_name)
	var marker := demo.get_node_or_null("Marker") as CanvasItem
	_check(marker != null and marker.z_index > 6, "Demo Marker must render above the camp base and evidence overlay")
	demo.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Map01 derelict-camp validation OK; shared base, two corpse overlays, split collisions and ledger boundary verified")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
