@tool
extends EditorPlugin
var panel: Control
func _enter_tree() -> void:
	panel = preload("res://addons/map01_terrain_editor/panel.gd").new()
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.hide()
func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "Map01 地形"
func _get_plugin_icon() -> Texture2D: return EditorInterface.get_base_control().get_theme_icon("Polygon2D", "EditorIcons")
func _make_visible(value: bool) -> void:
	if is_instance_valid(panel): panel.visible = value
func _get_unsaved_status(_for_scene: String) -> String:
	if is_instance_valid(panel) and panel.model.cells != panel.model.saved_cells:
		return "Map01 地形尚未保存，请点击“保存地形”。"
	return ""
