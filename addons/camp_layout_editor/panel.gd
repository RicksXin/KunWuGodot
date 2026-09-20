@tool
extends VBoxContainer
const Model = preload("res://addons/camp_layout_editor/model.gd")
const Canvas = preload("res://addons/camp_layout_editor/canvas.gd")
var model := Model.new()
var canvas: Control
var choice: OptionButton
var x_field: SpinBox
var y_field: SpinBox
var width_field: SpinBox
var angle_field: SpinBox
var status: Label
var loading := false
var mirror: CheckButton
var view_choice: OptionButton
var save_button: Button
func button(row: Control, title: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.pressed.connect(action)
	row.add_child(b)
	return b
func number(row: Control, title: String, minimum: float, maximum: float) -> SpinBox:
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.custom_minimum_size.x = 80
	row.add_child(field)
	return field
func _ready() -> void:
	if not Engine.is_editor_hint():
		get_window().content_scale_size = Vector2i(1440,900)
		get_window().size = Vector2i(1440,900)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	add_child(row)
	choice = OptionButton.new()
	row.add_child(choice)
	x_field = number(row,"格 X",-1000,1000)
	y_field = number(row,"Y",-1000,1000)
	width_field = number(row,"显示宽",10,2000)
	button(row,"撤销",func(): model.undo(); sync(); report())
	save_button = button(row,"保存 JSON",save)
	button(row,"重新读取",reload_confirm)
	button(row,"适应地图",func(): canvas.fit())
	var rotation_row := HBoxContainer.new()
	add_child(rotation_row)
	angle_field = number(rotation_row,"贴图旋转（°）",-360,360)
	angle_field.step = 0.1
	angle_field.custom_minimum_size.x = 110
	angle_field.value_changed.connect(rotate_building)
	button(rotation_row,"−1°",func(): angle_field.value -= 1.0)
	button(rotation_row,"＋1°",func(): angle_field.value += 1.0)
	button(rotation_row,"归零",func(): angle_field.value = 0.0)
	var rotation_note := Label.new()
	rotation_note.text = "绕门口锚点旋转，可输入0.1°；只转贴图，不生成新侧面，占地与入口保持原位。"
	rotation_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotation_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_row.add_child(rotation_note)
	var instructions := Label.new()
	instructions.text = "左键拖建筑；滚轮/捏合/＋－缩放；双指滑动或右键平移。任何位置均可保存，通路问题仅提示。"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(instructions)
	var controls := HBoxContainer.new()
	add_child(controls)
	button(controls,"－",func(): canvas.zoom_at(1.0/1.25,canvas.size*0.5))
	button(controls,"＋",func(): canvas.zoom_at(1.25,canvas.size*0.5))
	button(controls,"100%",func(): canvas.zoom_at(1.0/canvas.zoom,canvas.size*0.5))
	mirror = CheckButton.new()
	mirror.text = "水平翻转"
	mirror.toggled.connect(func(value):
		if loading or model.data.is_empty(): return
		model.checkpoint()
		model.data.buildings[choice.selected].mirror_x = value
		model.dirty = true
		canvas.refresh()
		report())
	controls.add_child(mirror)
	view_choice = OptionButton.new()
	view_choice.add_item("现有视角")
	view_choice.item_selected.connect(change_view)
	controls.add_child(view_choice)
	var grid := CheckButton.new()
	grid.text = "网格与院路"
	grid.button_pressed = true
	grid.toggled.connect(func(value): canvas.show_grid=value; canvas.queue_redraw())
	controls.add_child(grid)
	var ghost := CheckButton.new()
	ghost.text = "半透明建筑（查看占地）"
	ghost.toggled.connect(func(value): canvas.translucent=value; canvas.refresh())
	controls.add_child(ghost)
	var note := Label.new()
	note.text = "翻转为左右面向；招贤馆另有正/背面。"
	controls.add_child(note)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	canvas = Canvas.new()
	canvas.model = model
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(400,350)
	add_child(canvas)
	choice.item_selected.connect(select)
	canvas.selected.connect(select)
	canvas.moved.connect(move)
	x_field.value_changed.connect(func(_v): numeric_move())
	y_field.value_changed.connect(func(_v): numeric_move())
	width_field.value_changed.connect(func(v):
		if loading or model.data.is_empty(): return
		model.checkpoint()
		model.data.buildings[choice.selected].display_width = v
		model.dirty = true
		canvas.refresh()
		report())
	reload()
	canvas.call_deferred("fit")
func reload() -> void:
	var error := model.load_file()
	if not error.is_empty(): status.text=error; return
	choice.clear()
	for b in model.data.buildings: choice.add_item(b.name+("（隐藏）" if not b.get("preview_visible",false) else ""))
	select(0)
	report()
func reload_confirm() -> void:
	if not model.dirty: reload(); return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "放弃尚未保存的摆放并读取磁盘布局？"
	add_child(dialog)
	dialog.confirmed.connect(func(): reload(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
func select(index: int) -> void:
	choice.select(index)
	canvas.active = index
	sync()
func sync() -> void:
	if model.data.is_empty(): return
	loading = true
	var item: Dictionary = model.data.buildings[choice.selected]
	x_field.value = item.origin[0]
	y_field.value = item.origin[1]
	width_field.value = item.get("display_width",220)
	angle_field.value = item.get("rotation_degrees",0.0)
	mirror.button_pressed = item.get("mirror_x",false)
	view_choice.clear()
	if item.id=="recruit":
		view_choice.add_item("招贤馆·正面")
		view_choice.add_item("招贤馆·背面")
		view_choice.select(1 if "recruit-rear" in item.texture else 0)
		view_choice.disabled = false
	else:
		view_choice.add_item("当前素材视角")
		view_choice.disabled = true
	loading = false
	canvas.refresh()
func move(index: int, delta: Vector2i) -> void:
	if delta==Vector2i.ZERO: return
	model.checkpoint()
	model.translate(index,delta)
	sync()
	report()
func numeric_move() -> void:
	if loading or model.data.is_empty(): return
	var item: Dictionary = model.data.buildings[choice.selected]
	move(choice.selected,Vector2i(int(x_field.value)-int(item.origin[0]),int(y_field.value)-int(item.origin[1])))
func report() -> void:
	var errors := model.validate()
	save_button.disabled = not model.dirty
	status.modulate = Color("ffbb77") if not errors.is_empty() else Color("99ddbb")
	status.text = ("未保存 · " if model.dirty else "与磁盘一致 · ")+("通路检查通过" if errors.is_empty() else "可保存，通路提示："+"；".join(errors.slice(0,4)))
func save() -> void:
	var error := model.save()
	if not error.is_empty(): status.text=error; return
	report()
	status.text = "已保存 camp_tile_rebuild.json；重新运行营地实验查看效果。"
	if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().scan()

func change_view(index: int) -> void:
	if loading or model.data.is_empty(): return
	var item: Dictionary = model.data.buildings[choice.selected]
	if item.id!="recruit": return
	model.checkpoint()
	# Preserve the existing visual base while swapping the authored directional sprite.
	var old_anchor := Vector2(item.door_anchor[0],item.door_anchor[1])
	var old_texture: Texture2D = load(item.texture)
	var old_base := Vector2(768,840) if "recruit-rear" in item.texture else Vector2(768,900)
	var offset: Array = item.get("visual_offset",[0,0])
	var signs := Vector2(-1 if item.get("mirror_x",false) else 1,1)
	var rotation := deg_to_rad(float(item.get("rotation_degrees",0.0)))
	var base_position := Vector2(offset[0],offset[1])+((old_base-old_anchor)*float(item.display_width)/old_texture.get_width()*signs).rotated(rotation)
	item.texture = "res://resources/prototypes/camp_west_buildings_v4/recruit.png" if index==0 else "res://resources/prototypes/camp_west_inward_v1/recruit-rear.png"
	item.door_anchor = [850,930] if index==0 else [1395,530]
	var new_base := Vector2(768,900) if index==0 else Vector2(768,840)
	var next_offset := base_position-((new_base-Vector2(item.door_anchor[0],item.door_anchor[1]))*float(item.display_width)/1536.0*signs).rotated(rotation)
	item.visual_offset = [next_offset.x,next_offset.y]
	model.dirty = true
	sync()
	report()

func rotate_building(angle: float) -> void:
	if loading or model.data.is_empty(): return
	var item: Dictionary = model.data.buildings[choice.selected]
	if is_equal_approx(float(item.get("rotation_degrees",0.0)),angle): return
	model.checkpoint()
	item.rotation_degrees = angle
	model.dirty = true
	canvas.refresh()
	report()
