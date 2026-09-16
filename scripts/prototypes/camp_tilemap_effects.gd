extends Node2D
## Pure presentation. Anchors follow independently movable buildings.
var enabled := true
var elapsed := 0.0

func _process(delta: float) -> void:
	if enabled: elapsed += delta
	queue_redraw()

func _draw() -> void:
	if not enabled: return
	var portal: Sprite2D = get_node("../Buildings/Portal")
	var forge: Sprite2D = get_node("../Buildings/Forge")
	var center := portal.position + Vector2(0, 18)
	for ring in range(3):
		var phase := fmod(elapsed * 0.32 + ring / 3.0, 1.0)
		var points := PackedVector2Array()
		for step in range(65):
			var angle := TAU * step / 64.0
			points.append(center + Vector2(cos(angle) * 66, sin(angle) * 23) * (0.6 + phase * 0.7))
		draw_polyline(points, Color(0.4, 0.95, 0.87, (1.0 - phase) * 0.7), 1.5)
	for puff in range(7):
		var phase := fmod(elapsed * 0.2 + puff / 7.0, 1.0)
		var point := forge.position + Vector2(18 + sin(phase * 5) * 9, -52 - phase * 55)
		draw_circle(point, 3 + phase * 8, Color(0.8, 0.85, 0.82, (1.0 - phase) * 0.25))
