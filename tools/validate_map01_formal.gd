extends SceneTree
var failures: Array[String] = []
var game: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	game = root.get_node("Game")
	game.profile = game.default_profile.duplicate(true)
	check(game.start_expedition().get("ok",false),"start expedition")
	var data: Dictionary = game.get_map_definition()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/map_01_manifest.json"))
	check(data.id == "map_01" and data.positionVersion == 2,"formal continuous map")
	check(not data.has("terrainRows"),"old grid removed")
	check(FileAccess.get_sha256("res://assets/maps/map_01/map01_background.png")==manifest.backgroundSha256,"approved paired background hash")
	var texture: Texture2D = load("res://assets/maps/map_01/map01_background.png")
	check(texture.get_size()==Vector2(2488,5692),"approved image dimensions")
	var nav: RefCounted = game.get_world_navigation()
	check(nav.external_collision_polygons.size()==36,"36 original blockers")
	var spawn: Vector2 = game.expedition_world_position()
	check(nav.can_walk(spawn),"entry walkable")
	check(data.objects.size()==31,"31 gameplay objects retained")
	for polygon in nav.external_collision_polygons:
		for vertex in polygon:
			check(not nav.can_walk(vertex),"source boundary blocks actor")
	for object in data.objects:
		var target := Vector2(object.x,object.y)
		if object.id == "m1_exit":
			check(nav.path(spawn,target).is_empty(),"boss gate blocks exit before victory")
			continue
		var path: PackedVector2Array = nav.path(spawn,target)
		check(not path.is_empty(),"reachable object " + object.id)
		var cursor := spawn
		for waypoint in path:
			check(nav.segment_clear(cursor,waypoint),"path avoids blockers " + object.id)
			cursor = nav.move(cursor,waypoint-cursor)
		check(cursor.distance_to(target)<0.1,"actual walking reaches " + object.id)
		check(game.object_at(int(target.x),int(target.y)).get("id","")==object.id,"object proximity " + object.id)
	for point in [Vector2(-1,200),Vector2(450,900),Vector2(900,200)]:
		check(not nav.can_walk(point),"mountain and world limits")
	var grain_before: int = game.profile.expedition.remainingGrain
	var road: PackedVector2Array = nav.path(spawn,Vector2(data.objects[12].x,data.objects[12].y))
	var direction := (road[0]-spawn).normalized()
	game.move_world(direction*25.0)
	game.move_world(-direction*25.0)
	check(game.profile.expedition.remainingGrain==grain_before-int(game.get_expedition_map_rule().get("grainPerStep",1)),"distance-based grain charge")
	check(game.is_revealed(450,1890),"entry revealed")
	check(not game.is_revealed(450,240),"distant fog not revealed")
	game.enter_rest()
	var before: Vector2 = game.expedition_world_position()
	check(not game.move_world(Vector2(0,-12)).get("ok",false),"rest blocks movement")
	check(game.expedition_world_position()==before,"rest preserves position")
	game.continue_rest()
	# Resource interaction still credits the existing expedition loot flow.
	var wood: Dictionary = data.objects.filter(func(o): return o.id=="m1_res_wood_01")[0]
	game.profile.expedition.position = {"x":wood.x,"y":wood.y}
	check(game.resolve_map_object_action(wood,"gather").get("ok",false),"resource action")
	check(not game.profile.expedition.temporaryLoot.is_empty(),"resource stored as expedition loot")
	var shortcut: Dictionary = data.objects.filter(func(o): return o.id=="m1_shortcut_stairs")[0]
	game.apply_map_state_patch({"map_01.encounters.m1_e01.firstClearClaimed":true})
	game.profile.expedition.position = {"x":shortcut.x,"y":shortcut.y}
	check(game.resolve_map_object_action(shortcut,"unlock").get("ok",false),"shortcut unlock")
	check(game.resolve_map_object_action(shortcut,"travel_down").get("ok",false),"shortcut travel down")
	check(game.expedition_world_position()==Vector2(450,1848),"shortcut lower landing")
	check(game.object_at(450,1848).get("id","")==shortcut.id,"lower landing interactable")
	check(game.resolve_map_object_action(shortcut,"travel_up").get("ok",false),"shortcut travel up")
	check(game.expedition_world_position()==Vector2(shortcut.x,shortcut.y),"shortcut upper landing")
	game.apply_map_state_patch({"map_01.encounters.m1_boss_gate_spirit.defeated":true})
	nav = game.get_world_navigation()
	var exit_object: Dictionary = data.objects.filter(func(o): return o.id=="m1_exit")[0]
	check(not nav.path(spawn,Vector2(exit_object.x,exit_object.y)).is_empty(),"boss victory opens exit")
	# Migrate a genuine old position without dropping loot or completed object flags.
	var loot: String = JSON.stringify(game.profile.expedition.temporaryLoot)
	game.profile.expedition.erase("positionVersion")
	game.profile.expedition.position = {"x":13,"y":6}
	game.ensure_world_position()
	check(game.expedition_world_position()==spawn,"old save position migration")
	check(JSON.stringify(game.profile.expedition.temporaryLoot)==loot,"migration preserves loot")
	var scene: Node2D = load("res://scenes/map.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_physics_process(false)
	check(scene.get("actor").position==spawn,"formal scene resumes stored position")
	var overlay: Node2D = scene.get("annotation_overlay")
	check(overlay.get("shapes").size()==53,"53 annotation regions displayed")
	var collision_index := 0
	for shape in overlay.get("shapes"):
		if shape.layer!="collision": continue
		var polygon: PackedVector2Array = nav.external_collision_polygons[collision_index]
		for i in polygon.size():
			check((overlay.transform*shape.points[i]).distance_to(polygon[i])<0.01,"visual and movement polygon alignment")
		collision_index+=1
	for zoom in [0.14,0.5,1.2,2.2]:
		scene.call("_set_zoom",zoom)
		check(not nav.can_walk(Vector2(450,900)),"zoom must not alter collision")
	# Save before combat, return to the exact same world position.
	var enemy: Dictionary = data.objects.filter(func(o): return o.id=="m1_g01")[0]
	game.profile.expedition.position={"x":enemy.x,"y":enemy.y}
	check(game.begin_encounter(enemy).get("ok",false),"begin encounter")
	scene.call("sync_saved_position")
	check(scene.get("actor").position==Vector2(enemy.x,enemy.y),"combat return position")
	if DisplayServer.get_name()!="headless":
		game.profile.expedition.position={"x":450,"y":1890}
		scene.call("sync_saved_position")
		scene.call("_set_zoom",1.2)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/map01_formal_expedition.png")
	game.profile.expedition.position={"x":450,"y":1890}
	check(game.return_to_camp().get("ok",false),"entry return settles expedition")
	check(game.profile.expedition==null,"expedition cleared after return")
	scene.queue_free()
	await process_frame
	check(root.content_scale_size==Vector2i(375,817),"restore camp orientation")
	print("MAP01_FORMAL_VALIDATION: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
