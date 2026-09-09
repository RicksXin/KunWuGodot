extends Node2D
var definition: Dictionary
func _draw() -> void:
	if not Game.profile.get("expedition") is Dictionary: return
	var cell := float(definition.get("fogCellSize",48))
	var size := Vector2(definition.worldSize[0],definition.worldSize[1])
	var player := Game.expedition_world_position()
	var radius := float(Game.get_expedition_map_rule().get("discoveryRadius",2))*cell
	var revealed: Array = Game.profile.get("expedition",{}).get("revealedTiles",[])
	for y in ceili(size.y/cell):
		for x in ceili(size.x/cell):
			var center := Vector2(x+0.5,y+0.5)*cell
			if player.distance_to(center) <= radius: continue
			var alpha := 0.32 if ("%d:%d" % [x,y]) in revealed else 0.94
			draw_rect(Rect2(Vector2(x,y)*cell,Vector2(minf(cell,size.x-x*cell),minf(cell,size.y-y*cell))),Color(0.025,0.04,0.045,alpha))
