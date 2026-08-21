@tool
class_name KWWanxiuGate
extends Node2D

signal state_changed(state_id: String, center_passage_open: bool)

enum GateState {
	LOCKED,
	BOSS_READY,
	OPEN,
}

const STATE_IDS := ["GATE_LOCKED", "GATE_BOSS_READY", "GATE_OPEN"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/wanxiu_gate/gate_locked_seal.png"),
	preload("res://assets/maps/map_01/landmarks/wanxiu_gate/gate_boss_ready_seal.png"),
	preload("res://assets/maps/map_01/landmarks/wanxiu_gate/gate_open_array.png"),
]

@export_enum("GATE_LOCKED", "GATE_BOSS_READY", "GATE_OPEN") var gate_state: int = GateState.LOCKED:
	set(value):
		gate_state = clampi(int(value), GateState.LOCKED, GateState.OPEN)
		if is_node_ready():
			_apply_gate_state()
@export_range(0.0, 1.0, 0.01) var faded_alpha := 0.22
@export_range(0.0, 8.0, 0.1) var fade_speed := 2.8

@onready var state_sprite: Sprite2D = $GateState
@onready var foreground_sprite: Sprite2D = $GateTopForeground
@onready var center_barrier: CollisionShape2D = $CenterBarrier/CollisionShape2D

var _foreground_target_alpha := 1.0


func _ready() -> void:
	_apply_gate_state()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if is_equal_approx(foreground_sprite.modulate.a, _foreground_target_alpha):
		return
	var color := foreground_sprite.modulate
	color.a = move_toward(color.a, _foreground_target_alpha, delta * fade_speed)
	foreground_sprite.modulate = color


func set_gate_state(value: int) -> void:
	gate_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_gate_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[gate_state]


func is_center_passage_open() -> bool:
	return gate_state == GateState.OPEN


func set_occluder_faded(faded: bool, immediate: bool = false) -> void:
	_foreground_target_alpha = faded_alpha if faded else 1.0
	if immediate and is_instance_valid(foreground_sprite):
		var color := foreground_sprite.modulate
		color.a = _foreground_target_alpha
		foreground_sprite.modulate = color


func get_foreground_alpha() -> float:
	if not is_instance_valid(foreground_sprite):
		return _foreground_target_alpha
	return foreground_sprite.modulate.a


func _apply_gate_state() -> void:
	if not is_instance_valid(state_sprite) or not is_instance_valid(center_barrier):
		return
	state_sprite.texture = STATE_TEXTURES[gate_state]
	var passage_open := is_center_passage_open()
	center_barrier.set_deferred("disabled", passage_open)
	state_changed.emit(get_state_id(), passage_open)
