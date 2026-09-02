extends Control

## Decorative layer for the isolated landscape map preview.

const ROUTE := [
	Vector2(490, 112), Vector2(510, 192), Vector2(488, 268),
	Vector2(540, 350), Vector2(604, 420), Vector2(558, 500), Vector2(470, 584)
]
const MARKERS := [
	{"position": Vector2(490, 112), "color": Color("#f0d78e"), "radius": 12.0},
	{"position": Vector2(488, 268), "color": Color("#d5b267"), "radius": 10.0},
	{"position": Vector2(604, 420), "color": Color("#8cbac0"), "radius": 11.0},
	{"position": Vector2(470, 584), "color": Color("#e3c47a"), "radius": 13.0},
]

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_soft_grid()
	_draw_route()
	_draw_markers()
	_draw_corner_fog()

func _draw_soft_grid() -> void:
	for x in range(40, 960, 96):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.74, 0.82, 0.78, 0.055), 1.0)
	for y in range(80, 720, 96):
		draw_line(Vector2(0, y), Vector2(965, y), Color(0.74, 0.82, 0.78, 0.05), 1.0)

func _draw_route() -> void:
	for index in range(ROUTE.size() - 1):
		var start: Vector2 = ROUTE[index]
		var end: Vector2 = ROUTE[index + 1]
		var length: float = start.distance_to(end)
		var direction: Vector2 = (end - start).normalized()
		var cursor := 0.0
		while cursor < length:
			var dash_start: Vector2 = start + direction * cursor
			var dash_end: Vector2 = start + direction * minf(cursor + 12.0, length)
			draw_line(dash_start, dash_end, Color("#efe1b9d9"), 3.0, true)
			cursor += 22.0

	for index in range(ROUTE.size()):
		var point: Vector2 = ROUTE[index]
		var label := "%d天" % (index + 1)
		draw_string(ThemeDB.fallback_font, point + Vector2(18, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f2e8c9e8"))

func _draw_markers() -> void:
	for marker in MARKERS:
		var point: Vector2 = marker["position"]
		var color: Color = marker["color"]
		var radius: float = marker["radius"]
		for glow_index in range(3, 0, -1):
			draw_circle(point, radius + glow_index * 5.0, Color(color, 0.035 * float(4 - glow_index)))
		draw_circle(point, radius, Color("#0a1113e8"))
		draw_arc(point, radius, 0, TAU, 24, color, 2.0, true)
		draw_circle(point, 3.0, color)

func _draw_corner_fog() -> void:
	# Layered translucent shapes are cheaper and more controllable than a large
	# shader for this static direction board.
	draw_circle(Vector2(0, 0), 210.0, Color(0.02, 0.05, 0.06, 0.42))
	draw_circle(Vector2(950, 60), 190.0, Color(0.02, 0.05, 0.06, 0.32))
	draw_circle(Vector2(60, 690), 240.0, Color(0.02, 0.05, 0.06, 0.38))
