extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/east_wall_stairs/map01_east_wall_stairs_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/map01_east_wall_stairs.tscn"
const DEMO_PATH := "res://scenes/map01_east_wall_stairs_demo.tscn"
const APPROVED_SHA256 := "889d3316c87f769ad43b0ebbef36fe77ea74cc9f05fb175f9738e58cef4530b6"
const STATE_IDS := ["STAIRS_CLOSED", "STAIRS_OPEN"]

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(str(manifest.get("source_sha256", "")) == APPROVED_SHA256, "East-wall stair source SHA-256 is not the approved master")
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(72, 56), "East-wall stair canvas must remain 72x56")
	_check(_json_array_to_vector2i(manifest.get("subject_px", [])) == Vector2i(64, 48), "East-wall stair subject must remain 64x48")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(36, 52), "East-wall stair anchor must remain [36,52]")
	_check(_json_array_to_vector2i(manifest.get("visual_footprint_cells", [])) == Vector2i(4, 3), "East-wall stair footprint must remain 4x3 cells")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "East-wall stair manifest must reference its reusable component")
	_check(not bool(manifest.get("formal_map_coordinate_frozen", true)), "East-wall stair must not claim a frozen formal Map01 coordinate")
	_check(_json_array_to_vector2i(manifest.get("candidate_document_cell", [])) == Vector2i(39, 31), "East-wall stair candidate cell changed")
	_check(_json_array_to_vector2i(manifest.get("paired_elite_candidate_document_cell", [])) == Vector2i(36, 29), "East-wall elite candidate cell changed")
	_check(bool(manifest.get("same_view_feedback_required", false)), "East-wall stair must preserve same-view elite feedback")
	_check(is_equal_approx(float(manifest.get("map_scene_root_scale", 0.0)) * float(manifest.get("map_scene_instance_scale", 0.0)), 3.0), "East-wall stair Map01 scale must resolve to 3x")
	_check(float(manifest.get("silhouette_iou", 0.0)) >= 0.98, "East-wall stair state silhouettes diverged")

	var state_specs: Dictionary = manifest.get("states", {})
	var images: Dictionary = {}
	for state_id in STATE_IDS:
		_check(state_specs.has(state_id), "Missing east-wall stair state %s" % state_id)
		if not state_specs.has(state_id):
			continue
		var path := str(state_specs[state_id].get("path", ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		images[state_id] = image
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		_check(image.get_size() == Vector2i(72, 56), "%s canvas must remain 72x56" % state_id)
		_check(image.get_used_rect() == Rect2i(4, 4, 64, 48), "%s used rect must remain [4,4,64,48]" % state_id)
		_validate_hard_alpha(image, state_id)
	_validate_silhouettes(images)
	_validate_functional_colors(images)
	await _validate_component_and_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "East-wall stair manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "East-wall stair manifest is invalid JSON")
		return {}
	return parsed


func _json_array_to_vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _validate_hard_alpha(image: Image, state_id: String) -> void:
	var alpha_values: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var alpha := roundi(color.a * 255.0)
			alpha_values[alpha] = true
			if alpha == 0:
				_check(color.r == 0.0 and color.g == 0.0 and color.b == 0.0, "%s has non-black RGB under transparent pixels" % state_id)
	_check(alpha_values.size() == 2 and alpha_values.has(0) and alpha_values.has(255), "%s must use binary alpha" % state_id)


func _validate_silhouettes(images: Dictionary) -> void:
	if images.size() != 2:
		return
	var first: Image = images["STAIRS_CLOSED"]
	var second: Image = images["STAIRS_OPEN"]
	if first.is_empty() or second.is_empty():
		return
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
	_check(iou >= 0.98, "East-wall stair runtime silhouette IoU fell below 0.98: %.4f" % iou)


func _validate_functional_colors(images: Dictionary) -> void:
	if images.size() != 2:
		return
	var closed: Image = images["STAIRS_CLOSED"]
	var opened: Image = images["STAIRS_OPEN"]
	_check(_count_exact_rgb(closed, Color8(111, 62, 69)) >= 8, "STAIRS_CLOSED lost its restrained dark-red lock traces")
	_check(_count_exact_rgb(closed, Color8(212, 184, 125)) >= 4, "STAIRS_CLOSED lost its old-gold fasteners")
	_check(_count_exact_rgb(opened, Color8(238, 224, 181)) >= 40, "STAIRS_OPEN lost its warm-ivory passage traces")


func _count_exact_rgb(image: Image, expected: Color) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.is_equal_approx(expected):
				count += 1
	return count


func _validate_component_and_demo() -> void:
	_check(ResourceLoader.exists(COMPONENT_PATH, "PackedScene"), "Reusable east-wall stair component is missing")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "East-wall stair demo scene is missing")
	if not ResourceLoader.exists(COMPONENT_PATH, "PackedScene") or not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var component := (load(COMPONENT_PATH) as PackedScene).instantiate()
	root.add_child(component)
	await process_frame
	_check(component is KWMap01EastWallStairs, "East-wall stair component does not expose KWMap01EastWallStairs")
	_check(str(component.call("get_state_id")) == "STAIRS_CLOSED", "East-wall stair component must default to STAIRS_CLOSED")
	_check(not bool(component.call("is_passage_open")), "Closed stair passage must start blocked")
	var sprite := component.get_node_or_null("StateSprite") as Sprite2D
	_check(sprite != null and sprite.position == Vector2(-36.0, -52.0), "East-wall stair sprite must preserve the [36,52] anchor")
	var expected_collisions := {
		"LeftCheekCollision": [Vector2(-20.0, -12.0), Vector2(18.0, 24.0)],
		"RightCheekCollision": [Vector2(20.0, -12.0), Vector2(18.0, 24.0)],
		"ClosedBarrierCollision": [Vector2(0.0, -24.0), Vector2(32.0, 10.0)],
	}
	for collision_name in expected_collisions:
		var collision := component.get_node_or_null("StaticBody2D/%s" % collision_name) as CollisionShape2D
		_check(collision != null, "%s is missing" % collision_name)
		if collision == null:
			continue
		_check(collision.position == expected_collisions[collision_name][0], "%s center changed" % collision_name)
		_check((collision.shape as RectangleShape2D).size == expected_collisions[collision_name][1], "%s size changed" % collision_name)
	var left_collision := component.get_node("StaticBody2D/LeftCheekCollision") as CollisionShape2D
	var right_collision := component.get_node("StaticBody2D/RightCheekCollision") as CollisionShape2D
	var barrier_collision := component.get_node("StaticBody2D/ClosedBarrierCollision") as CollisionShape2D
	_check(not left_collision.disabled and not right_collision.disabled and not barrier_collision.disabled, "Closed stair collisions must start enabled")
	_check(bool(component.call("set_state_id", "STAIRS_OPEN")), "East-wall stair component rejected STAIRS_OPEN")
	await process_frame
	_check(str(component.call("get_state_id")) == "STAIRS_OPEN", "East-wall stair component did not expose STAIRS_OPEN")
	_check(bool(component.call("is_passage_open")), "Open stair passage did not report open")
	_check(not left_collision.disabled and not right_collision.disabled, "Open state disabled a static stone-cheek collision")
	_check(barrier_collision.disabled, "Open state did not disable the center barrier")
	_check(bool(component.call("set_state_id", "STAIRS_CLOSED")), "East-wall stair component rejected STAIRS_CLOSED")
	await process_frame
	_check(not barrier_collision.disabled, "Closed state did not restore the center barrier")
	_check(not bool(component.call("set_state_id", "NOT_A_STAIRS_STATE")), "East-wall stair component must reject unknown state IDs")
	component.queue_free()

	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	for index in STATE_IDS.size():
		var node_name := "StairsClosed" if index == 0 else "StairsOpen"
		var stair := demo.get_node_or_null(node_name) as KWMap01EastWallStairs
		_check(stair != null, "Demo %s is not the reusable stair component" % node_name)
		if stair == null:
			continue
		_check(stair.scene_file_path == COMPONENT_PATH, "Demo %s is not sourced from the reusable stair component" % node_name)
		_check(stair.scale == Vector2(3.0, 3.0), "Demo %s must use approved 3x display" % node_name)
		_check(stair.get_state_id() == STATE_IDS[index], "Demo %s has the wrong frozen state" % node_name)
	var marker := demo.get_node_or_null("Marker") as CanvasItem
	_check(marker != null and marker.z_index > 5, "Demo Marker must render above stair sprites")
	demo.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP01_EAST_WALL_STAIRS_VALIDATION_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP01_EAST_WALL_STAIRS_VALIDATION_FAILED: %d error(s)" % failures.size())
	quit(1)
