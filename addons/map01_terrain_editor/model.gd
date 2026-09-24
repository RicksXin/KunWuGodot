@tool
extends RefCounted
const PATH := "res://data/maps/map_01.json"
var data_path := PATH
var cells: Dictionary = {}
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var saved_cells: Dictionary = {}
var disk_revision := ""
var extent := Vector2i(24, 32)
var spawn := Vector2(10,27)
var regions: Array = []
var placements: Array = []
var rest_areas: Array = []
var objects: Dictionary = {}
const TILE := Vector2(96, 48)
const RISE := 32.0

func load_data() -> Error:
	var data = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary: return ERR_PARSE_ERROR
	var authoring: Dictionary = data.get("terrainAuthoring", {})
	var dimensions: Array = authoring.get("extent",[24,32])
	extent = Vector2i(dimensions[0],dimensions[1])
	var origin: Array = authoring.get("spawn",[10,27])
	spawn = Vector2(origin[0],origin[1])
	regions = authoring.get("regions",[])
	placements = authoring.get("placements",[])
	rest_areas = authoring.get("restAreas",[])
	objects.clear()
	for object in data.get("objects",[]): objects[object.id] = object
	cells.clear()
	for item in data.get("terrainAuthoring", {}).get("cells", []):
		cells[Vector2i(item.x, item.y)] = {"height": int(item.height), "kind": str(item.kind)}
	saved_cells = cells.duplicate(true)
	disk_revision = JSON.stringify(data.get("terrainAuthoring", {}))
	return OK

func checkpoint() -> void:
	history.append(cells.duplicate(true))
	if history.size() > 80: history.pop_front()
	future.clear()

func undo() -> void:
	if history.is_empty(): return
	future.append(cells.duplicate(true))
	cells = history.pop_back()

func redo() -> void:
	if future.is_empty(): return
	history.append(cells.duplicate(true))
	cells = future.pop_back()

func paint(cell: Vector2i, height: int, kind: String, erase := false) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= extent.x or cell.y >= extent.y: return
	if erase: cells.erase(cell)
	else: cells[cell] = {"height": clampi(height, 1 if kind == "stairs" else 0, 5), "kind": kind}

func point(cell: Vector2i, height := 0) -> Vector2:
	return Vector2((cell.x-cell.y)*TILE.x/2, (cell.x+cell.y)*TILE.y/2-height*RISE)

func ordered_cells() -> Array:
	var result := cells.keys()
	result.sort_custom(func(a, b): return a.x+a.y < b.x+b.y if a.x+a.y != b.x+b.y else a.x < b.x)
	return result

func diamond(cell: Vector2i, height: int) -> PackedVector2Array:
	var p := point(cell, height)
	return PackedVector2Array([p+Vector2(0,-24), p+Vector2(48,0), p+Vector2(0,24), p+Vector2(-48,0)])

func pick(world: Vector2, flat_view := false) -> Vector2i:
	var ordered := ordered_cells()
	ordered.reverse()
	for cell in ordered:
		if Geometry2D.is_point_in_polygon(world, surface_polygon(cell, flat_view)): return cell
	return Vector2i(roundi(world.x/TILE.x+world.y/TILE.y), roundi(world.y/TILE.y-world.x/TILE.x))

func save() -> Error:
	# Merge only the authoring field into the latest file; preserve gameplay edits.
	var data = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary: return ERR_PARSE_ERROR
	if JSON.stringify(data.get("terrainAuthoring", {})) != disk_revision: return ERR_BUSY
	var rows: Array = []
	for cell in ordered_cells():
		rows.append({"x": cell.x, "y": cell.y, "height": cells[cell].height, "kind": cells[cell].kind})
	var authoring: Dictionary = data.get("terrainAuthoring",{}).duplicate(true)
	authoring.merge({"status": "graybox_pending_review", "schemaVersion": 1,
		"coordinateSystem": "isometric_authoring_cells", "extent": [extent.x,extent.y],
		"spawn": [spawn.x,spawn.y], "tileSize": [96,48], "heightStep": 32,
		"runtimeEnabled": false, "cells": rows},true)
	data.terrainAuthoring = authoring
	var pending := data_path + ".terrain-tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  ", true, true) + "\n")
	file.close()
	var error := DirAccess.rename_absolute(pending, data_path)
	if error == OK:
		saved_cells = cells.duplicate(true)
		disk_revision = JSON.stringify(data.terrainAuthoring)
	return error

