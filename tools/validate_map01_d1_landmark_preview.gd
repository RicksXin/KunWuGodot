extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_landmark_preview.tscn"
const COMPOSITION_PATH := "res://art/candidates/map01_layout/map01_landmark_composition_preview_20260820.json"
const MASK_PATH := "res://art/candidates/map01_layout/map01_d1_environment_mask_20260820.json"
const SOURCE_CELL_SIZE := 256
const MAP_SCALE := Vector2(0.1875, 0.1875)
const INSTANCE_SCALE := Vector2(16.0, 16.0)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var composition := _load_json(COMPOSITION_PATH)
	var mask := _load_json(MASK_PATH)
	if composition.is_empty() or mask.is_empty():
		_finish()
		return
	_check(str(composition.get("status", "")) == "candidate_only_not_runtime", "Landmark composition must remain candidate-only")
	_check(ResourceLoader.exists(SCENE_PATH, "PackedScene"), "Landmark preview scene is missing")
	if not ResourceLoader.exists(SCENE_PATH, "PackedScene"):
		_finish()
		return

	var ground := _cell_set(mask.get("groundCells", []))
	var collision := _cell_set(mask.get("collisionBlockedCells", []))
	var occupied: Dictionary = {}
	for anchor in composition.get("anchors", []):
		var cell := _json_cell(anchor.get("documentCell", []))
		_check(ground.has(cell), "Landmark anchor %s is outside Ground" % [cell])
		_check(not collision.has(cell), "Landmark anchor %s is collision-blocked" % [cell])
		_check(not occupied.has(cell), "Landmark anchors share cell %s" % [cell])
		occupied[cell] = true
	for resolution in composition.get("conflictResolutions", []):
		var kept := _json_cell(resolution.get("keptCell", []))
		var proposed := _json_cell(resolution.get("proposedCell", []))
		_check(ground.has(kept) and not collision.has(kept), "Kept conflict cell %s is not safely walkable" % [kept])
		_check(ground.has(proposed) and not collision.has(proposed), "Proposed conflict cell %s is not safely walkable" % [proposed])
		_check(kept != proposed, "Conflict resolution did not separate %s" % [kept])

	var instance := (load(SCENE_PATH) as PackedScene).instantiate()
	_check(instance != null, "Landmark preview could not instantiate")
	if instance == null:
		_finish()
		return
	_check(instance.get_node_or_null("Environment") != null, "Environment instance is missing")
	_check(instance.find_child("Markers", true, false) == null, "Candidate preview must not contain runtime Markers")
	var camera := instance.get_node_or_null("Camera2D") as Camera2D
	_check(camera != null, "Landmark preview camera is missing")
	_check(instance.get_node_or_null("UI") is CanvasLayer, "Landmark preview controls are missing")
	var landmarks := instance.get_node_or_null("CandidateLandmarks") as Node2D
	_check(landmarks != null, "CandidateLandmarks container is missing")
	if landmarks == null:
		instance.free()
		_finish()
		return
	_check(landmarks.scale == MAP_SCALE, "CandidateLandmarks scale must match the environment map scale")
	for anchor in composition.get("anchors", []):
		var node_name := str(anchor.get("sceneNode", ""))
		var node := landmarks.get_node_or_null(node_name) as Node2D
		_check(node != null, "Landmark preview node is missing: %s" % node_name)
		if node == null:
			continue
		var cell := _json_cell(anchor.get("documentCell", []))
		_check(node.position == _source_anchor(cell), "%s position differs from candidate cell %s" % [node_name, cell])
		_check(node.scale == INSTANCE_SCALE, "%s must use the approved Map01 instance scale" % node_name)

	root.add_child(instance)
	await process_frame
	await process_frame
	_check(camera != null and camera.is_current(), "Landmark preview camera is not current")
	_check(camera != null and camera.position == Vector2(1152.0, 1536.0), "Landmark preview must open at the map center")
	_check(camera != null and camera.zoom == Vector2(0.15, 0.15), "Landmark preview must open in overview zoom")
	_check(int(instance.call("get_review_mode")) == 0, "Landmark preview must open in overview mode")
	_check((landmarks.get_node("Lamp01") as KWMap01ArrayLamp).get_state_id() == "LAMP_REVERSED", "Lamp01 preview state is incorrect")
	_check((landmarks.get_node("Lamp02") as KWMap01ArrayLamp).get_state_id() == "LAMP_BROKEN", "Lamp02 preview state is incorrect")
	_check((landmarks.get_node("Lamp03") as KWMap01ArrayLamp).get_state_id() == "LAMP_BROKEN", "Lamp03 preview state is incorrect")
	_check((landmarks.get_node("WanxiuGate") as KWWanxiuGate).get_state_id() == "GATE_LOCKED", "Gate preview state is incorrect")
	_check((landmarks.get_node("WanxiuStele") as KWMap01WanxiuStele).get_state_id() == "STELE_DEFAULT", "Stele preview state is incorrect")
	_check((landmarks.get_node("DerelictCamp") as KWMap01DerelictCamp).get_state_id() == "CAMP_CORPSES_DEFAULT", "Camp preview state is incorrect")
	var tunnel := landmarks.get_node("TunnelCandidate") as KWMap01MountainTunnel
	_check(tunnel != null, "Mountain-tunnel preview component is missing")
	_check(tunnel.get_state_id() == "TUNNEL_DEFAULT", "Mountain-tunnel preview state is incorrect")
	_check(not tunnel.is_passage_open(), "Mountain-tunnel preview must start blocked")
	_check(str(instance.call("get_tunnel_preview_state_id")) == "TUNNEL_DEFAULT", "Landmark preview did not expose its tunnel state")
	_check(bool(instance.call("set_tunnel_preview_state_id", "TUNNEL_DISCOVERED")), "Landmark preview rejected TUNNEL_DISCOVERED")
	await physics_frame
	_check(tunnel.get_state_id() == "TUNNEL_DISCOVERED" and not tunnel.is_passage_open(), "Discovered tunnel preview must remain blocked")
	_check(bool(instance.call("set_tunnel_preview_state_id", "TUNNEL_CLEARED")), "Landmark preview rejected TUNNEL_CLEARED")
	await physics_frame
	_check(tunnel.get_state_id() == "TUNNEL_CLEARED" and tunnel.is_passage_open(), "Cleared tunnel preview did not open")
	_check(bool(instance.call("set_tunnel_preview_state_id", "TUNNEL_DEFAULT")), "Landmark preview could not restore TUNNEL_DEFAULT")
	await physics_frame
	var stairs := landmarks.get_node("StairsCandidate") as KWMap01EastWallStairs
	_check(stairs.get_state_id() == "STAIRS_CLOSED", "East-wall stair preview state is incorrect")
	_check(not stairs.is_passage_open(), "East-wall stair preview must start closed")
	_check(str(instance.call("get_stairs_preview_state_id")) == "STAIRS_CLOSED", "Landmark preview did not expose its stair state")
	instance.call("set_stairs_preview_open", true)
	await process_frame
	_check(stairs.get_state_id() == "STAIRS_OPEN" and stairs.is_passage_open(), "Landmark preview could not show the open stair state")
	instance.call("set_stairs_preview_open", false)
	await process_frame
	_check(stairs.get_state_id() == "STAIRS_CLOSED" and not stairs.is_passage_open(), "Landmark preview could not restore the closed stair state")
	_check(tunnel.get_node_or_null("StayBaseSprite") is Sprite2D, "Tunnel structural base is missing")
	_check(tunnel.get_node_or_null("StateSprite") is Sprite2D, "Tunnel state layer is missing")
	_check(tunnel.get_node_or_null("RoofForeground") is Sprite2D, "Tunnel foreground roof is missing")
	root.remove_child(instance)
	instance.free()
	await process_frame
	await process_frame
	_finish()


func _source_anchor(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * SOURCE_CELL_SIZE, float(cell.y + 1) * SOURCE_CELL_SIZE)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_check(false, "Missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check(false, "Invalid JSON: %s" % path)
		return {}
	return parsed


func _cell_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[_json_cell(value)] = true
	return result


func _json_cell(value: Array) -> Vector2i:
	if value.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(value[0]), int(value[1]))


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP01_D1_LANDMARK_PREVIEW_VALIDATION_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP01_D1_LANDMARK_PREVIEW_VALIDATION_FAILED: %d error(s)" % failures.size())
	quit(1)
