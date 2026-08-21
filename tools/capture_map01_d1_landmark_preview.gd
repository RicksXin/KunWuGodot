extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_landmark_preview.tscn"
const REVIEW_DIR := "res://art/review/map01"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var captures := [
		{
			"size": Vector2i(2352, 3120),
			"offset": Vector2(24.0, 24.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_overview.png",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(1512.0, 2380.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_b_zone_375x817.png",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(1176.0, 2016.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_c_zone_375x817.png",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(1176.0, 360.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_gate_375x817.png",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(1824.0, 1488.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_e_zone_closed_375x817.png",
			"stairs_open": false,
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(1824.0, 1488.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_e_zone_open_375x817.png",
			"stairs_open": true,
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(408.0, 1392.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_d_zone_default_375x817.png",
			"tunnel_state": "TUNNEL_DEFAULT",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(408.0, 1392.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_d_zone_discovered_375x817.png",
			"tunnel_state": "TUNNEL_DISCOVERED",
		},
		{
			"size": Vector2i(375, 817),
			"offset": Vector2(375.0, 817.0) * 0.5 - Vector2(408.0, 1392.0),
			"path": REVIEW_DIR + "/map01_d1_landmark_d_zone_cleared_375x817.png",
			"tunnel_state": "TUNNEL_CLEARED",
		},
	]
	for capture in captures:
		var error := await _capture(
			capture.size,
			capture.offset,
			capture.path,
			bool(capture.get("stairs_open", false)),
			str(capture.get("tunnel_state", "TUNNEL_DEFAULT"))
		)
		if error != OK:
			push_error("Could not capture Map01 D1 landmark preview %s: %s" % [capture.path, error_string(error)])
			quit(1)
			return
	print("MAP01_D1_LANDMARK_CAPTURE_OK")
	quit(0)


func _capture(
	size: Vector2i,
	world_offset: Vector2,
	output_path: String,
	stairs_open: bool = false,
	tunnel_state: String = "TUNNEL_DEFAULT"
) -> Error:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = world_offset
	viewport.add_child(holder)
	var preview := (load(SCENE_PATH) as PackedScene).instantiate()
	holder.add_child(preview)
	preview.call("set_stairs_preview_open", stairs_open)
	preview.call("set_tunnel_preview_state_id", tunnel_state)
	var camera := preview.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	var ui := preview.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		await _dispose_viewport(viewport)
		return ERR_CANT_CREATE
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	await _dispose_viewport(viewport)
	return error


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
