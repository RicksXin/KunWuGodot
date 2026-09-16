extends "res://scripts/scenes/camp.gd"

func _ready() -> void:
	super._ready()
	call_deferred("_open_market", true)
