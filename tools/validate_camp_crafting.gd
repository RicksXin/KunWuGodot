extends SceneTree
const SpriteScript = preload("res://scripts/prototypes/camp_building_3d_sprite.gd")
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(960,960)
	root.content_scale_size = Vector2i(960,960)
	var background := ColorRect.new()
	background.color = Color(.065,.085,.10)
	background.size = Vector2(960,960)
	root.add_child(background)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_tile_rebuild.json"))
	for kind in ["forge","garden","market"]:
		var item: Dictionary
		for entry in data.buildings:
			if entry.id == kind: item = entry.duplicate(true)
		var sprite = SpriteScript.new()
		root.add_child(sprite)
		item.display_width = 960.0
		sprite.configure(item)
		var anchor: Array = item.model_anchor
		assert((sprite.offset+sprite.camera.unproject_position(sprite.model.transform*Vector3(anchor[0],anchor[1],anchor[2]))).length()<.001)
		sprite.offset = Vector2.ZERO
		var motion = sprite.banners
		assert(motion.kind == kind)
		assert(is_equal_approx(motion.player.current_animation_length,16.0))
		motion.seek_preview(0)
		var moving: Node3D
		if kind == "forge": moving = sprite.building_visual.find_child("ForgeSmith_ArmR*",true,false)
		elif kind == "garden": moving = sprite.building_visual.find_child("Waterwheel*",true,false)
		else: moving = sprite.building_visual.find_child("TradeKeeper_ArmL*",true,false)
		assert(moving != null)
		var start: Transform3D = moving.transform
		motion.seek_preview(.5 if kind=="forge" else 2.0)
		assert(not moving.transform.is_equal_approx(start))
		if kind == "forge":
			assert(motion.smoke.size()==12 and motion.sparks.size()==9)
			var puff: Vector3 = motion.smoke[0].position
			motion.seek_preview(1.0)
			assert(motion.strike.light_energy>1.7)
			assert(not motion.smoke[0].position.is_equal_approx(puff))
		elif kind == "garden":
			assert(motion.droplets.size()==20 and motion.water_materials.size()==1)
			var child: Node3D = sprite.building_visual.find_child("HerbApprentice_Body*",true,false)
			var bent: Transform3D = child.transform
			motion.seek_preview(0)
			assert(not child.transform.is_equal_approx(bent))
		else:
			var flags = sprite.building_visual.find_children("TradeWindBanner*","MeshInstance3D",true,false)
			assert(flags.size()==2)
			motion.seek_preview(1.0)
			assert(absf(flags[0].get_blend_shape_value(0))>.8)
		motion.seek_preview(16)
		assert(moving.transform.is_equal_approx(start))
		motion.seek_preview(.7)
		var stopped: Transform3D = moving.transform
		await process_frame
		await process_frame
		assert(moving.transform.is_equal_approx(stopped))
		if not DisplayServer.get_name()=="headless":
			for n in range(4): await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/"+kind+"-living.png")
			if OS.get_cmdline_user_args().has("--capture-motion"):
				var path: String = "res://art/candidates/camp-crafting-trio-v1/"+kind+"-frames"
				DirAccess.make_dir_recursive_absolute(path)
				for f in range(64):
					motion.seek_preview(f*.25)
					await process_frame
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png(path+"/%03d.png"%f)
		sprite.free()
		print("PASS ",kind,": isolated scene, 16s motion, pause/reset, effects, entrance anchor")
	quit()
