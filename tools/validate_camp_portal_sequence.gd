extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	var original: Dictionary = panel.model.data.duplicate(true)
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/candidates/camp-portal-20260923/layout-before-integration.json"))
	var existing := original.duplicate(true)
	existing.erase("portal")
	assert(existing == previous)
	var index: int = panel.model.items().size()-1
	assert(panel.model.items()[index].id == "portal")
	var visual: Sprite2D = panel.canvas.sprites[index]
	assert(visual.z_index >= 0) # Negative depth hides it behind the Control's ground image.
	assert(visual.player.is_playing() and visual.player.sprite_frames.get_frame_count("default") == 16)
	assert(is_equal_approx(visual.player.sprite_frames.get_animation_speed("default"),8.0))
	var before: Vector2 = visual.position
	var frame: int = visual.player.frame
	await create_timer(0.2).timeout
	assert(visual.player.frame != frame and visual.position == before)
	visual.player.set_frame_and_progress(15,0)
	await create_timer(0.15).timeout
	assert(visual.player.frame < 2)
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	assert(camp.portal.transform.is_equal_approx(visual.transform))
	assert(camp.portal.player.is_playing())
	panel.select(index)
	panel.nudge(index,Vector2(2.5,-1.5))
	assert(panel.canvas.sprites[index].position.is_equal_approx(before+Vector2(2.5,-1.5)))
	assert(panel.model.data.spawn == original.spawn)
	assert(panel.model.data.buildings == original.buildings and panel.model.data.decorations == original.decorations)
	panel.model.undo()
	panel.sync()
	assert(panel.model.data == original)
	var bare = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	bare.definition_override = previous
	root.add_child(bare)
	assert(bare.ids == camp.ids and bare.blocked == camp.blocked)
	print("PASS portal: 16 frames at 8fps, playback/loop, stable anchor, editor/runtime parity, fine placement/undo, original layout/spawn/navigation preserved")
	quit()
