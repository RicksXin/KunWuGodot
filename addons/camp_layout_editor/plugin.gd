@tool
extends EditorPlugin
var panel: Control
func _enter_tree() -> void:
	panel = preload("res://addons/camp_layout_editor/panel.gd").new()
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.hide()
func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "营地摆放"
func _get_plugin_icon() -> Texture2D: return EditorInterface.get_base_control().get_theme_icon("Node2D", "EditorIcons")
func _make_visible(visible: bool) -> void:
	if is_instance_valid(panel): panel.visible = visible
