@tool
extends RefCounted
const Collision = preload("res://scripts/prototypes/camp_collision.gd")
const PATH := "res://data/prototypes/camp_tile_rebuild.json"
var data: Dictionary = {}
var disk_text := ""
var undo_states: Array[Dictionary] = []
var dirty := false
func load_file(path: String = PATH) -> String:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("buildings") or not parsed.has("cells"):
		return "读取失败：布局文件不是有效的营地 JSON。"
	data = parsed
	disk_text = text
	undo_states.clear()
	dirty = false
	return ""
func items() -> Array:
	# Concatenation keeps references to the dictionaries in their separate JSON lists.
	return data.get("buildings",[]) + data.get("decorations",[]) + ([data.portal] if data.has("portal") else [])
func checkpoint() -> void:
	undo_states.append(data.duplicate(true))
	if undo_states.size() > 60: undo_states.pop_front()
func undo() -> void:
	if undo_states.is_empty(): return
	data = undo_states.pop_back()
	dirty = true
func heights() -> Dictionary:
	var result := {}
	for c in data.cells: result[Vector2i(c[0], c[1])] = c[2]
	return result
static func flat(cell: Vector2) -> Vector2:
	return Vector2((cell.x-cell.y)*64, (cell.x+cell.y)*32)
func point(cell: Vector2i) -> Vector2:
	return flat(cell)-Vector2(0, heights().get(cell, 0))
func translate(index: int, offset: Vector2i) -> void:
	var item: Dictionary = items()[index]
	for key in ["origin", "door", "approach"]:
		if item.has(key): item[key] = [int(item[key][0])+offset.x, int(item[key][1])+offset.y]
	dirty = true
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var h := heights()
	var blocked := {}
	var stairs := {}
	for stair in data.stairs: stairs[Vector2i(stair.cell[0], stair.cell[1])] = stair
	var footprints := Collision.polygons(data)
	for cell: Vector2i in h:
		if Collision.contains(point(cell),footprints):
			blocked[cell] = true
			if stairs.has(cell): errors.append("建筑碰撞挡住阶梯 %s" % str(cell))
	for c in data.get("west_courtyard",{}).get("reserved_cells",[]):
		if blocked.has(Vector2i(c[0],c[1])): errors.append("建筑挡住保留院路 %s" % str(c))
	if not errors.is_empty(): return errors
	var start := Vector2i(data.spawn[0],data.spawn[1])
	if not h.has(start) or blocked.has(start): return PackedStringArray(["出生点被挡住。"])
	var visited := {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for axis in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+axis
			if not h.has(next) or blocked.has(next) or visited.has(next): continue
			var can_move: bool = h[current]==h[next]
			for cell in [current,next]:
				if stairs.has(cell):
					var st: Dictionary = stairs[cell]
					var other: Vector2i = next if cell==current else current
					can_move = other==Vector2i(st.from[0],st.from[1]) or other==Vector2i(st.to[0],st.to[1])
					break
			if can_move and not Collision.crosses(point(current),point(next),footprints):
				visited[next] = true
				queue.append(next)
	if visited.size() != h.size()-blocked.size(): errors.append("摆放切断了通路：%d 个可走格不可达。" % (h.size()-blocked.size()-visited.size()))
	return errors
func save(path: String = PATH) -> String:
	if FileAccess.get_file_as_string(path) != disk_text: return "未保存：磁盘文件已被其他操作修改，请重新读取后再调整。"
	var temporary := path+".layout-tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "未保存：无法写入临时文件。"
	var output := JSON.stringify(data,"  ",false)+"\n"
	file.store_string(output)
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
	if result != OK: return "未保存：文件替换失败（%s）。" % result
	disk_text = output
	dirty = false
	return ""
