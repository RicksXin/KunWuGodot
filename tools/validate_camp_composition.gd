extends SceneTree
const OUTPUT := "res://Docs/Artifacts/camp-tilemap-exploration/"
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
func run() -> void:
	root.size = Vector2i(1600,900)
	var initial := FileAccess.get_file_as_string("res://data/prototypes/camp_tile_rebuild.json")
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	var exterior = sample.exterior
	var initial_position: Vector2 = sample.world.position
	var initial_scale: Vector2 = sample.world.scale
	var anchors := {}
	for layer in exterior.layers:
		if layer.name != "sky":
			anchors[layer.name] = (layer.position + exterior.position - sample.world.position)/sample.world.scale.x
	await capture("composition-default")
	for state in [[Vector2(300,100),0.7],[Vector2(950,360),1.4]]:
		sample.world.position = state[0]
		sample.world.scale = initial_scale*state[1]
		sample._process(0)
		for layer in exterior.layers:
			if anchors.has(layer.name):
				var actual: Vector2 = (layer.position+exterior.position-sample.world.position)/sample.world.scale.x
				assert(actual.distance_to(anchors[layer.name])<0.01,"Attached mountain moved relative to map")
		assert(sample.mountain_mist.size.is_equal_approx(Vector2(1280,455)*state[1]))
		await capture("composition-pan-"+str(state[1]))
	sample.world.position = initial_position
	sample.world.scale = initial_scale
	sample._process(0)
	for item in sample.tile_rebuild.data.buildings:
		if item.has("model_3d"):
			var sprite = sample.tile_rebuild.buildings.get_node(item.id)
			assert(sprite.model.has_node("GroundContact"))
	assert(FileAccess.get_file_as_string("res://data/prototypes/camp_tile_rebuild.json")==initial)
	print("PASS composition: near terrain registration at both pan/zoom extremes, map-local mist, six ground contacts, layout JSON unchanged")
	quit()
