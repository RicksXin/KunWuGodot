@tool
extends AnimatedSprite2D
## Callers supply business state; presentation never writes Game.
const FRAMES = preload("res://assets/maps/map_01/formation_lamp/formation_lamp_frames.tres")
const REPAIR_SECONDS := 2.0
var target_animation: StringName = &"broken"
var configured := false

static func animation_for_state(state: String) -> StringName:
	return &"active" if state == "LAMP_REPAIRED" else &"broken"

func configure(state: String, display_width: float = 54.0) -> void:
	visible = false
	sprite_frames = FRAMES
	centered = false
	offset = -Vector2(128,350)
	scale = Vector2.ONE * display_width / 224.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not animation_finished.is_connected(_finish_repair):
		animation_finished.connect(_finish_repair)
	# Loading a saved repaired lamp must not replay the repair ceremony.
	target_animation = animation_for_state(state)
	play(target_animation)
	configured = true
	visible = true

func apply_state(state: String) -> void:
	var desired := animation_for_state(state)
	if not configured:
		configure(state)
		return
	if target_animation == desired: return
	var previous := target_animation
	target_animation = desired
	play(&"repair" if previous == &"broken" and desired == &"active" else desired)

func _finish_repair() -> void:
	if animation == &"repair" and target_animation == &"active":
		play(&"active")
