extends "res://scripts/scenes/camp.gd"

## Visual review only: sample counts are never written into Game.profile.
func _ready() -> void:
	super._ready()
	call_deferred("_open_treasury", true)