# Authoring traversal uses these same surfaces for drawing and foot placement.
func cell_at(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x+0.5), floori(position.y+0.5))

func elevation(position: Vector2, cell: Vector2i) -> float:
	var item: Dictionary = cells.get(cell,{})
	var level := float(item.get("height",0))
	if item.get("kind","") == "stairs":
		level -= clampf(position.y-cell.y+0.5,0,1)
	return level*RISE

func surface(position: Vector2, cell: Vector2i) -> Vector2:
	return Vector2((position.x-position.y)*TILE.x/2,(position.x+position.y)*TILE.y/2-elevation(position,cell))

func surface_polygon(cell: Vector2i, flat := false) -> PackedVector2Array:
	if flat: return diamond(cell,0)
	var points := PackedVector2Array()
	for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
		points.append(surface(Vector2(cell)+offset,cell))
	return points

func walkable(cell: Vector2i) -> bool:
	return cells.has(cell) and cells[cell].kind != "rock"

func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not walkable(a) or not walkable(b): return false
	if a == b: return true
	var delta := b-a
	if absi(delta.x)+absi(delta.y) != 1: return false
	var edge := (Vector2(a)+Vector2(b))*0.5
	# Both endpoints must agree; stair sides cannot become accidental ledges.
	var tangent := Vector2(0,0.49) if delta.x != 0 else Vector2(0.49,0)
	for p in [edge,edge+tangent,edge-tangent]:
		if absf(elevation(p,a)-elevation(p,b)) > 0.01: return false
	return true

func connected(a: Vector2i, b: Vector2i) -> bool:
	if a == b: return walkable(a)
	if absi(a.x-b.x)+absi(a.y-b.y) == 1: return can_step(a,b)
	if absi(a.x-b.x)==1 and absi(a.y-b.y)==1:
		var x := Vector2i(b.x,a.y)
		var y := Vector2i(a.x,b.y)
		return can_step(a,x) and can_step(x,b) and can_step(a,y) and can_step(y,b)
	return false

func can_stand(position: Vector2) -> bool:
	var center := cell_at(position)
	if not walkable(center): return false
	for offset in [Vector2(-0.12,-0.12),Vector2(0.12,-0.12),Vector2(0.12,0.12),Vector2(-0.12,0.12)]:
		if not connected(center,cell_at(position+offset)): return false
	return true

func move_actor(position: Vector2, delta: Vector2) -> Vector2:
	var count := maxi(1,ceili(delta.length()/0.04))
	var step := delta/float(count)
	var cursor := position
	for i in range(count):
		var next := cursor+step
		if not connected(cell_at(cursor),cell_at(next)) or not can_stand(next): break
		cursor = next
	return cursor

func route_between(start: Vector2i, target: Vector2i) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not walkable(start) or not walkable(target): return result
	var queue: Array[Vector2i] = [start]
	var previous := {start:start}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if current == target: break
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+offset
			if not previous.has(next) and can_step(current,next):
				previous[next] = current
				queue.append(next)
	if not previous.has(target): return result
	var cursor := target
	while cursor != start:
		result.push_front(Vector2(cursor))
		cursor = previous[cursor]
	return result

func nearby_placement(position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 1.5
	for placement in placements:
		var at := Vector2(placement.cell[0],placement.cell[1])
		var gap := position.distance_to(at)
		if gap < distance:
			distance = gap
			nearest = placement
	return nearest
