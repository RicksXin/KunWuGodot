extends "res://scripts/ui/market_panel.gd"

## Reuses reviewed panel primitives and read-only notices; no crafting commands.
const RECIPES := [
	["五行法器制式", "法", "材料齐全", "Lv7–12 · 最高上品 · 七维随机", "打造", 2],
	["剑器制式", "剑", "材料齐全", "Lv7–12 · 最高上品 · 七维随机", "打造", 2],
	["玄甲制式", "甲", "材料不足", "Lv7–12 · 最高上品 · 七维随机", "材料不足", 2],
	["雷纹珠", "雷", "核心齐全", "上品特装 · 固定效果 · 七维随机", "打造", 2],
	["开山镐", "img", "材料齐全", "探索工具 · 消耗品 · 查看消耗", "制作", 0],
	["探灵镜", "img1", "未解锁", "探索工具 · 消耗品 · 配方未解锁", "未解锁", 1]
]
var recipe_buttons: Array[Button] = []
var selected_recipe := 0
var recipe_title: Label
var recipe_rule: Label
var recipe_backgrounds: Array[TextureRect] = []

func _build() -> void:
	name = "ForgePanel"
	var shade := ColorRect.new()
	shade.color = Color(0.0392, 0.0588, 0.0549, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_crop("imgPanelLevel2", Rect2(20, 110, 335, 565), Rect2(-0.0714, -0.2803, 1.1429, 1.5657))
	_crop("imgPanelDecorationTop", Rect2(8, 78, 359, 65), Rect2(-0.1116, -1.652, 1.2239, 4.511))
	_crop("imgPanelDecorationBottom", Rect2(8, 628, 359, 55), Rect2(-0.1497, -2.15, 1.2995, 5.6889))
	_label(self, "炼器坊", Rect2(8, 110, 359, 24), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(self, "已解锁配方 12 / 18", Rect2(32, 150, 150, 18), 12)
	var dot := KWUI.panel(self, Rect2(216, 156, 6, 6), Color("#6f945f"), Color.TRANSPARENT)
	dot.add_theme_stylebox_override("panel", KWUI.style_box(Color("#6f945f"), Color.TRANSPARENT, 3, 0))
	_label(self, "打造固定成功", Rect2(227, 150, 116, 18), 12, Color("#6f945f"), HORIZONTAL_ALIGNMENT_RIGHT)
	for i in 4:
		var tab := _button(self, ["打造", "重铸", "分解", "配方"][i], Rect2(32 + i * 79, 178, 72, 28), "inline", i == 0, 12)
		tab.name = "ForgeTab%d" % i
		tab.pressed.connect(_forge_tab.bind(i))
	var filter := KWUI.panel(self, Rect2(32, 214, 311, 24), Color("#202a27"), Color("#80623a"))
	filter.add_theme_stylebox_override("panel", KWUI.style_box(Color("#202a27"), Color("#80623a"), 0, 1))
	_label(filter, "制式装备 · Lv7–12 · 默认按等级", Rect2(8, 0, 295, 24), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	for i in RECIPES.size(): _recipe_row(i)
	var detail := Control.new()
	detail.position = Vector2(32, 555)
	detail.size = Vector2(272, 62)
	add_child(detail)
	_row_background(detail, false, Rect2(0, 0, 272, 62))
	var stripe := ColorRect.new()
	stripe.position = Vector2(10, 9)
	stripe.size = Vector2(3, 44)
	stripe.color = Color("#58b9b4")
	detail.add_child(stripe)
	recipe_title = _label(detail, "当前配方 · 五行法器制式", Rect2(20, 4, 242, 18), 12)
	recipe_rule = _label(detail, "Lv7–12 · 凡品 / 精制 / 上品 · 七维随机", Rect2(20, 23, 242, 15), 10, MUTED)
	_label(detail, "固定成功；最终品质与七维在打造后生成", Rect2(20, 41, 242, 15), 10, Color("#be883a"))
	for i in 3:
		var button := _button(self, ["整件重铸", "批量分解", "关闭"][i], Rect2(27 + i * 110, 718, 100, 44), "footer", false, 14)
		button.name = "ForgeFooter%d" % i
		if i == 2: button.pressed.connect(func(): closed.emit())
		else: button.pressed.connect(_forge_tab.bind(i + 1))

func _row_background(parent: Node, selected: bool, rect: Rect2) -> TextureRect:
	var art := KWUI.texture(parent, "res://assets/camp/ui/market/row_selected.png" if selected else "res://assets/camp/ui/market/row.png", rect)
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

func _recipe_row(index: int) -> void:
	var data: Array = RECIPES[index]
	var row := Control.new()
	row.name = "Recipe%d" % index
	row.position = Vector2(52, 244 + index * 51)
	row.size = Vector2(272, 48)
	add_child(row)
	recipe_backgrounds.append(_row_background(row, index == 0, Rect2(0, 0, 272, 48)))
	var select := Button.new()
	select.flat = true
	select.size = Vector2(194, 48)
	select.focus_mode = Control.FOCUS_NONE
	row.add_child(select)
	select.pressed.connect(_select_recipe.bind(index))
	_image(row, "imgQuality", Rect2(6, 4, 40, 40))
	var color: Color = [INK, Color("#6f945f"), Color("#4b83b8")][int(data[5])]
	var rim := KWUI.panel(row, Rect2(9, 7, 34, 34), Color.TRANSPARENT, color)
	rim.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, color, 4, 1))
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if index < 4: _label(row, data[1], Rect2(12, 9, 28, 28), 18, Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var art := _image(row, data[1], Rect2(14, 12, 24, 24))
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_label(row, data[0], Rect2(54, 2, 84, 17), 12)
	_label(row, data[2], Rect2(142, 2, 50, 16), 9, Color("#be883a") if index == 2 else (MUTED if index == 5 else Color("#6f945f")), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(row, data[3], Rect2(54, 29, 138, 14), 9, MUTED)
	var button := _button(row, data[4], Rect2(196, 10, 72, 28), "inline", false, 12)
	button.name = "Craft"
	button.disabled = index in [2, 5]
	if button.disabled:
		var old := button.get_node("NativeVisual")
		button.remove_child(old)
		old.queue_free()
		var visual := MarketDisabledVisual.new()
		button.add_child(visual)
		visual.configure(button, "inline", false, Vector2(72, 28))
		button.add_theme_color_override("font_disabled_color", Color("#5e6a66"))
	button.pressed.connect(func(): _select_recipe(index); _show_notice("%s\n打造功能尚未开放，当前为设计预览。" % data[0]))
	recipe_buttons.append(button)

func _select_recipe(index: int) -> void:
	selected_recipe = index
	for i in recipe_backgrounds.size():
		recipe_backgrounds[i].texture = load("res://assets/camp/ui/market/row_selected.png" if i == index else "res://assets/camp/ui/market/row.png")
	recipe_title.text = "当前配方 · " + str(RECIPES[index][0])
	recipe_rule.text = "Lv7–12 · 凡品 / 精制 / 上品 · 七维随机" if index < 4 else str(RECIPES[index][3])

func _forge_tab(index: int) -> void:
	if index == 0: return
	_show_notice(["", "当前规则不支持重铸。\n此按钮仅保留设计稿外观。", "批量分解尚未开放。\n当前材料和装备不会变更。", "当前为配方设计预览。\n正式配方与解锁条件尚未接入。"][index])

func _label(parent: Node, text: String, rect: Rect2, font_size := 12, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	# Set the final font before layout so the shared pixel font cannot inflate
	# the initial minimum box. Figma text here has a fixed single-line width.
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	label.clip_text = true
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = rect.size
	label.position = rect.position - Vector2(0, maxf(0, label.get_minimum_size().y - rect.size.y) / 2.0)
	parent.add_child(label)
	return label
