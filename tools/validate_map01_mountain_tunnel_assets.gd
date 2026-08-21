extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/landmarks/mountain_tunnel/map01_mountain_tunnel_manifest.json"
const COMPONENT_PATH := "res://scenes/maps/components/map01_mountain_tunnel.tscn"
const DEMO_PATH := "res://scenes/map01_mountain_tunnel_demo.tscn"
const APPROVED_SHA256 := "a3b98ec88961971b31e2aae0ccbb6bdb6ad101246c13fbec3ff79176bb4608c8"
const STATE_IDS := ["TUNNEL_DEFAULT", "TUNNEL_DISCOVERED", "TUNNEL_CLEARED"]
const DULL_EMBER := Color8(181, 76, 50)
const WARM_IVORY := Color8(238, 224, 181)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(str(manifest.get("source_sha256", "")) == APPROVED_SHA256, "Mountain-tunnel source SHA-256 is not the approved master")
	_check(_json_array_to_vector2i(manifest.get("canvas_px", [])) == Vector2i(72, 56), "Mountain-tunnel canvas must remain 72x56")
	_check(_json_array_to_vector2i(manifest.get("subject_px", [])) == Vector2i(64, 39), "Mountain-tunnel subject must remain 64x39")
	_check(_json_array_to_vector2i(manifest.get("anchor_px", [])) == Vector2i(36, 52), "Mountain-tunnel anchor must remain [36,52]")
	_check(_json_array_to_vector2i(manifest.get("visual_footprint_cells", [])) == Vector2i(4, 3), "Mountain-tunnel footprint must remain 4x3 cells")
	_check(str(manifest.get("component_scene", "")) == COMPONENT_PATH, "Mountain-tunnel manifest must reference its reusable component")
	_check(not bool(manifest.get("formal_map_coordinate_frozen", true)), "Mountain-tunnel must not claim a frozen formal Map01 coordinate")
	_check(_json_array_to_vector2i(manifest.get("candidate_document_cell", [])) == Vector2i(8, 28), "Mountain-tunnel candidate cell changed")
	_check(is_equal_approx(float(manifest.get("map_scene_root_scale", 0.0)) * float(manifest.get("map_scene_instance_scale", 0.0)), 3.0), "Mountain-tunnel Map01 scale must resolve to 3x")
	_check(is_equal_approx(float(manifest.get("foreground_faded_alpha", 0.0)), 0.22), "Mountain-tunnel foreground fade must remain 0.22")
	_check(float(manifest.get("minimum_silhouette_iou", 0.0)) >= 0.98, "Mountain-tunnel state silhouettes diverged")

	var layer_specs: Dictionary = manifest.get("layers", {})
	_check(layer_specs.size() == 5, "Mountain-tunnel manifest must define five runtime layers")
	var images: Dictionary = {}
	for layer_id in layer_specs:
		var path := str(layer_specs[layer_id].get("path", ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		images[layer_id] = image
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		_check(image.get_size() == Vector2i(72, 56), "%s canvas must remain 72x56" % layer_id)
		_validate_hard_alpha(image, str(layer_id))
	_validate_layer_regions(images)
	_validate_state_composites(images)
	_validate_functional_colors(images)
	await _validate_component_and_demo()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Mountain-tunnel manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Mountain-tunnel manifest is invalid JSON")
		return {}
	return parsed


func _json_array_to_vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _validate_hard_alpha(image: Image, layer_id: String) -> void:
	var alpha_values: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var alpha := roundi(color.a * 255.0)
			alpha_values[alpha] = true
			if alpha == 0:
				_check(color.r == 0.0 and color.g == 0.0 and color.b == 0.0, "%s has non-black RGB under transparent pixels" % layer_id)
	_check(alpha_values.size() == 2 and alpha_values.has(0) and alpha_values.has(255), "%s must use binary alpha" % layer_id)


func _validate_layer_regions(images: Dictionary) -> void:
	if images.size() != 5:
		return
	var base: Image = images["TUNNEL_STAY_BASE"]
	var roof: Image = images["TUNNEL_ROOF_FOREGROUND"]
	for y in base.get_height():
		for x in base.get_width():
			if roof.get_pixel(x, y).a > 0.5:
				_check(y <= 32, "Tunnel roof foreground leaked below its fadeable cap")
			if base.get_pixel(x, y).a > 0.5:
				_check(y >= 29, "Tunnel base leaked above the static shoulder band")
				_check(x < 27 or x >= 45, "Tunnel base leaked into the center state slot")
	for state_id in STATE_IDS:
		var state: Image = images[state_id]
		for y in state.get_height():
			for x in state.get_width():
				if state.get_pixel(x, y).a > 0.5:
					_check(y >= 29 and x >= 27 and x < 45, "%s leaked outside the center state slot" % state_id)


func _validate_state_composites(images: Dictionary) -> void:
	if images.size() != 5:
		return
	var masks: Dictionary = {}
	for state_id in STATE_IDS:
		var state_mask: Array[bool] = []
		var base: Image = images["TUNNEL_STAY_BASE"]
		var roof: Image = images["TUNNEL_ROOF_FOREGROUND"]
		var state: Image = images[state_id]
		for y in base.get_height():
			for x in base.get_width():
				state_mask.append(
					base.get_pixel(x, y).a > 0.5
					or roof.get_pixel(x, y).a > 0.5
					or state.get_pixel(x, y).a > 0.5
				)
		masks[state_id] = state_mask
	for pair in [
		["TUNNEL_DEFAULT", "TUNNEL_DISCOVERED"],
		["TUNNEL_DEFAULT", "TUNNEL_CLEARED"],
		["TUNNEL_DISCOVERED", "TUNNEL_CLEARED"],
	]:
		var first: Array = masks[pair[0]]
		var second: Array = masks[pair[1]]
		var intersection := 0
		var union := 0
		for index in first.size():
			if first[index] and second[index]:
				intersection += 1
			if first[index] or second[index]:
				union += 1
		var iou := float(intersection) / float(maxi(1, union))
		_check(iou >= 0.98, "%s / %s runtime silhouette IoU fell below 0.98: %.4f" % [pair[0], pair[1], iou])


func _validate_functional_colors(images: Dictionary) -> void:
	if images.size() != 5:
		return
	_check(_count_exact_rgb(images["TUNNEL_DEFAULT"], DULL_EMBER) == 0, "TUNNEL_DEFAULT must not reveal the forge ember")
	_check(_count_exact_rgb(images["TUNNEL_DISCOVERED"], DULL_EMBER) >= 1, "TUNNEL_DISCOVERED lost its restrained dull ember")
	_check(_count_exact_rgb(images["TUNNEL_CLEARED"], WARM_IVORY) >= 1, "TUNNEL_CLEARED lost its stable warm-ivory trace")


func _count_exact_rgb(image: Image, expected: Color) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.is_equal_approx(expected):
				count += 1
	return count


func _validate_component_and_demo() -> void:
	_check(ResourceLoader.exists(COMPONENT_PATH, "PackedScene"), "Reusable mountain-tunnel component is missing")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Mountain-tunnel demo scene is missing")
	if not ResourceLoader.exists(COMPONENT_PATH, "PackedScene") or not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var component := (load(COMPONENT_PATH) as PackedScene).instantiate()
	root.add_child(component)
	await process_frame
	_check(component is KWMap01MountainTunnel, "Mountain-tunnel component does not expose KWMap01MountainTunnel")
	_check(str(component.call("get_state_id")) == "TUNNEL_DEFAULT", "Mountain-tunnel component must default to TUNNEL_DEFAULT")
	_check(not bool(component.call("is_passage_open")), "Default tunnel passage must start blocked")
	for sprite_name in ["StayBaseSprite", "StateSprite", "RoofForeground"]:
		var sprite := component.get_node_or_null(sprite_name) as Sprite2D
		_check(sprite != null and sprite.position == Vector2(-36.0, -52.0), "%s must preserve the [36,52] anchor" % sprite_name)
	var expected_collisions := {
		"StaticShoulders/LeftShoulderCollision": [Vector2(-20.0, -10.0), Vector2(20.0, 18.0)],
		"StaticShoulders/RightShoulderCollision": [Vector2(20.0, -10.0), Vector2(20.0, 18.0)],
		"CenterBarrier/CollisionShape2D": [Vector2(0.0, -10.0), Vector2(16.0, 18.0)],
	}
	for node_path in expected_collisions:
		var collision := component.get_node_or_null(node_path) as CollisionShape2D
		_check(collision != null, "%s is missing" % node_path)
		if collision == null:
			continue
		_check(collision.position == expected_collisions[node_path][0], "%s center changed" % node_path)
		_check((collision.shape as RectangleShape2D).size == expected_collisions[node_path][1], "%s size changed" % node_path)
	var left_collision := component.get_node("StaticShoulders/LeftShoulderCollision") as CollisionShape2D
	var right_collision := component.get_node("StaticShoulders/RightShoulderCollision") as CollisionShape2D
	var center_collision := component.get_node("CenterBarrier/CollisionShape2D") as CollisionShape2D
	_check(not left_collision.disabled and not right_collision.disabled and not center_collision.disabled, "Default tunnel collisions must start enabled")
	_check(bool(component.call("set_state_id", "TUNNEL_DISCOVERED")), "Mountain-tunnel component rejected TUNNEL_DISCOVERED")
	await physics_frame
	_check(not bool(component.call("is_passage_open")) and not center_collision.disabled, "Discovered tunnel must remain blocked")
	_check(bool(component.call("set_state_id", "TUNNEL_CLEARED")), "Mountain-tunnel component rejected TUNNEL_CLEARED")
	await physics_frame
	_check(bool(component.call("is_passage_open")) and center_collision.disabled, "Cleared tunnel did not release the center passage")
	_check(not left_collision.disabled and not right_collision.disabled, "Cleared tunnel disabled a static rock-shoulder collision")
	_check(bool(component.call("set_state_id", "TUNNEL_DEFAULT")), "Mountain-tunnel component could not restore TUNNEL_DEFAULT")
	await physics_frame
	_check(not center_collision.disabled, "Default tunnel did not restore the center barrier")
	_check(not bool(component.call("set_state_id", "NOT_A_TUNNEL_STATE")), "Mountain-tunnel component must reject unknown state IDs")
	component.call("set_occluder_faded", true, true)
	_check(is_equal_approx(float(component.call("get_foreground_alpha")), 0.22), "Mountain-tunnel component did not expose the approved 0.22 foreground fade")
	component.call("set_occluder_faded", false, true)
	_check(is_equal_approx(float(component.call("get_foreground_alpha")), 1.0), "Mountain-tunnel component did not restore the foreground")
	var state_sprite := component.get_node("StateSprite") as CanvasItem
	var foreground := component.get_node("RoofForeground") as CanvasItem
	_check(foreground.z_index > state_sprite.z_index, "Mountain-tunnel roof must render above its center state")
	component.queue_free()

	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	var node_names := ["TunnelDefault", "TunnelDiscovered", "TunnelCleared"]
	for index in STATE_IDS.size():
		var tunnel := demo.get_node_or_null(node_names[index]) as KWMap01MountainTunnel
		_check(tunnel != null, "Demo %s is not the reusable mountain-tunnel component" % node_names[index])
		if tunnel == null:
			continue
		_check(tunnel.scene_file_path == COMPONENT_PATH, "Demo %s is not sourced from the reusable component" % node_names[index])
		_check(tunnel.scale == Vector2(3.0, 3.0), "Demo %s must use approved 3x display" % node_names[index])
		_check(tunnel.get_state_id() == STATE_IDS[index], "Demo %s has the wrong frozen state" % node_names[index])
	_check(str(demo.call("get_selected_state_id")) == "TUNNEL_DEFAULT", "Mountain-tunnel demo must select TUNNEL_DEFAULT initially")
	demo.call("set_selected_roof_faded", true)
	_check(is_equal_approx(float(demo.call("get_selected_foreground_alpha")), 0.22), "Mountain-tunnel demo could not fade its selected roof")
	var marker := demo.get_node_or_null("Marker") as CanvasItem
	_check(marker != null and marker.z_index > 15, "Demo Marker must render above the tunnel roof")
	demo.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP01_MOUNTAIN_TUNNEL_VALIDATION_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP01_MOUNTAIN_TUNNEL_VALIDATION_FAILED: %d error(s)" % failures.size())
	quit(1)
