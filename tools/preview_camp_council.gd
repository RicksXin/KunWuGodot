extends SceneTree
## Review-only overlay. Never promotes candidate art or writes profile data.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): path = arg.trim_prefix("--candidate=")
	if path.is_empty():
		push_error("Provide --candidate=<local PNG>")
		quit(1)
		return
	var picture := Image.load_from_file(path)
	if picture == null or picture.get_size() != Vector2i(288,240):
		push_error("Candidate must be an aligned 288x240 PNG")
		quit(1)
		return
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	var hall = sample.terrace.hall
	for child in hall.get_children():
		if child is Polygon2D or child is Line2D or child is Sprite2D: child.hide()
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(picture)
	sprite.centered = false
	sprite.position = Vector2(-144,-224)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hall.add_child(sprite)
	sample.scene_hint.text = "议事殿候选叠放 · 原像素不缩放 · 仅供预览，不替换默认素材"
	sample.terrace.lamp.hide()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/kunwu-council-candidate.png")
	print("Candidate preview: /tmp/kunwu-council-candidate.png")
	if not OS.get_cmdline_user_args().has("--keep-open"): quit()
