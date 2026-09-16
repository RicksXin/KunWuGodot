class_name KWMapNavigation
extends RefCounted

# Passability comes from the same authored JSON as the overlay, never texture pixels.
const MANIFEST_PATH := "res://data/maps/map_01_regions.json"
var definition: Dictionary
var graph := AStarGrid2D.new()
var world_size := Vector2.ZERO
var step := 6.0
var actor_radius := 5.0
var painted_walkable: Dictionary = {}
var external_collision_polygons: Array[PackedVector2Array] = []
var collision_bounds: Array[Rect2] = []
var collision_loaded := false
var external_adjust_polygons: Array[PackedVector2Array] = []

func setup(data: Dictionary) -> void:
	definition = data
	world_size = point(data["worldSize"])
	step = float(data["navigationStep"])
	actor_radius = float(data["actorRadius"])
	_load_external_collision_layer()
	graph.region = Rect2i(0, 0, ceili(world_size.x / step), ceili(world_size.y / step))
	graph.cell_size = Vector2.ONE * step
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	graph.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	graph.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	graph.update()
	for y in graph.region.size.y:
		for x in graph.region.size.x:
			graph.set_point_solid(Vector2i(x, y), not can_walk(Vector2(x, y) * step))

static func point(raw: Array) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))

func can_walk(position: Vector2) -> bool:
	if not collision_loaded or not Rect2(Vector2.ZERO, world_size).grow(-actor_radius).has_point(position):
		return false
	for polygon in dynamic_polygons:
		if Geometry2D.is_point_in_polygon(position,polygon): return false
		for i in polygon.size():
			if position.distance_to(Geometry2D.get_closest_point_to_segment(position,polygon[i],polygon[(i+1)%polygon.size()])) <= actor_radius: return false
	for raw in painted_walkable:
		var parts: PackedStringArray = raw.split(",")
		var center := Vector2(float(parts[0]), float(parts[1]))
		if position.distance_to(center) <= absf(float(painted_walkable[raw])):
			return false
	for index in external_collision_polygons.size():
		if not collision_bounds[index].has_point(position):
			continue
		var polygon := external_collision_polygons[index]
		if Geometry2D.is_point_in_polygon(position, polygon):
			return false
		# The actor's foot circle must stay outside every authored edge.
		for i in polygon.size():
			var closest := Geometry2D.get_closest_point_to_segment(position, polygon[i], polygon[(i + 1) % polygon.size()])
			if position.distance_squared_to(closest) <= actor_radius * actor_radius:
				return false
	return true

func _load_external_collision_layer() -> void:
	external_adjust_polygons.clear()
	external_collision_polygons.clear()
	collision_bounds.clear()
	collision_loaded = false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not manifest is Dictionary:
		push_error("Missing Demo collision manifest")
		return
	var canvas: Dictionary = manifest["canvas"]
	var source_size := Vector2(float(canvas["width"]), float(canvas["height"]))
	var source_to_world := world_size / source_size
	for layer in manifest["annotations"]["layers"]:
		if layer["id"] not in ["collision", "adjust"]:
			continue
		for shape in layer["shapes"]:
			var polygon := PackedVector2Array()
			for p in shape["points"]:
				polygon.append(Vector2(float(p["x"]), float(p["y"])) * source_to_world)
			if polygon.size() < 3:
				continue
			if layer["id"] == "adjust":
				external_adjust_polygons.append(polygon)
				continue
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for p in polygon:
				bounds = bounds.expand(p)
			external_collision_polygons.append(polygon)
			collision_bounds.append(bounds.grow(actor_radius + 0.001))
	collision_loaded = not external_collision_polygons.is_empty()

func paint(position: Vector2, radius: float, erase := false) -> void:
	var key := "%d,%d" % [roundi(position.x / step) * int(step), roundi(position.y / step) * int(step)]
	# Debug may restrict the authored area, but cannot paint through source blockers.
	if erase: painted_walkable[key] = radius
	else: painted_walkable.erase(key)
	graph.update()
	for y in graph.region.size.y:
		for x in graph.region.size.x:
			graph.set_point_solid(Vector2i(x, y), not can_walk(Vector2(x, y) * step))

func segment_clear(from: Vector2, to: Vector2) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / 2.0))
	for index in range(samples + 1):
		if not can_walk(from.lerp(to, float(index) / samples)):
			return false
	return true

func move(from: Vector2, delta: Vector2) -> Vector2:
	# Substeps prevent tunneling on frame stalls; sliding keeps narrow stairs usable.
	var position := from
	var count := maxi(1, ceili(delta.length() / 2.0))
	var offset := delta / count
	for index in count:
		if can_walk(position + offset):
			position += offset
		elif can_walk(position + Vector2(offset.x, 0)):
			position.x += offset.x
		elif can_walk(position + Vector2(0, offset.y)):
			position.y += offset.y
	return position

func _nearest_cell(position: Vector2) -> Vector2i:
	var cell := Vector2i((position / step).round())
	var best := Vector2i(-1, -1)
	var distance := INF
	for y in range(cell.y - 2, cell.y + 3):
		for x in range(cell.x - 2, cell.x + 3):
			var candidate := Vector2i(x, y)
			if not graph.is_in_boundsv(candidate) or graph.is_point_solid(candidate):
				continue
			var location := Vector2(candidate) * step
			if location.distance_to(position) < distance and segment_clear(position, location):
				best = candidate
				distance = location.distance_to(position)
	return best

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not can_walk(from) or not can_walk(to):
		return PackedVector2Array()
	if segment_clear(from, to):
		return PackedVector2Array([to])
	var start := _nearest_cell(from)
	var end := _nearest_cell(to)
	if start.x < 0 or end.x < 0:
		return PackedVector2Array()
	var raw := graph.get_point_path(start, end)
	if raw.is_empty():
		return raw
	raw.append(to)
	var simplified := PackedVector2Array()
	var anchor := from
	var index := 0
	while index < raw.size():
		var farthest := index
		while farthest + 1 < raw.size() and segment_clear(anchor, raw[farthest + 1]):
			farthest += 1
		if not segment_clear(anchor, raw[farthest]):
			return PackedVector2Array()
		anchor = raw[farthest]
		simplified.append(anchor)
		index = farthest + 1
	return simplified

var dynamic_polygons: Array[PackedVector2Array] = []

func set_dynamic_blockers(blockers: Array) -> void:
	dynamic_polygons.clear()
	for blocker in blockers:
		var polygon := PackedVector2Array()
		for p in blocker.polygon: polygon.append(point(p))
		dynamic_polygons.append(polygon)
	graph.update()
	for y in graph.region.size.y:
		for x in graph.region.size.x:
			graph.set_point_solid(Vector2i(x,y),not can_walk(Vector2(x,y)*step))

# Authored purple regions affect presentation only, never passability.
func is_in_adjust_region(world_position: Vector2) -> bool:
	for polygon in external_adjust_polygons:
		if Geometry2D.is_point_in_polygon(world_position, polygon):
			return true
	return false
