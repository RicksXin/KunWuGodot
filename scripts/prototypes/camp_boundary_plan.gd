extends RefCounted
## Boundary topology only. Artwork and collision remain separate consumers.
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]

static func build(heights: Dictionary, stair_links: Array = [], outside_height: int = -22) -> Dictionary:
	var edges: Array = []
	var corners: Array = []
	var levels: Array = []
	var vertices := {}
	for cell: Vector2i in heights:
		var high := int(heights[cell])
		if high not in levels: levels.append(high)
		for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]: vertices[cell+offset] = true
		for direction: Vector2i in DIRECTIONS:
			var neighbor := cell+direction
			var low := int(heights.get(neighbor,outside_height))
			if low >= high: continue
			var opening := ""
			for link: Dictionary in stair_links:
				if cell==link.from and neighbor==link.to: opening = link.id
			edges.append({"cell":cell,"neighbor":neighbor,"direction":direction,"high":high,"low":low,"drop":high-low,"visible_face":direction in [Vector2i.RIGHT,Vector2i.DOWN],"stair":opening})
	levels.sort()
	for level: int in levels:
		for vertex: Vector2i in vertices:
			var mask := 0
			var around := [vertex,vertex+Vector2i.RIGHT,vertex+Vector2i.ONE,vertex+Vector2i.DOWN]
			var count := 0
			for bit in range(4):
				if int(heights.get(around[bit],outside_height)) >= level:
					mask |= 1<<bit
					count += 1
			if count==1 or count==3:
				corners.append({"vertex":vertex,"level":level,"kind":"convex" if count==1 else "concave","mask":mask})
			elif mask in [5,10]:
				# Point contacts are two separate convex corners, never a bridge.
				for bit in range(4):
					if mask & (1<<bit): corners.append({"vertex":vertex,"level":level,"kind":"convex","mask":1<<bit,"point_contact":true})
	return {"edges":edges,"corners":corners,"levels":levels}

static func summary(plan: Dictionary) -> Dictionary:
	var result := {"boundary_edges":plan.edges.size(),"visible_wall_edges":0,"stair_openings":0,"convex":0,"concave":0,"drops":{}}
	for edge: Dictionary in plan.edges:
		if edge.visible_face: result.visible_wall_edges += 1
		if edge.stair!="": result.stair_openings += 1
		var key := str(edge.drop)
		result.drops[key] = result.drops.get(key,0)+1
	for corner: Dictionary in plan.corners: result[corner.kind] += 1
	return result
