extends Control
## Isolated authoring experiment; no camp commands or profile mutations.

const VIEW := Vector2i(817, 375)
const MAP_WIDTH := 1280.0
const WORLD_SCALE := 0.85
const INITIAL_SCROLL := (MAP_WIDTH * WORLD_SCALE - VIEW.x) / 2.0
const EDIT_RECT := Rect2(0, 44, 817, 287)
@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $World/Ground
@onready var paths: TileMapLayer = $World/Paths
@onready var water: TileMapLayer = $World/Water
@onready var buildings: Node2D = $World/Buildings
@onready var effects: Node2D = $World/Effects
var mode := "pan"
var dragging := false
var selected: Sprite2D
var initial_cells: Dictionary = {}
var initial_positions: Dictionary = {}
var scroll: HSlider
var status: Label
var camp: Control
var previous_profile_write_suppression := true
var previous_content := Vector2i.ZERO
var previous_size := Vector2i.ZERO
var previous_position := Vector2i.ZERO
var previous_orientation := DisplayServer.SCREEN_PORTRAIT

func _enter_tree() -> void:
	previous_content = get_window().content_scale_size
	get_window().content_scale_size = VIEW
	if OS.has_feature("mobile"):
		previous_orientation = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	elif DisplayServer.get_name() != "headless":
		previous_size = DisplayServer.window_get_size()
		previous_position = DisplayServer.window_get_position()
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect()
			var factor := minf(1.5, minf((usable.size.x - 40.0) / VIEW.x, (usable.size.y - 40.0) / VIEW.y))
			var target := Vector2i(Vector2(VIEW) * factor)
			DisplayServer.window_set_size(target)
			DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)

func _ready() -> void:
	previous_profile_write_suppression = Game.suppress_profile_writes
	Game.suppress_profile_writes = true
	for layer in [ground, paths, water]:
		var cells: Dictionary = {}
		for cell in layer.get_used_cells():
			cells[cell] = layer.get_cell_atlas_coords(cell)
		initial_cells[layer.name] = cells
	for building in buildings.get_children():
		initial_positions[building.name] = building.position
	_build_hud()

func _exit_tree() -> void:
	get_window().content_scale_size = previous_content
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(previous_orientation)
	elif DisplayServer.get_name() != "headless" and previous_size != Vector2i.ZERO:
		DisplayServer.window_set_size(previous_size)
		DisplayServer.window_set_position(previous_position)
	Game.suppress_profile_writes = previous_profile_write_suppression
	if is_instance_valid(camp):
		camp.process_mode = Node.PROCESS_MODE_INHERIT
		camp.show()

func _return_to_camp() -> void:
	if is_instance_valid(camp):
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/camp.tscn")

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "LabHUD"
	add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color("17262c")
	panel.size = Vector2(817, 44)
	hud.add_child(panel)
	_label(panel, "营地 · TileMap 实验", Vector2(12, 9), 18)
	var back := Button.new()
	back.name = "ReturnToCampButton"
	back.text = "返回营地"
	back.position = Vector2(725, 5)
	back.size = Vector2(80, 34)
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(_return_to_camp)
	panel.add_child(back)
	var row := HBoxContainer.new()
	row.position = Vector2(265, 4)
	panel.add_child(row)
	var group := ButtonGroup.new()
	for item in [["浏览", "pan"], ["草地", "grass"], ["石路", "stone"], ["泥地", "soil"], ["水面", "water"], ["摆放", "building"]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(54, 36)
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = item[1] == mode
		button.pressed.connect(func():
			mode = item[1]
			status.text = "拖动查看营地" if mode == "pan" else ("拖动建筑调整位置" if mode == "building" else "按住拖动绘制；草地可擦除道路与水面")
		)
		row.add_child(button)
	var bottom := ColorRect.new()
	bottom.position = Vector2(0, 331)
	bottom.size = Vector2(817, 44)
	bottom.color = Color("17262c")
	hud.add_child(bottom)
	status = _label(bottom, "拖动查看营地", Vector2(12, 4), 11)
	scroll = HSlider.new()
	scroll.step = 0.1
	scroll.position = Vector2(350, 12)
	scroll.size = Vector2(160, 22)
	scroll.max_value = MAP_WIDTH * WORLD_SCALE - VIEW.x
	scroll.value = -world.position.x
	scroll.value_changed.connect(func(value: float): world.position.x = -value)
	bottom.add_child(scroll)
	var toggle := CheckButton.new()
	toggle.text = "水波 / 阵光 / 炊烟"
	toggle.position = Vector2(523, 5)
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.button_pressed = true
	toggle.toggled.connect(func(enabled: bool):
		effects.set("enabled", enabled)
		(water.material as ShaderMaterial).set_shader_parameter("animated", enabled)
	)
	bottom.add_child(toggle)
	var reset := Button.new()
	reset.text = "复位"
	reset.position = Vector2(738, 5)
	reset.size = Vector2(68, 32)
	reset.pressed.connect(reset_layout)
	bottom.add_child(reset)
	_label(bottom, "占位地形 · 修改仅本次有效 · 不写入存档", Vector2(12, 24), 10)

func _label(parent: Node, text: String, point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0e8d9"))
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = false
			selected = null
			return
		if not EDIT_RECT.has_point(event.position): return
		dragging = true
		if mode == "building":
			var candidates := buildings.get_children()
			candidates.reverse()
			for building: Sprite2D in candidates:
				if building.get_rect().has_point(building.to_local(event.position)):
					selected = building
					break
		elif mode != "pan":
			paint_at(event.position)
	elif event is InputEventMouseMotion and dragging:
		# A release on the HUD still terminates the stroke on the next motion.
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			dragging = false
			selected = null
			return
		if not EDIT_RECT.has_point(event.position): return
		if mode == "pan":
			scroll.value -= event.relative.x
		elif mode == "building" and is_instance_valid(selected):
			selected.position += event.relative / world.scale
			selected.position = selected.position.clamp(Vector2(32, 85), Vector2(1248, 270))
		elif mode != "building":
			# Interpolate quick strokes so skipped mouse events don't leave holes.
			var steps := maxi(1, ceili(event.relative.length() / 8.0))
			for index in range(steps + 1):
				paint_at(event.position - event.relative * (float(index) / steps))

func paint_at(screen_point: Vector2) -> void:
	if not EDIT_RECT.has_point(screen_point): return
	var cell := ground.local_to_map(ground.to_local(screen_point))
	if ground.get_cell_source_id(cell) < 0: return
	paths.erase_cell(cell)
	water.erase_cell(cell)
	match mode:
		"stone": paths.set_cell(cell, 0, Vector2i(1, 0))
		"soil": paths.set_cell(cell, 0, Vector2i(2, 0))
		"water": water.set_cell(cell, 0, Vector2i(3, 0))

func reset_layout() -> void:
	for layer in [ground, paths, water]:
		layer.clear()
		for cell in initial_cells[layer.name]:
			layer.set_cell(cell, 0, initial_cells[layer.name][cell])
	for building in buildings.get_children():
		building.position = initial_positions[building.name]
	scroll.value = INITIAL_SCROLL
	status.text = "已恢复初始地形和建筑位置"
