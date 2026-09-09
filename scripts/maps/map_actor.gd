extends Node2D

# Procedural stand-in for a future approved directional character asset.
var facing := Vector2.UP
var walking := false
var phase := 0.0

func _process(delta: float) -> void:
	phase += delta * (10.0 if walking else 1.5)
	queue_redraw()

func _draw() -> void:
	var stride := sin(phase) * 2.5 if walking else 0.0
	var bob := absf(sin(phase)) * 0.7 if walking else sin(phase) * 0.25
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, 11, Color(0.02, 0.03, 0.03, 0.5))
	draw_arc(Vector2.ZERO, 13, 0, TAU, 32, Color(0.74, 0.79, 0.67, 0.55), 1.1, true)
	draw_set_transform(Vector2(0, bob))
	draw_line(Vector2(-3, -6), Vector2(-4 + stride, 0), Color("#252b29"), 4, true)
	draw_line(Vector2(3, -6), Vector2(4 - stride, -1), Color("#252b29"), 4, true)
	var robe := PackedVector2Array([Vector2(-5,-25),Vector2(5,-25),Vector2(9,-7),Vector2(6,-3),Vector2(-8,-4),Vector2(-9,-8)])
	draw_colored_polygon(robe, Color("#536c6a"))
	draw_polyline(PackedVector2Array([Vector2(-5,-24),Vector2(-8,-7),Vector2(-4,-5)]), Color("#92a59a"), 1.2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(1,-23),Vector2(5,-22),Vector2(8,-6),Vector2(2,-7)]), Color("#314845"))
	draw_line(Vector2(-6,-15),Vector2(6,-15),Color("#b6a782"),2,true)
	draw_line(Vector2(-5,-22),Vector2(-10,-13-stride),Color("#617e79"),4,true)
	draw_line(Vector2(5,-22),Vector2(10,-13+stride),Color("#617e79"),4,true)
	# Sheathed sword and pale shoulder wrap keep the small silhouette readable.
	draw_line(Vector2(-6,-9),Vector2(7,-31),Color("#1d292b"),3,true)
	draw_line(Vector2(7,-31),Vector2(9,-35),Color("#a99b73"),2,true)
	draw_line(Vector2(-5,-25),Vector2(5,-23),Color("#c0beb0"),3,true)
	draw_circle(Vector2(0,-29),5,Color("#252b2a"))
	if facing.y > 0.2:
		draw_circle(Vector2(facing.x,-28),3.3,Color("#b9a48c"))
	else:
		draw_arc(Vector2(0,-29),3.7,PI,TAU,12,Color("#55615b"),1,true)
	draw_circle(Vector2(0,-34),2.5,Color("#252b2a"))
	draw_line(Vector2(-3,-33),Vector2(3,-33),Color("#acaa8d"),1,true)
