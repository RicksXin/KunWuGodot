@tool
class_name KWMapWorld
extends Node2D

@export_range(1, 256, 1) var active_width := 15
@export_range(1, 256, 1) var active_height := 15
@export_range(1, 1024, 1) var source_tile_size := 256
@export_range(1, 256, 1) var logical_tile_size := 48

func domain_to_scene_cell(domain_cell: Vector2i) -> Vector2i:
	return Vector2i(domain_cell.x, active_height - 1 - domain_cell.y)

func scene_to_domain_cell(scene_cell: Vector2i) -> Vector2i:
	return Vector2i(scene_cell.x, active_height - 1 - scene_cell.y)

func domain_to_local(domain_cell: Vector2i) -> Vector2:
	var scene_cell := domain_to_scene_cell(domain_cell)
	return Vector2(scene_cell.x + 0.5, scene_cell.y + 0.5) * float(source_tile_size)
