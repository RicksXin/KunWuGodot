extends SceneTree
const Model = preload("res://addons/camp_layout_editor/model.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model := Model.new()
	assert(model.load_file().is_empty())
	assert(model.validate().is_empty())
	var original := model.data.duplicate(true)
	# Translation must preserve the building/entrance/approach relationship.
	model.checkpoint()
	model.translate(1,Vector2i(20,20))
	assert(model.data.buildings[1].door[0]==original.buildings[1].door[0]+20)
	assert(model.data.buildings[1].approach[1]==original.buildings[1].approach[1]+20)
	assert(not model.validate().is_empty())
	model.undo()
	assert(model.data==original)
	# Reject overlap and reserved-passage obstruction.
	model.data.buildings[1].origin = original.buildings[2].origin.duplicate()
	assert(not model.validate().is_empty())
	model.data = original.duplicate(true)
	model.data.buildings[1].origin = [2,8]
	assert(not model.validate().is_empty())
	model.data = original.duplicate(true)
	# Use a temporary file: never write the real layout or profile during tests.
	var path := "user://camp-layout-editor-test.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(model.disk_text)
	file.close()
	assert(model.load_file(path).is_empty())
	model.data.buildings[1].display_width = 211
	model.data.buildings[1].rotation_degrees = -23.7
	model.dirty = true
	assert(model.save(path).is_empty())
	var roundtrip = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(roundtrip.buildings[1].display_width==211)
	assert(is_equal_approx(roundtrip.buildings[1].rotation_degrees,-23.7))
	assert(roundtrip.cells==original.cells and roundtrip.stairs==original.stairs)
	assert(roundtrip.buildings[3].texture==original.buildings[3].texture)
	model.translate(1,Vector2i(30,30))
	assert(not model.validate().is_empty())
	assert(model.save(path).is_empty()) # Terrain problems are now warnings, not save restrictions.
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).buildings[1].origin[0]==original.buildings[1].origin[0]+30)
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	assert(model.save(path).contains("其他操作"))
	assert(FileAccess.get_file_as_string(path)=="{}")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	camp.definition_override = original.duplicate(true)
	camp.definition_override.buildings[0].origin = [100,100]
	camp.definition_override.buildings[0].door = [100,102]
	camp.definition_override.buildings[1].origin = original.spawn.duplicate()
	root.add_child(camp)
	await process_frame
	assert(camp.targets[0].node == -1)
	assert(not camp.move_to_node(-1))
	assert(camp.current>=0 and camp.graph.has_point(camp.current))
	camp.queue_free()
	await process_frame
	print("PASS camp editor: entrance translation, invalid placement, undo, roundtrip, conflict protection")
	quit()
