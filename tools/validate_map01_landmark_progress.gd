extends SceneTree

const CONTRACT_PATH := "res://data/maps/map_01_landmark_state_contract.json"
const AUDIT_PATH := "res://art/candidates/map01_layout/map01_landmark_coordinate_audit_20260820.json"
const DEMO_PATH := "res://scenes/map01_landmark_progress_demo.tscn"

var failures: Array[String] = []


func _init() -> void:
	_validate_contracts()
	await _validate_progress_controller()
	_finish()


func _validate_contracts() -> void:
	var contract := _load_json(CONTRACT_PATH)
	_check(str(contract.get("status", "")) == "d1_state_contract", "Map01 landmark state contract status is invalid")
	var integration: Dictionary = contract.get("layoutIntegration", {})
	_check(not bool(integration.get("formalCoordinatesFrozen", true)), "Formal Map01 coordinates must remain explicitly unfrozen")
	_check(not bool(integration.get("runtimeSceneMutationAllowed", true)), "Landmark state contract must not authorize formal scene mutation")
	var lamps: Array = contract.get("lamps", [])
	_check(lamps.size() == 3, "Landmark state contract must define three independent lamps")
	if lamps.size() == 3:
		_check(str(lamps[0].get("initialState", "")) == "LAMP_REVERSED", "First lamp must expose the scripted initial reverse-array state")
		_check(str(lamps[1].get("initialState", "")) == "LAMP_BROKEN", "Second lamp must default to the broken visual state")
		_check(str(lamps[2].get("initialState", "")) == "LAMP_BROKEN", "Third lamp must default to the broken visual state")
	var audit := _load_json(AUDIT_PATH)
	_check(str(audit.get("status", "")) == "candidate_only_not_runtime", "Coordinate audit must remain candidate-only")
	_check((audit.get("knownConflicts", []) as Array).size() == 2, "Coordinate audit must preserve both unresolved shared-cell conflicts")
	var candidates: Array = audit.get("legacyLandmarkCandidates", [])
	_check(candidates.size() == 5, "Coordinate audit must retain the three lamps, Boss and exit candidates")
	for source in audit.get("sources", []):
		var path := str(source.get("path", ""))
		if not path.ends_with(".png"):
			continue
		_check(FileAccess.file_exists(path), "Archived graybox source is missing: %s" % path)
		if FileAccess.file_exists(path):
			_check(FileAccess.get_sha256(path) == str(source.get("sha256", "")), "Archived graybox SHA-256 changed: %s" % path)


func _validate_progress_controller() -> void:
	_check(ResourceLoader.exists(DEMO_PATH, "PackedScene"), "Map01 landmark progress demo is missing")
	if not ResourceLoader.exists(DEMO_PATH, "PackedScene"):
		return
	var demo := (load(DEMO_PATH) as PackedScene).instantiate()
	root.add_child(demo)
	await process_frame
	var progress := demo.get_node_or_null("LandmarkProgress") as KWMap01LandmarkProgress
	var gate := demo.get_node_or_null("WanxiuGate") as KWWanxiuGate
	_check(progress != null, "Map01 landmark progress controller is missing")
	_check(gate != null, "Map01 landmark progress demo must instantiate Wanxiu Gate")
	if progress == null or gate == null:
		demo.queue_free()
		return
	_check(progress.get_lamp_state("m1_event_lamp_01") == "LAMP_REVERSED", "First lamp initial state must be LAMP_REVERSED")
	_check(progress.get_lamp_state("m1_event_lamp_02") == "LAMP_BROKEN", "Second lamp initial state must be LAMP_BROKEN")
	_check(progress.get_lamp_state("m1_event_lamp_03") == "LAMP_BROKEN", "Third lamp initial state must be LAMP_BROKEN")
	_check(progress.get_gate_state_id() == "GATE_LOCKED", "Gate must start locked")
	_check(not gate.is_center_passage_open(), "Initial locked gate must block the center")

	var before_invalid := progress.get_lamp_states()
	_check(not progress.set_lamp_state("NOT_A_LAMP", "LAMP_REPAIRED"), "Controller must reject an unknown lamp ID")
	_check(not progress.set_lamp_state("m1_event_lamp_01", "NOT_A_STATE"), "Controller must reject an unknown lamp state")
	_check(progress.get_lamp_states() == before_invalid, "Rejected state update must be atomic")

	_check(progress.set_lamp_state("m1_event_lamp_01", "LAMP_REPAIRED"), "Could not repair first lamp")
	_check(progress.get_gate_state_id() == "GATE_LOCKED", "One repaired lamp must not unlock the gate")
	_check(progress.set_lamp_state("m1_event_lamp_02", "LAMP_REPAIRED"), "Could not repair second lamp")
	_check(progress.get_gate_state_id() == "GATE_LOCKED", "Two repaired lamps must not unlock the gate")
	_check(progress.set_lamp_state("m1_event_lamp_03", "LAMP_REPAIRED"), "Could not repair third lamp")
	await physics_frame
	_check(progress.get_repaired_count() == 3, "Controller must report all three repaired lamps")
	_check(progress.get_gate_state_id() == "GATE_BOSS_READY", "Three repaired lamps must enter GATE_BOSS_READY")
	_check(not gate.is_center_passage_open(), "GATE_BOSS_READY must keep the center blocked")

	progress.set_boss_defeated(true)
	await physics_frame
	_check(progress.get_gate_state_id() == "GATE_OPEN", "Boss defeat after three repairs must open the gate")
	_check(gate.is_center_passage_open(), "GATE_OPEN must release the center passage")
	progress.set_lamp_state("m1_event_lamp_02", "LAMP_BROKEN")
	await physics_frame
	_check(progress.get_gate_state_id() == "GATE_LOCKED", "A regressed lamp must relock the gate even if Boss is defeated")
	_check(not gate.is_center_passage_open(), "Relocked gate must restore its center collision")
	demo.queue_free()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_check(false, "Missing JSON contract: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check(false, "Invalid JSON contract: %s" % path)
		return {}
	return parsed


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Map01 landmark progress validation OK; independent lamps, derived gate state, Boss gating and coordinate audit verified")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
