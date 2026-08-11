class_name KWUI
extends RefCounted

const FONT = preload("res://assets/fonts/ark-pixel-12px-proportional-zh_cn.ttf")
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
