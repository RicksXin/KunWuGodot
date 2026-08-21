@tool
class_name KWMap01MountainTunnel
extends Node2D

signal state_changed(state_id: String, passage_open: bool)
signal occluder_fade_changed(faded: bool)

enum TunnelState {
	DEFAULT,
	DISCOVERED,
	CLEARED,
}

const STATE_IDS := ["TUNNEL_DEFAULT", "TUNNEL_DISCOVERED", "TUNNEL_CLEARED"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/mountain_tunnel/tunnel_default_state.png"),
	preload("res://assets/maps/map_01/landmarks/mountain_tunnel/tunnel_discovered_state.png"),
	preload("res://assets/maps/map_01/landmarks/mountain_tunnel/tunnel_cleared_state.png"),
]

@export_enum("TUNNEL_DEFAULT", "TUNNEL_DISCOVERED", "TUNNEL_CLEARED") var tunnel_state: int = TunnelState.DEFAULT:
	set(value):
		tunnel_state = clampi(int(value), TunnelState.DEFAULT, TunnelState.CLEARED)
		if is_node_ready():
			_apply_tunnel_state()
@export_range(0.0, 1.0, 0.01) var faded_alpha := 0.22
@export_range(0.0, 8.0, 0.1) var fade_speed := 2.8

@onready var state_sprite: Sprite2D = $StateSprite
@onready var foreground_sprite: Sprite2D = $RoofForeground
@onready var center_barrier_collision: CollisionShape2D = $CenterBarrier/CollisionShape2D

var _foreground_target_alpha := 1.0


func _ready() -> void:
	_apply_tunnel_state()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if is_equal_approx(foreground_sprite.modulate.a, _foreground_target_alpha):
		return
	var color := foreground_sprite.modulate
	color.a = move_toward(color.a, _foreground_target_alpha, delta * fade_speed)
	foreground_sprite.modulate = color


func set_tunnel_state(value: int) -> void:
	tunnel_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_tunnel_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[tunnel_state]


func is_passage_open() -> bool:
	return tunnel_state == TunnelState.CLEARED


func set_occluder_faded(faded: bool, immediate: bool = false) -> void:
	_foreground_target_alpha = faded_alpha if faded else 1.0
	if immediate and is_instance_valid(foreground_sprite):
		var color := foreground_sprite.modulate
		color.a = _foreground_target_alpha
		foreground_sprite.modulate = color
	occluder_fade_changed.emit(faded)


func get_foreground_alpha() -> float:
	if not is_instance_valid(foreground_sprite):
		return _foreground_target_alpha
	return foreground_sprite.modulate.a


func _apply_tunnel_state() -> void:
	if not is_instance_valid(state_sprite) or not is_instance_valid(center_barrier_collision):
		return
	state_sprite.texture = STATE_TEXTURES[tunnel_state]
	var passage_open := is_passage_open()
	center_barrier_collision.set_deferred("disabled", passage_open)
	state_changed.emit(get_state_id(), passage_open)
