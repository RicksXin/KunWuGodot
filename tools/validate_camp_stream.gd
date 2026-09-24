extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	var original: Dictionary = panel.model.data.duplicate(true)
	var stream = panel.canvas.live_stream
	assert(stream.waterfall_count == 3)
	assert(stream.get_index() < panel.canvas.world.get_node("CachedGround").get_index())
	var surface: Polygon2D = stream.get_node("WaterSurface").get_child(0)
	var vertices := surface.polygon
	var line: Line2D = stream.falling_lines[0].line
	var points := line.points
	var clock: float = stream.animation_time
	await create_timer(0.3).timeout
	assert(stream.animation_time > clock and line.points != points)
	assert(surface.polygon == vertices)
	assert(stream.get_node("Riverbed").get_child(0).material != surface.material)
	panel.canvas.refresh()
	assert(panel.canvas.live_stream == stream)
	assert(panel.model.data == original)
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	assert(camp.get_node("ExteriorStream").definition == stream.definition)
	assert(camp.get_node("ExteriorStream").waterfall_count == 3)
	print("PASS stream: 3 animated falls, static geometry/riverbed, editor layer order, refresh continuity, runtime parity, layout preserved")
	quit()
