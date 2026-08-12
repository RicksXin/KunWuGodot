extends SceneTree

const UI = preload("res://scripts/ui/ui.gd")
const PREVIEW_PATH := "res://Docs/Artifacts/button_style_preview_godot.png"

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(375, 817)
	get_root().add_child(canvas)
	var background := ColorRect.new()
	background.color = Color8(10, 17, 16)
	background.position = Vector2.ZERO
	background.size = canvas.size
	canvas.add_child(background)

	UI.label(canvas, "营地面板按钮 · Godot 还原预览", Rect2(20, 28, 335, 34), 17, Color8(232, 220, 187), HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(canvas, "行内按钮 72×28", Rect2(24, 82, 327, 22), 12, Color8(145, 164, 158))
	var inline_default := UI.camp_button(canvas, "升级", Rect2(24, 112, 72, 28), "inline", false, 13)
	var inline_selected := UI.camp_button(canvas, "选择", Rect2(151.5, 112, 72, 28), "inline", true, 13)
	var inline_disabled := UI.camp_button(canvas, "调息", Rect2(279, 112, 72, 28), "inline", false, 13)
	inline_disabled.disabled = true

	UI.label(canvas, "底部按钮 132×44", Rect2(24, 174, 327, 22), 12, Color8(145, 164, 158))
	var footer_default := UI.camp_button(canvas, "返回", Rect2(24, 204, 132, 44), "footer", false, 14)
	var footer_selected := UI.camp_button(canvas, "确认", Rect2(219, 204, 132, 44), "footer", true, 14)
	var footer_disabled := UI.camp_button(canvas, "当前不可传送", Rect2(83, 270, 209, 44), "footer", false, 13)
	footer_disabled.disabled = true

	UI.label(canvas, "地图按钮", Rect2(24, 346, 327, 22), 12, Color8(145, 164, 158))
	var map_default := UI.map_button(canvas, "休整", Rect2(24, 376, 150, 48), 14)
	var map_disabled := UI.map_button(canvas, "归营", Rect2(201, 376, 150, 48), 14)
	UI.set_map_button_disabled(map_disabled, true)

	UI.label(canvas, "战斗按钮", Rect2(24, 454, 327, 22), 12, Color8(145, 164, 158))
	var combat_default := UI.combat_button(canvas, "技能", Rect2(24, 484, 150, 44), 13)
	var combat_disabled := UI.combat_button(canvas, "冷却", Rect2(201, 484, 150, 44), 13)
	UI.set_combat_button_disabled(combat_disabled, true)

	await process_frame
	await process_frame
	_validate_camp_button(inline_default, "inline", false)
	_validate_camp_button(inline_selected, "inline", true)
	_validate_camp_button(footer_default, "footer", false)
	_validate_camp_button(footer_selected, "footer", true)
	_validate_camp_visual_size(inline_default, Vector2(72, 28))
	_validate_camp_visual_size(footer_default, Vector2(132, 44))
	_validate_stylebox_color(map_default, Color8(66, 82, 76), "map default")
	_validate_stylebox_color(combat_default, Color8(56, 71, 67, 250), "combat default")
	if map_disabled.get_theme_stylebox("disabled") == null:
		_fail("map disabled style is missing")
	if combat_disabled.get_theme_stylebox("disabled") == null:
		_fail("combat disabled style is missing")
	if not map_disabled.scale.is_equal_approx(Vector2(0.96, 0.96)):
		_fail("map disabled scale mismatch")
	if not combat_disabled.scale.is_equal_approx(Vector2(0.97, 0.97)):
		_fail("combat disabled scale mismatch")

	if OS.get_cmdline_user_args().has("--capture-button-preview"):
		await process_frame
		var preview := get_root().get_texture().get_image()
		if preview.is_empty():
			_fail("button preview capture returned an empty image")
		else:
			if preview.get_size() != Vector2i(375, 817):
				preview.resize(375, 817, Image.INTERPOLATE_NEAREST)
			var save_error := preview.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
			if save_error != OK:
				_fail("could not save button preview: %s" % error_string(save_error))
			else:
				print("BUTTON_STYLE_PREVIEW=%s" % PREVIEW_PATH)

	canvas.queue_free()
	await process_frame
	if errors.is_empty():
		print("BUTTON_STYLE_VALIDATION_OK")
		quit(0)
		return
	for message in errors:
		push_error(message)
	print("BUTTON_STYLE_VALIDATION_FAILED: %d error(s)" % errors.size())
	quit(1)

func _validate_camp_button(button: Button, expected_kind: String, expected_selected: bool) -> void:
	var visual := button.get_node_or_null("NativeVisual") as KWCampButtonVisual
	if visual == null:
		_fail("camp button is missing NativeVisual")
		return
	if visual.kind != expected_kind:
		_fail("camp button kind mismatch: %s" % expected_kind)
	if visual.selected != expected_selected:
		_fail("camp button selected state mismatch")
	if button.size.x < 48.0 or button.size.y < 48.0:
		_fail("preview camp button touch target is unexpectedly small")

func _validate_camp_visual_size(button: Button, expected: Vector2) -> void:
	var visual := button.get_node_or_null("NativeVisual") as KWCampButtonVisual
	if visual == null:
		return
	if not visual.size.is_equal_approx(expected):
		_fail("camp button visual size mismatch: expected %s, got %s" % [expected, visual.size])

func _validate_stylebox_color(button: Button, expected: Color, label: String) -> void:
	var box := button.get_theme_stylebox("normal") as StyleBoxFlat
	if box == null or not box.bg_color.is_equal_approx(expected):
		_fail("%s style color mismatch" % label)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
