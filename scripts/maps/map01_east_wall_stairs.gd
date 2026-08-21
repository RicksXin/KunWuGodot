@tool
class_name KWMap01EastWallStairs
extends Node2D

signal state_changed(state_id: String, passage_open: bool)

enum StairsState {
	CLOSED,
	OPEN,
}

const STATE_IDS := ["STAIRS_CLOSED", "STAIRS_OPEN"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/east_wall_stairs/stairs_closed.png"),
	preload("res://assets/maps/map_01/landmarks/east_wall_stairs/stairs_open.png"),
]

@export_enum("STAIRS_CLOSED", "STAIRS_OPEN") var stairs_state: int = StairsState.CLOSED:
	set(value):
		stairs_state = clampi(int(value), StairsState.CLOSED, StairsState.OPEN)
		if is_node_ready():
			_apply_stairs_state()

@onready var state_sprite: Sprite2D = $StateSprite
@onready var closed_barrier_collision: CollisionShape2D = $StaticBody2D/ClosedBarrierCollision


func _ready() -> void:
	_apply_stairs_state()


func set_stairs_state(value: int) -> void:
	stairs_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_stairs_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[stairs_state]


func is_passage_open() -> bool:
	return stairs_state == StairsState.OPEN


func _apply_stairs_state() -> void:
	if not is_instance_valid(state_sprite) or not is_instance_valid(closed_barrier_collision):
		return
	state_sprite.texture = STATE_TEXTURES[stairs_state]
	closed_barrier_collision.disabled = is_passage_open()
	state_changed.emit(get_state_id(), is_passage_open())
