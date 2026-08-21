@tool
class_name KWMap01ArrayLamp
extends Node2D

signal state_changed(state_id: String)

enum LampState {
	BROKEN,
	REVERSED,
	REPAIRED,
}

const STATE_IDS := ["LAMP_BROKEN", "LAMP_REVERSED", "LAMP_REPAIRED"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/array_lamp/array_lamp_broken.png"),
	preload("res://assets/maps/map_01/landmarks/array_lamp/array_lamp_reversed.png"),
	preload("res://assets/maps/map_01/landmarks/array_lamp/array_lamp_repaired.png"),
]

@export_enum("LAMP_BROKEN", "LAMP_REVERSED", "LAMP_REPAIRED") var lamp_state: int = LampState.BROKEN:
	set(value):
		lamp_state = clampi(int(value), LampState.BROKEN, LampState.REPAIRED)
		if is_node_ready():
			_apply_lamp_state()

@onready var state_sprite: Sprite2D = $StateSprite


func _ready() -> void:
	_apply_lamp_state()


func set_lamp_state(value: int) -> void:
	lamp_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_lamp_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[lamp_state]


func _apply_lamp_state() -> void:
	if not is_instance_valid(state_sprite):
		return
	state_sprite.texture = STATE_TEXTURES[lamp_state]
	state_changed.emit(get_state_id())
