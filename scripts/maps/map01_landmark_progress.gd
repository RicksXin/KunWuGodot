class_name KWMap01LandmarkProgress
extends Node

signal progress_changed(repaired_count: int, gate_state_id: String, boss_defeated: bool)

const LAMP_IDS := ["m1_event_lamp_01", "m1_event_lamp_02", "m1_event_lamp_03"]
const LAMP_STATE_IDS := ["LAMP_BROKEN", "LAMP_REVERSED", "LAMP_REPAIRED"]
const DEFAULT_LAMP_STATES := {
	"m1_event_lamp_01": "LAMP_REVERSED",
	"m1_event_lamp_02": "LAMP_BROKEN",
	"m1_event_lamp_03": "LAMP_BROKEN",
}

@export var lamp_01_path: NodePath
@export var lamp_02_path: NodePath
@export var lamp_03_path: NodePath
@export var gate_path: NodePath

var _lamp_states: Dictionary = DEFAULT_LAMP_STATES.duplicate(true)
var _lamp_nodes: Dictionary = {}
var _gate: KWWanxiuGate
var _boss_defeated := false
var _gate_state_id := "GATE_LOCKED"


func _ready() -> void:
	_resolve_visual_nodes()
	_apply_visual_state()


func set_lamp_state(lamp_id: String, state_id: String) -> bool:
	return apply_external_state({lamp_id: state_id}, _boss_defeated)


func get_lamp_state(lamp_id: String) -> String:
	return str(_lamp_states.get(lamp_id, ""))


func get_lamp_states() -> Dictionary:
	return _lamp_states.duplicate(true)


func set_boss_defeated(defeated: bool) -> void:
	_boss_defeated = defeated
	_apply_visual_state()


func is_boss_defeated() -> bool:
	return _boss_defeated


func get_repaired_count() -> int:
	var count := 0
	for lamp_id in LAMP_IDS:
		if get_lamp_state(lamp_id) == "LAMP_REPAIRED":
			count += 1
	return count


func are_all_lamps_repaired() -> bool:
	return get_repaired_count() == LAMP_IDS.size()


func get_gate_state_id() -> String:
	return _gate_state_id


func apply_external_state(lamp_states: Dictionary, boss_defeated: bool) -> bool:
	for lamp_id in lamp_states:
		if not LAMP_IDS.has(str(lamp_id)) or not LAMP_STATE_IDS.has(str(lamp_states[lamp_id])):
			return false
	for lamp_id in lamp_states:
		_lamp_states[str(lamp_id)] = str(lamp_states[lamp_id])
	_boss_defeated = boss_defeated
	_apply_visual_state()
	return true


func reset_default_state() -> void:
	_lamp_states = DEFAULT_LAMP_STATES.duplicate(true)
	_boss_defeated = false
	_apply_visual_state()


func _resolve_visual_nodes() -> void:
	_lamp_nodes = {
		LAMP_IDS[0]: get_node_or_null(lamp_01_path),
		LAMP_IDS[1]: get_node_or_null(lamp_02_path),
		LAMP_IDS[2]: get_node_or_null(lamp_03_path),
	}
	_gate = get_node_or_null(gate_path) as KWWanxiuGate


func _apply_visual_state() -> void:
	_gate_state_id = _derive_gate_state_id()
	for lamp_id in LAMP_IDS:
		var lamp := _lamp_nodes.get(lamp_id) as KWMap01ArrayLamp
		if lamp != null:
			lamp.set_state_id(get_lamp_state(lamp_id))
	if _gate != null:
		_gate.set_state_id(_gate_state_id)
	progress_changed.emit(get_repaired_count(), _gate_state_id, _boss_defeated)


func _derive_gate_state_id() -> String:
	if not are_all_lamps_repaired():
		return "GATE_LOCKED"
	if _boss_defeated:
		return "GATE_OPEN"
	return "GATE_BOSS_READY"
