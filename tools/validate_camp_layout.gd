extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")

var errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		_fail("validation requires --no-profile-write")
		_finish()
		return
	var game: Node = get_tree().root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload is missing")
		_finish()
		return
	var defaults: Variant = _read_json("res://data/config/default_profile.json")
	if defaults is Dictionary:
		game.set("profile", defaults.duplicate(true))
	var camp := CAMP_SCENE.instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame

	var panorama := camp.get("panorama_scroll") as ScrollContainer
	if panorama == null:
		_fail("camp panorama scroll is missing")
		_finish()
		return
	_validate_building(camp, "huan_hun_tan", Rect2(38, 492, 206, 137), "还魂殿")
	_validate_building(camp, "portal", Rect2(421, 575, 206, 139), "传送阵")
	_validate_building(camp, "ling_pu", Rect2(724, 560, 247, 165), "灵源院")
	var capture_dir := _capture_output_dir()
	if not capture_dir.is_empty():
		for entry in [["left", 0], ["middle", 338], ["right", 675]]:
			panorama.scroll_horizontal = entry[1]
			await get_tree().process_frame
			await _capture(capture_dir.path_join("camp_%s_godot.png" % entry[0]))
	_finish()

func _validate_building(camp: Node, node_name: String, expected: Rect2, expected_label: String) -> void:
	var building := camp.find_child(node_name, true, false) as Control
	if building == null:
		_fail("camp building is missing: %s" % node_name)
		return
	var actual := Rect2(building.position, building.size)
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_fail("%s rect mismatch: expected %s, got %s" % [node_name, expected, actual])
	var label := building.get_node_or_null("NameLabel") as Label
	if label == null or label.text != expected_label:
		_fail("%s label mismatch: expected %s" % [node_name, expected_label])

func _capture_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-camp="):
			return argument.trim_prefix("--capture-camp=")
	return ""

func _capture(path: String) -> void:
	await get_tree().process_frame
	var preview: Image = get_viewport().get_texture().get_image()
	if preview == null or preview.is_empty():
		_fail("capture returned an empty image: %s" % path)
		return
	if preview.get_size() != Vector2i(375, 817):
		preview.resize(375, 817, Image.INTERPOLATE_NEAREST)
	var save_error := preview.save_png(path)
	if save_error != OK:
		_fail("could not save preview %s: %s" % [path, error_string(save_error)])
	else:
		print("CAMP_PREVIEW=%s" % path)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null

func _finish() -> void:
	if errors.is_empty():
		print("CAMP_LAYOUT_VALIDATION_OK")
		get_tree().quit(0)
		return
	for message in errors:
		push_error(message)
	print("CAMP_LAYOUT_VALIDATION_FAILED: %d error(s)" % errors.size())
	get_tree().quit(1)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
