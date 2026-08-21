@tool
class_name KWMap01WanxiuStele
extends Node2D

signal state_changed(state_id: String)

enum SteleState {
	DEFAULT,
	INTERACTED,
	C07_RESERVED,
}

const STATE_IDS := ["STELE_DEFAULT", "STELE_INTERACTED", "STELE_C07_RESERVED"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/wanxiu_stele/wanxiu_stele_default.png"),
	preload("res://assets/maps/map_01/landmarks/wanxiu_stele/wanxiu_stele_interacted.png"),
	preload("res://assets/maps/map_01/landmarks/wanxiu_stele/wanxiu_stele_c07_reserved.png"),
]

@export_enum("STELE_DEFAULT", "STELE_INTERACTED", "STELE_C07_RESERVED") var stele_state: int = SteleState.DEFAULT:
	set(value):
		stele_state = clampi(int(value), SteleState.DEFAULT, SteleState.C07_RESERVED)
		if is_node_ready():
			_apply_stele_state()

@onready var state_sprite: Sprite2D = $StateSprite


func _ready() -> void:
	_apply_stele_state()


func set_stele_state(value: int) -> void:
	stele_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_stele_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[stele_state]


func _apply_stele_state() -> void:
	if not is_instance_valid(state_sprite):
		return
	state_sprite.texture = STATE_TEXTURES[stele_state]
	state_changed.emit(get_state_id())
