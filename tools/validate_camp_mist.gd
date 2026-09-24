extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	assert(not sample.has_node("MountainFootMist"))
	var fog = sample.tile_rebuild.mountain_mist
	assert(fog.get_child_count() == 1)
	var player: AnimatedSprite2D = fog.get_child(0)
	assert(player.sprite_frames.get_frame_count("default") == 96)
	assert(player.sprite_frames.get_animation_loop("default"))
	var initial: int = player.frame
	await create_timer(0.4).timeout
	assert(player.frame != initial)
	player.set_frame_and_progress(95,0)
	await create_timer(0.2).timeout
	assert(player.frame < 4)
	var before: Rect2 = fog.band_rect()
	sample.world.position += Vector2(57,31)
	sample.world.scale *= 1.2
	var after: Rect2 = fog.band_rect()
	assert(after.position.x == 0 and after.size.x == fog.get_viewport_rect().size.x)
	assert(after.position.y != before.position.y)
	for offset in [Vector2(-1200,-900),Vector2(1400,900),Vector2.ZERO]:
		for zoom in [0.45,0.8,1.2]:
			sample.world.position = offset
			sample.world.scale = Vector2.ONE*zoom
			var rect: Rect2 = fog.band_rect()
			assert(rect.end.y > fog.get_viewport_rect().size.y)
			assert(rect.position.y <= fog.get_viewport_rect().size.y*0.72+0.01)
	for i in range(96):
		var im: Image = player.sprite_frames.get_frame_texture("default",i).get_image()
		for x in range(im.get_width()): assert(im.get_pixel(x,0).a == 0 and im.get_pixel(x,im.get_height()-1).a >= 0.94)
		for y in range(im.get_height()):
			var left := im.get_pixel(0,y)
			var right := im.get_pixel(im.get_width()-1,y)
			assert(left.a == right.a)
			# Godot repairs RGB in invisible alpha-border pixels during import.
			assert(absf(left.r-right.r)*left.a <= 2.0/255.0)
			assert(absf(left.g-right.g)*left.a <= 2.0/255.0)
			assert(absf(left.b-right.b)*left.a <= 2.0/255.0)
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	assert(panel.canvas.world.get_node("MountainFootMist").get_child_count() == 1)
	print("PASS mist: 96 frames/12fps, playback+loop, 96 soft upper/dense lower borders, seamless horizontal edges, bottom coverage under extreme pan/zoom, shared editor/runtime, old rectangular overlay absent")
	quit()
