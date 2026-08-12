extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")
const MAIN_PREVIEW := "ling_pu_layout_godot.png"
const RECRUIT_PREVIEW := "ling_pu_recruit_layout_godot.png"
const UPGRADE_PREVIEW := "ling_pu_upgrade_layout_godot.png"

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
	camp.call("_open_ling_pu")
	await get_tree().process_frame
	await get_tree().process_frame

	var body := camp.get_node_or_null("Modal/LingPuPanelBody") as Control
	if body == null:
		# The runtime modal is intentionally unnamed; resolve its unique panel body.
		body = camp.find_child("LingPuPanelBody", true, false) as Control
	if body == null:
		_fail("LingPuPanelBody is missing")
		_finish()
		return
	_validate_rect(body.get_node_or_null("灵源院Title") as Control, Rect2(0, 41, 374, 27), "title")
	# Ark Pixel 12px 的 Godot 最小字框为 86×23；布局事实是左上角下移到 y=77。
	_validate_rect(body.get_node_or_null("IdleWorkerLabel") as Control, Rect2(248.5, 77, 86, 23), "idle worker label")
	_validate_rect(body.get_node_or_null("spiritGrainRowBackground") as Control, Rect2(51, 97.5, 272, 48), "grain row background")
	_validate_rect(body.get_node_or_null("spiritWoodRowBackground") as Control, Rect2(51, 175.5, 272, 48), "wood row background")
	_validate_rect(body.get_node_or_null("darkIronRowBackground") as Control, Rect2(51, 255.5, 272, 48), "iron row background")
	_validate_visual_rect(body.get_node_or_null("RecruitButton") as Button, Rect2(42, 558.5, 132, 44), "main recruit button")

	var output_dir := _capture_output_dir()
	if not output_dir.is_empty():
		await _capture(output_dir.path_join(MAIN_PREVIEW))

	var recruit := body.get_node_or_null("RecruitButton") as Button
	if recruit == null:
		_fail("main recruit button is missing")
	else:
		recruit.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_confirmation(camp, "招募杂役", "招募")
		if not output_dir.is_empty():
			await _capture(output_dir.path_join(RECRUIT_PREVIEW))

	camp.call("_close_ling_pu_confirmation")
	await get_tree().process_frame
	var upgrade := body.get_node_or_null("spiritGrainUpgradeButton") as Button
	if upgrade == null:
		_fail("grain upgrade button is missing")
	else:
		# Default profile has no spirit wood: clicking must still open the preview,
		# with a disabled confirmation instead of appearing unresponsive.
		upgrade.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_confirmation(camp, "灵粮储量升级", "升级")
		var insufficient_dialog := camp.find_child("DialogPanel", true, false) as Control
		var insufficient_confirm := insufficient_dialog.get_node_or_null("ConfirmButton") as Button if insufficient_dialog else null
		if insufficient_confirm == null or not insufficient_confirm.disabled:
			_fail("upgrade confirmation should be disabled without spirit wood")
		camp.call("_close_ling_pu_confirmation")
		await get_tree().process_frame

		var test_profile: Dictionary = game.get("profile")
		test_profile["wallet"]["spiritWood"] = 20
		game.set("profile", test_profile)
		upgrade.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_confirmation(camp, "灵粮储量升级", "升级")
		if not output_dir.is_empty():
			await _capture(output_dir.path_join(UPGRADE_PREVIEW))
		var upgrade_dialog := camp.find_child("DialogPanel", true, false) as Control
		var confirm := upgrade_dialog.get_node_or_null("ConfirmButton") as Button if upgrade_dialog else null
		if confirm == null or confirm.disabled:
			_fail("upgrade confirmation should be enabled with 20 spirit wood")
		else:
			confirm.emit_signal("pressed")
			await get_tree().process_frame
			await get_tree().process_frame
			if int(game.call("resource_capacity", "spiritGrain")) != 400:
				_fail("upgrade click did not raise spirit grain capacity to 400")
	_finish()

func _validate_confirmation(camp: Node, expected_title: String, expected_action: String) -> void:
	var overlay := camp.find_child("LingPuConfirmation", true, false) as Control
	if overlay == null:
		_fail("confirmation overlay did not open")
		return
	var dialog := overlay.get_node_or_null("DialogPanel") as Control
	_validate_rect(dialog, Rect2(24, 242, 327, 266), "confirmation panel")
	if dialog == null:
		return
	var title := dialog.get_node_or_null("DialogTitle") as Label
	if title == null or title.text != expected_title:
		_fail("confirmation title mismatch: %s" % expected_title)
	var confirm := dialog.get_node_or_null("ConfirmButton") as Button
	if confirm == null or confirm.text != expected_action:
		_fail("confirmation action mismatch: %s" % expected_action)
	_validate_visual_rect(confirm, Rect2(22, 272, 132, 44), "confirmation primary button")
	_validate_visual_rect(dialog.get_node_or_null("CancelButton") as Button, Rect2(173, 272, 132, 44), "confirmation cancel button")

func _validate_rect(control: Control, expected: Rect2, label: String) -> void:
	if control == null:
		_fail("%s is missing" % label)
		return
	var actual := Rect2(control.position, control.size)
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_fail("%s rect mismatch: expected %s, got %s" % [label, expected, actual])

func _validate_visual_rect(button: Button, expected: Rect2, label: String) -> void:
	if button == null:
		_fail("%s is missing" % label)
		return
	var visual := button.get_node_or_null("NativeVisual") as Control
	if visual == null:
		_fail("%s NativeVisual is missing" % label)
		return
	var actual := Rect2(button.position + visual.position, visual.size)
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_fail("%s visual rect mismatch: expected %s, got %s" % [label, expected, actual])

func _capture_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-ling-pu="):
			return argument.trim_prefix("--capture-ling-pu=")
	return ""

func _capture(path: String) -> void:
	await get_tree().process_frame
	var preview := get_viewport().get_texture().get_image()
	if preview.is_empty():
		_fail("capture returned an empty image: %s" % path)
		return
	if preview.get_size() != Vector2i(375, 817):
		preview.resize(375, 817, Image.INTERPOLATE_NEAREST)
	var save_error := preview.save_png(path)
	if save_error != OK:
		_fail("could not save preview %s: %s" % [path, error_string(save_error)])
	else:
		print("LING_PU_PREVIEW=%s" % path)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null

func _finish() -> void:
	if errors.is_empty():
		print("LING_PU_LAYOUT_VALIDATION_OK")
		get_tree().quit(0)
		return
	for message in errors:
		push_error(message)
	print("LING_PU_LAYOUT_VALIDATION_FAILED: %d error(s)" % errors.size())
	get_tree().quit(1)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
