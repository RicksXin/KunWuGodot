@tool
class_name KWMap01DerelictCamp
extends Node2D

signal corpse_state_changed(state_id: String)

enum CorpseState {
	DEFAULT,
	PROCESSED,
}

const STATE_IDS := ["CAMP_CORPSES_DEFAULT", "CAMP_CORPSES_PROCESSED"]
const STATE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/maps/map_01/landmarks/derelict_camp/camp_corpses_default_overlay.png"),
	preload("res://assets/maps/map_01/landmarks/derelict_camp/camp_corpses_processed_overlay.png"),
]

@export_enum("CAMP_CORPSES_DEFAULT", "CAMP_CORPSES_PROCESSED") var corpse_state: int = CorpseState.DEFAULT:
	set(value):
		corpse_state = clampi(int(value), CorpseState.DEFAULT, CorpseState.PROCESSED)
		if is_node_ready():
			_apply_corpse_state()

@onready var corpse_evidence_sprite: Sprite2D = $CorpseEvidenceSprite


func _ready() -> void:
	_apply_corpse_state()


func set_corpse_state(value: int) -> void:
	corpse_state = value


func set_state_id(state_id: String) -> bool:
	var index := STATE_IDS.find(state_id)
	if index < 0:
		return false
	set_corpse_state(index)
	return true


func get_state_id() -> String:
	return STATE_IDS[corpse_state]


func _apply_corpse_state() -> void:
	if not is_instance_valid(corpse_evidence_sprite):
		return
	corpse_evidence_sprite.texture = STATE_TEXTURES[corpse_state]
	corpse_state_changed.emit(get_state_id())
