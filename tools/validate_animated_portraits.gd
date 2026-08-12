extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")
const COMBAT_SCENE = preload("res://scenes/combat.tscn")

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
	if not defaults is Dictionary:
		_fail("default profile could not be read")
		_finish()
		return
	game.set("profile", defaults.duplicate(true))

	var capture_dir: String = _capture_output_dir()
	var camp: Node = CAMP_SCENE.instantiate()
	add_child(camp)
	await get_tree().process_frame
	camp.call("_open_expedition")
	await get_tree().create_timer(0.5).timeout
	_validate_animation_list(camp.get("animated_portraits"), 3, "camp")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_camp.png"))
	camp.queue_free()
	await get_tree().process_frame

	game.set("profile", defaults.duplicate(true))
	game.get("profile")["expedition"] = {
		"mapId": "map_01",
		"partyPresetId": "party_01",
		"partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"],
		"temporaryLoot": {},
	}
	var combat: Node = COMBAT_SCENE.instantiate()
	add_child(combat)
	await get_tree().create_timer(0.5).timeout
	_validate_animation_list(combat.get("animated_portraits"), 3, "combat")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_combat.png"))
	combat.queue_free()
	await get_tree().process_frame
	_finish()

func _validate_animation_list(value: Variant, expected_count: int, context: String) -> void:
	if not value is Array:
		_fail("%s animated portrait list is missing" % context)
		return
	var animations: Array = value
	if animations.size() != expected_count:
		_fail("%s expected %d animated portraits, got %d" % [context, expected_count, animations.size()])
	for animation in animations:
		var portrait := animation.get("node") as TextureRect
		var frames: Array = animation.get("frames", [])
		if portrait == null or not is_instance_valid(portrait):
			_fail("%s animated portrait node is invalid" % context)
			continue
		if frames.size() != 8:
			_fail("%s expected 8 frames, got %d" % [context, frames.size()])
		if not portrait.size.is_equal_approx(Vector2(86, 149)):
			_fail("%s portrait size mismatch: %s" % [context, portrait.size])
		for frame in frames:
			if not frame.get_size().is_equal_approx(Vector2(86, 149)):
				_fail("%s frame size mismatch: %s" % [context, frame.get_size()])

func _capture_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-portraits="):
			return argument.trim_prefix("--capture-portraits=")
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
		print("ANIMATED_PORTRAIT_PREVIEW=%s" % path)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null

func _finish() -> void:
	if errors.is_empty():
		print("ANIMATED_PORTRAIT_VALIDATION_OK")
		get_tree().quit(0)
		return
	for message in errors:
		push_error(message)
	print("ANIMATED_PORTRAIT_VALIDATION_FAILED: %d error(s)" % errors.size())
	get_tree().quit(1)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
