@tool
extends VBoxContainer
var model = preload("res://addons/map01_terrain_editor/model.gd").new()
var canvas: Control
var status: Label
var play_button: Button
var zoom_slider: HSlider
var zoom_label: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The editor main screen is a Container; anchors alone do not expand us.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Map01 · 地形编辑    /    山谷地形：入口 → 废营 → 东西双路 → 北坡 → 山门"
	add_child(title)
	var bar := HBoxContainer.new()
	add_child(bar)
	var brush := OptionButton.new()
	for label in ["地面", "山道", "山石", "阶梯（沿格子 Y 方向）"]: brush.add_item(label)
	bar.add_child(brush)
	var flat := CheckButton.new()
	flat.text = "平面编辑"
	bar.add_child(flat)
	flat.toggled.connect(func(value):
		canvas.flat_view = value and not canvas.play_mode
		flat.set_pressed_no_signal(canvas.flat_view)
		canvas.queue_redraw()
	)
	var label := Label.new()
	label.text = "  高度层 "
	bar.add_child(label)
	var height := SpinBox.new()
	height.max_value = 5
	bar.add_child(height)
	for action in ["撤销", "重做", "适应全图", "保存地形"]:
		var button := Button.new()
		button.text = action
		bar.add_child(button)
		button.pressed.connect(_action.bind(action))
	play_button = Button.new()
	play_button.text = "试玩地形"
	bar.add_child(play_button)
	play_button.pressed.connect(func():
		canvas.set_play_mode(not canvas.play_mode)
		flat.set_pressed_no_signal(false)
		play_button.text = "返回编辑" if canvas.play_mode else "试玩地形"
	)
	var grid := CheckButton.new()
	grid.text = "网格"
	bar.add_child(grid)
	grid.toggled.connect(func(value): canvas.show_grid = value; canvas.queue_redraw())
	var view_bar := HBoxContainer.new()
	add_child(view_bar)
	for action in ["－ 缩小", "＋ 放大", "100%"]:
		var button := Button.new()
		button.text = action
		view_bar.add_child(button)
		button.pressed.connect(func():
			var value: float = 1.0 if action == "100%" else canvas.zoom*(1.25 if action == "＋ 放大" else 0.8)
			canvas.set_zoom(value,canvas.size*0.5)
		)
	zoom_slider = HSlider.new()
	zoom_slider.min_value = 5
	zoom_slider.max_value = 400
	zoom_slider.step = 1
	zoom_slider.custom_minimum_size.x = 220
	view_bar.add_child(zoom_slider)
	zoom_label = Label.new()
	view_bar.add_child(zoom_label)
	zoom_slider.value_changed.connect(func(value): canvas.set_zoom(value/100.0,canvas.size*0.5))
	var filter := OptionButton.new()
	for label_text in ["全部内容", "仅资源", "仅敌人", "仅剧情/入口", "仅休整区"]: filter.add_item(label_text)
	view_bar.add_child(filter)
	filter.item_selected.connect(func(index): canvas.content_filter = ["all","resource","enemy","story","rest"][index]; canvas.queue_redraw())
	var names := CheckButton.new()
	names.text = "全部名称"
	view_bar.add_child(names)
	names.toggled.connect(func(value): canvas.all_labels = value; canvas.queue_redraw())
	var help := Label.new()
	help.text = "绿色=资源，红色=敌人，金/青=剧情，蓝色=休整预留；试玩靠近按 E 查看，阵灯按 E 切换残破/激活候选。左键绘制 / 右键擦除 / 空格＋左键或中键拖动 / 滚轮、捏合缩放 / 双指平移。试玩支持 WASD / 点击寻路；不写玩家存档。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	canvas = preload("res://addons/map01_terrain_editor/canvas.gd").new()
	canvas.model = model
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(canvas)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	brush.item_selected.connect(func(index): canvas.kind = ["ground","road","rock","stairs"][index])
	height.value_changed.connect(func(value): canvas.height = int(value))
	canvas.view_changed.connect(_update_zoom)
	canvas.edited.connect(_refresh)
	canvas.play_status.connect(func(message): status.text = message)
	var error: Error = model.load_data()
	_refresh()
	if error != OK: status.text = "读取失败：" + error_string(error)
	canvas.call_deferred("fit")

func _refresh() -> void:
	status.text = "%d×%d 编辑范围 · %d 个地形单元 · %s · 尚未晋升运行地图" % [model.extent.x, model.extent.y, model.cells.size(), "有未保存修改" if model.cells != model.saved_cells else "已保存"]
	canvas.queue_redraw()

func _action(action: String) -> void:
	if canvas.play_mode:
		canvas.set_play_mode(false)
		play_button.text = "试玩地形"
	match action:
		"撤销": model.undo()
		"重做": model.redo()
		"适应全图": canvas.fit()
		"保存地形":
			var error: Error = model.save()
			if error != OK:
				status.text = "保存失败（外部地形已变化时请先备份当前修改）：" + error_string(error)
				return
	_refresh()

func _update_zoom() -> void:
	zoom_slider.set_value_no_signal(canvas.zoom*100.0)
	zoom_label.text = "%d%%" % roundi(canvas.zoom*100.0)
