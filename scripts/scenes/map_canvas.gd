extends Control

signal cell_clicked(x: int, y: int)

var tile_size := 48.0
var terrain_instance: Node2D
var overlay: Control

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
	if is_instance_valid(overlay):
		overlay.call("refresh")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell_x := floori(event.position.x / tile_size)
		var screen_y := floori(event.position.y / tile_size)
		var cell_y := int(Game.get_map_definition().get("activeHeight", 15)) - 1 - screen_y
		if Game.is_visible(cell_x, cell_y):
			emit_signal("cell_clicked", cell_x, cell_y)
