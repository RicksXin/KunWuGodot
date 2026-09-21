extends Node2D

const MANIFEST_PATH := "res://data/maps/map_01_regions.json"
var source_canvas := Vector2.ZERO
var shapes: Array = []

func setup(background: Sprite2D, definition: Dictionary = {}) -> void:
	var manifest: Dictionary = definition.get("regionsDocument", {}) if definition.has("regionsDocument") else JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var canvas: Dictionary = manifest["canvas"]
	source_canvas = Vector2(float(canvas["width"]), float(canvas["height"]))
	# Source pixels -> texture pixels -> world. Camera zoom applies to both siblings.
	transform = background.transform
	scale *= background.texture.get_size() / source_canvas
	position += background.transform.basis_xform(background.get_rect().position)
	shapes.clear()
	for layer in manifest["annotations"]["layers"]:
		if layer["id"] not in ["collision", "adjust"]:
			continue
		for shape in layer["shapes"]:
			var points := PackedVector2Array()
			for point in shape["points"]:
				points.append(Vector2(float(point["x"]), float(point["y"])))
			if points.size() >= 3:
				shapes.append({"layer": layer["id"], "points": points, "fills": _fill_parts(points)})
	queue_redraw()

# Even-odd trapezoids also support self-intersections in authored outlines.
# Split at every vertex and crossing; edges remain linear within each band.
# Preserve all source vertices, including large mountain boundary polygons.
func _fill_parts(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var levels: Array[float] = []
	var edges: Array[PackedVector2Array] = []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		levels.append(a.y)
		if not is_equal_approx(a.y, b.y):
			edges.append(PackedVector2Array([a, b]))
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var crossing: Variant = Geometry2D.segment_intersects_segment(edges[i][0], edges[i][1], edges[j][0], edges[j][1])
			if crossing != null:
				levels.append(crossing.y)
	levels.sort()
	var fills: Array[PackedVector2Array] = []
	for i in range(1, levels.size()):
		var top := levels[i - 1]
		var bottom := levels[i]
		if bottom - top < 0.0001:
			continue
		var middle := (top + bottom) * 0.5
		var active: Array[PackedVector2Array] = []
		for edge in edges:
			if middle > minf(edge[0].y, edge[1].y) and middle < maxf(edge[0].y, edge[1].y):
				active.append(edge)
		active.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return _edge_x(a, middle) < _edge_x(b, middle))
		for j in range(0, active.size() - 1, 2):
			fills.append(PackedVector2Array([
				Vector2(_edge_x(active[j], top), top), Vector2(_edge_x(active[j + 1], top), top),
				Vector2(_edge_x(active[j + 1], bottom), bottom), Vector2(_edge_x(active[j], bottom), bottom)]))
	return fills

func _edge_x(edge: PackedVector2Array, y: float) -> float:
	return lerpf(edge[0].x, edge[1].x, (y - edge[0].y) / (edge[1].y - edge[0].y))

func _draw() -> void:
	for item in shapes:
		var points: PackedVector2Array = item.points
		var color := Color("#e0525f66") if item.layer == "collision" else Color("#7a3eb166")
		for fill in item.fills:
			draw_primitive(fill, PackedColorArray([color]), PackedVector2Array())
		draw_polyline(points + PackedVector2Array([points[0]]), color.lightened(0.25), 2.0, true)
