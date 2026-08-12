class_name KWUI
extends RefCounted

const FONT = preload("res://assets/fonts/ark-pixel-12px-proportional-zh_cn.ttf")
const CAMP_BUTTON_VISUAL = preload("res://scripts/ui/camp_button_visual.gd")
const BG = Color("#071016")
const PANEL = Color("#111e25")
const PANEL_2 = Color("#172b31")
const BORDER = Color("#6f897e")
const TEXT = Color("#e8edcf")
const MUTED = Color("#9aa995")
const TEAL = Color("#4dd5c0")
const GOLD = Color("#e7b75b")
const RED = Color("#e66a59")

static func style_box(color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(width if border_color != Color.TRANSPARENT else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

static func panel(parent: Node, rect: Rect2, color: Color = PANEL, border: Color = BORDER) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style_box(color, border))
	parent.add_child(node)
	return node

static func label(parent: Node, text: String, rect: Rect2, size: int = 14, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, rect: Rect2, size: int = 14) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_stylebox_override("normal", style_box(PANEL_2, BORDER, 5, 1))
	node.add_theme_stylebox_override("hover", style_box(Color("#23474a"), TEAL, 5, 1))
	node.add_theme_stylebox_override("pressed", style_box(Color("#315b57"), GOLD, 5, 1))
	node.add_theme_stylebox_override("disabled", style_box(Color("#0d1519"), Color("#394841"), 5, 1))
	parent.add_child(node)
	return node

static func camp_button(parent: Node, text: String, rect: Rect2, kind := "footer", selected := false, size: int = 14) -> Button:
	# Keep the original visual dimensions while restoring the Cocos/Figma
	# contract that every compact button has a touch target of at least 48px.
	var touch_size := Vector2(maxf(48.0, rect.size.x), maxf(48.0, rect.size.y))
	var touch_rect := Rect2(rect.position + (rect.size - touch_size) / 2.0, touch_size)
	var node := button(parent, text, touch_rect, size)
	node.add_theme_color_override("font_color", Color8(232, 220, 187))
	node.add_theme_color_override("font_hover_color", Color8(232, 220, 187))
	node.add_theme_color_override("font_pressed_color", Color8(232, 220, 187))
	node.add_theme_color_override("font_disabled_color", Color8(94, 106, 102))
	node.add_theme_constant_override("outline_size", 1)
	node.add_theme_color_override("font_outline_color", Color8(7, 10, 10, 220))
	var visual := CAMP_BUTTON_VISUAL.new() as KWCampButtonVisual
	node.add_child(visual)
	visual.configure(node, kind, selected, rect.size)
	return node

static func map_button(parent: Node, text: String, rect: Rect2, size: int = 14) -> Button:
	var node := button(parent, text, rect, size)
	var normal := _button_box(Color8(66, 82, 76), Color8(132, 151, 126), 4)
	var disabled := _button_box(Color8(46, 51, 50), Color8(132, 151, 126), 4)
	_apply_button_boxes(node, normal, normal, normal, disabled)
	node.add_theme_color_override("font_color", Color8(236, 230, 202))
	node.add_theme_color_override("font_hover_color", Color8(236, 230, 202))
	node.add_theme_color_override("font_pressed_color", Color8(236, 230, 202))
	node.add_theme_color_override("font_disabled_color", Color8(236, 230, 202))
	_bind_press_scale(node)
	return node

static func combat_button(parent: Node, text: String, rect: Rect2, size: int = 13) -> Button:
	var node := button(parent, text, rect, size)
	var normal := _button_box(Color8(56, 71, 67, 250), Color8(143, 126, 78), 3)
	# Cocos applied opacity 135 to the complete normal button when disabled.
	var disabled := _button_box(Color8(56, 71, 67, 132), Color8(143, 126, 78, 135), 3)
	_apply_button_boxes(node, normal, normal, normal, disabled)
	node.add_theme_color_override("font_color", Color8(235, 230, 207))
	node.add_theme_color_override("font_hover_color", Color8(235, 230, 207))
	node.add_theme_color_override("font_pressed_color", Color8(235, 230, 207))
	node.add_theme_color_override("font_disabled_color", Color8(235, 230, 207, 135))
	_bind_press_scale(node)
	return node

static func set_map_button_disabled(node: Button, disabled: bool) -> void:
	_set_button_disabled(node, disabled, 0.96)

static func set_combat_button_disabled(node: Button, disabled: bool) -> void:
	_set_button_disabled(node, disabled, 0.97)

static func _button_box(fill: Color, stroke: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	box.corner_detail = 1
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box

static func _apply_button_boxes(node: Button, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox) -> void:
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("hover_pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func _bind_press_scale(node: Button) -> void:
	node.focus_mode = Control.FOCUS_NONE
	node.set_meta("kw_rest_scale", Vector2.ONE)
	node.pivot_offset = node.size / 2.0
	node.resized.connect(func(): node.pivot_offset = node.size / 2.0)
	node.button_down.connect(func(): _scale_button(node, Vector2(0.96, 0.96)))
	node.button_up.connect(func(): _scale_button(node, node.get_meta("kw_rest_scale", Vector2.ONE)))

static func _set_button_disabled(node: Button, disabled: bool, disabled_scale: float) -> void:
	if not is_instance_valid(node):
		return
	node.disabled = disabled
	var rest_scale := Vector2(disabled_scale, disabled_scale) if disabled else Vector2.ONE
	node.set_meta("kw_rest_scale", rest_scale)
	if node.scale.is_equal_approx(rest_scale):
		return
	var previous: Variant = node.get_meta("kw_press_tween") if node.has_meta("kw_press_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	node.scale = rest_scale

static func _scale_button(node: Button, target: Vector2) -> void:
	if not is_instance_valid(node):
		return
	var previous: Variant = node.get_meta("kw_press_tween") if node.has_meta("kw_press_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := node.create_tween()
	node.set_meta("kw_press_tween", tween)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", target, 0.1)

static func texture(parent: Node, path: String, rect: Rect2, expand := true) -> TextureRect:
	var node := TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if expand else TextureRect.EXPAND_KEEP_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(node)
	return node

static func divider(parent: Node, rect: Rect2, color := Color("#314b48")) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	parent.add_child(node)
	return node

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

static func set_button_icon(button_node: Button, path: String) -> void:
	var image := load(path)
	if image is Texture2D:
		# 交付图可以与逻辑显示尺寸不同（例如 72px 素材显示为 24px）。
		# Button.icon 会使用原始像素，因此用子 TextureRect 明确控制尺寸。
		button_node.icon = null
		var icon_node := TextureRect.new()
		icon_node.position = Vector2((button_node.size.x - 30.0) / 2.0, 4)
		icon_node.size = Vector2(30, 30)
		icon_node.texture = image
		icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_node.add_child(icon_node)
