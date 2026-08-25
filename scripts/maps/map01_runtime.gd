@tool
class_name KWMap01Runtime
extends Node2D

@export var active_width := 28
@export var active_height := 64


func sync_player_occluders(_domain_position: Dictionary) -> void:
	# The approved full-map background has no separate foreground occluder layer.
	pass
