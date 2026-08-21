extends SceneTree

const MANIFEST_PATH := "res://assets/maps/map_01/blockers/map01_blockers_manifest.json"
const DEMO_PATH := "res://scenes/map01_foreground_demo.tscn"

var failures: Array[String] = []


func _init() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_check(int(manifest.get("source_pixel_per_logical_cell", 0)) == 16, "Source pixel scale must be 16px per logical cell")
	_check(int(manifest.get("runtime_display_scale", 0)) == 3, "Runtime display scale must be 3x")
	var assets: Array = manifest.get("assets", [])
	_check(assets.size() == 16, "Expected 16 extracted C1/C2 sprites")
	var canvas_by_id: Dictionary = {}
	for asset_value in assets:
		var asset: Dictionary = asset_value
		var asset_id := str(asset.get("id", ""))
		var path := str(asset.get("path", ""))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(not image.is_empty(), "Could not load %s" % path)
		if image.is_empty():
			continue
		var alpha_values: Dictionary = {}
		for y in image.get_height():
			for x in image.get_width():
				alpha_values[roundi(image.get_pixel(x, y).a * 255.0)] = true
		_check(alpha_values.has(0) and alpha_values.has(255), "%s must contain transparent and opaque pixels" % asset_id)
		_check(alpha_values.size() == 2, "%s must use hard binary alpha" % asset_id)
		canvas_by_id[asset_id] = Vector2i(image.get_width(), image.get_height())

	_check_pair(canvas_by_id, "ridge_nw_se_base", "ridge_nw_se_foreground")
	_check_pair(canvas_by_id, "ridge_ne_sw_base", "ridge_ne_sw_foreground")
	_check_pair(canvas_by_id, "tunnel_stay_base", "tunnel_roof_foreground")
	_check_pair(canvas_by_id, "gate_stay_base", "gate_top_foreground")
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Foreground demo scene is missing")
	if ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		var scene := load(DEMO_PATH) as PackedScene
		var instance := scene.instantiate()
		_check(instance != null, "Foreground demo scene could not instantiate")
		if instance != null:
			root.add_child(instance)
			await process_frame
			_check(instance.get_node_or_null("BaseSprite") != null, "Demo base layer is missing")
			_check(instance.get_node_or_null("ForegroundSprite") != null, "Demo foreground layer is missing")
			_check(instance.get_node_or_null("Player") != null, "Demo player layer is missing")
			instance.queue_free()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Map01 blocker manifest is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_check(false, "Map01 blocker manifest is invalid JSON")
		return {}
	return parsed


func _check_pair(canvas_by_id: Dictionary, base_id: String, foreground_id: String) -> void:
	_check(canvas_by_id.has(base_id), "Missing pair base %s" % base_id)
	_check(canvas_by_id.has(foreground_id), "Missing pair foreground %s" % foreground_id)
	if canvas_by_id.has(base_id) and canvas_by_id.has(foreground_id):
		_check(canvas_by_id[base_id] == canvas_by_id[foreground_id], "%s pair canvases must match" % base_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Map01 blocker/foreground validation OK; 16 sprites and 4 matched fade pairs")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
