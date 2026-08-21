@tool
class_name KWMap01D1Environment
extends KWMapWorld

const NORMAL_FOREGROUND_ALPHA := 1.0
const FADED_FOREGROUND_ALPHA := 0.22

@onready var ground: TileMapLayer = $Ground
@onready var road_visual: TileMapLayer = $RoadVisual
@onready var difficult_terrain: TileMapLayer = $DifficultTerrain
@onready var difficult_visual: TileMapLayer = $DifficultVisual
@onready var foreground_visual: Sprite2D = $ForegroundVisual


func set_foreground_faded(faded: bool) -> void:
	var color := foreground_visual.modulate
	color.a = FADED_FOREGROUND_ALPHA if faded else NORMAL_FOREGROUND_ALPHA
	foreground_visual.modulate = color
