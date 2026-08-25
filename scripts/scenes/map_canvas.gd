extends Control

signal cell_clicked(x: int, y: int)

const CLICK_DRAG_THRESHOLD := 5.0

var tile_size := 48.0
var terrain_instance: Node2D
var overlay: Control
var pointer_active := false
var pointer_index := -1
var pointer_start := Vector2.ZERO
var pointer_moved := false

func _ready() -> void:
	var active_map := Game.get_map_definition()
	var visual: Dictionary = active_map.get("visual", {})
	tile_size = float(visual.get("logicalTileSize", 48))
	var width := int(active_map.get("activeWidth", 15))
	var height := int(active_map.get("activeHeight", 15))
	custom_minimum_size = Vector2(width * tile_size, height * tile_size)
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var scene_terrain_active := _instantiate_terrain(str(visual.get("scenePath", "")))
	overlay = Control.new()
	overlay.name = "RuntimeOverlay"
	overlay.set_script(load("res://scripts/scenes/map_overlay.gd"))
	overlay.position = Vector2.ZERO
	overlay.size = custom_minimum_size
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.call("setup", scene_terrain_active)

func _instantiate_terrain(scene_path: String) -> bool:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	terrain_instance = packed.instantiate() as Node2D
	if terrain_instance == null:
		return false
	terrain_instance.name = "Terrain"
	add_child(terrain_instance)
	move_child(terrain_instance, 0)
	return true

func refresh() -> void:
	if is_instance_valid(terrain_instance) and terrain_instance.has_method("sync_external_state_from_game"):
		terrain_instance.call("sync_external_state_from_game")
	if is_instance_valid(terrain_instance) and terrain_instance.has_method("sync_player_occluders"):
		var expedition: Variant = Game.profile.get("expedition")
		if expedition is Dictionary:
			terrain_instance.call("sync_player_occluders", expedition.get("position", {}))
	if is_instance_valid(overlay):
		overlay.call("refresh")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer(-1, event.position)
		elif pointer_active and pointer_index == -1:
			_end_pointer(event.position)
		return
	if event is InputEventMouseMotion and pointer_active and pointer_index == -1:
		_update_pointer(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not pointer_active:
				_begin_pointer(event.index, event.position)
			elif event.index != pointer_index:
				pointer_moved = true
		elif pointer_active and event.index == pointer_index:
			_end_pointer(event.position)
		return
	if event is InputEventScreenDrag and pointer_active and event.index == pointer_index:
		_update_pointer(event.position)

func cancel_pending_click() -> void:
	pointer_moved = true

func _begin_pointer(index: int, position: Vector2) -> void:
	pointer_active = true
	pointer_index = index
	pointer_start = position
	pointer_moved = false

func _update_pointer(position: Vector2) -> void:
	if position.distance_to(pointer_start) >= CLICK_DRAG_THRESHOLD:
		pointer_moved = true

func _end_pointer(position: Vector2) -> void:
	_update_pointer(position)
	if not pointer_moved and Rect2(Vector2.ZERO, size).has_point(position):
		_emit_cell_click(position)
	pointer_active = false
	pointer_index = -1
	pointer_moved = false

func _emit_cell_click(position: Vector2) -> void:
	var cell_x := floori(position.x / tile_size)
	var screen_y := floori(position.y / tile_size)
	var cell_y := int(Game.get_map_definition().get("activeHeight", 15)) - 1 - screen_y
	if Game.is_visible(cell_x, cell_y):
		emit_signal("cell_clicked", cell_x, cell_y)
