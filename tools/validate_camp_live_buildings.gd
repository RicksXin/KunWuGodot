extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(1440,900)
	root.size = Vector2i(1440,900)
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.canvas.fit()
	var original: Dictionary = panel.model.data.duplicate(true)
	for index in range(panel.model.data.buildings.size()):
		var item: Dictionary = panel.model.data.buildings[index]
		if not item.has("model_3d"): continue
		panel.select(index)
		var sprite = panel.canvas.sprites[index]
		assert(sprite.viewport != null and sprite.building_visual != null)
		var before: Vector2 = sprite.position
		var instance_id: int = sprite.get_instance_id()
		panel.rotate_building(37.6)
		assert(panel.canvas.sprites[index].get_instance_id() == instance_id)
		assert(is_equal_approx(sprite.model.rotation_degrees.y,37.6))
		assert(sprite.rotation == 0 and sprite.model.basis.y.is_equal_approx(Vector3.UP))
		assert(sprite.position == before)
		if item.id == "recruit":
			var anchor := Vector3(1.06, 0.0, 2.78)
			assert((sprite.camera.unproject_position(sprite.model.transform * anchor)+sprite.offset).length() < 0.001)
			assert(sprite.banners.player != null)
			assert(is_equal_approx(sprite.banners.player.current_animation_length, 24.0))
		assert(panel.model.data.buildings[index].yaw_degrees == 37.6)
		panel.move(index,Vector2i(20,20))
		assert(sprite.position != before and not panel.save_button.disabled)
		panel.model.undo()
		panel.model.undo()
		panel.sync()
		assert(panel.model.data == original)
	# JSON round trip in a disposable file only.
	var temp := "user://camp-live-buildings-test.json"
	var f := FileAccess.open(temp,FileAccess.WRITE)
	f.store_string(panel.model.disk_text)
	f.close()
	panel.model.checkpoint()
	for item in panel.model.data.buildings:
		if item.has("model_3d"): item.yaw_degrees = -23.7
	panel.model.dirty = true
	assert(panel.model.save(temp).is_empty())
	var check = load("res://addons/camp_layout_editor/model.gd").new()
	assert(check.load_file(temp).is_empty())
	for item in check.data.buildings:
		if item.has("model_3d"): assert(item.yaw_degrees == -23.7)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	panel.model.undo()
	panel.sync()
	for n in range(12): await process_frame
	RenderingServer.force_draw(false)
	# Real rendered pixels must be selectable, including the GPU viewport texture.
	for index in range(panel.model.data.buildings.size()):
		if not panel.model.data.buildings[index].has("model_3d"): continue
		var sprite: Sprite2D = panel.canvas.sprites[index]
		var img := sprite.texture.get_image()
		var local := Vector2.ZERO
		var found := false
		for y in range(200,850,12):
			for x in range(250,700,12):
				if img.get_pixel(x,y).a > 0.9:
					local = Vector2(x,y)+sprite.offset
					found = true
					break
			if found: break
		assert(found and sprite.is_pixel_opaque(local))
	panel.select(1)
	panel.model.dirty = false
	panel.report()
	panel.canvas.show_grid = false
	panel.canvas.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/editor-live-buildings.png")
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	for id in ["treasury","revival","recruit","forge","garden","market"]:
		var live = camp.buildings.get_node(id)
		assert(live.viewport != null and live.model != null and live.rotation == 0)
		var expected: Dictionary
		for item in original.buildings:
			if item.id == id: expected = item
		live.configure(expected.merged({"yaw_degrees":71.2},true))
		assert(is_equal_approx(live.model.rotation_degrees.y,71.2))
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	camp.queue_free()
	panel.queue_free()
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	print("PASS live 3D buildings: six models, upright yaw, cached refresh, unrestricted placement, undo, JSON roundtrip, rendered alpha picking, runtime parity")
	quit()
