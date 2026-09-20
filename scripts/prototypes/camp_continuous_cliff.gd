extends RefCounted
## Merge collinear exposed edges; UVs are continuous screen-space distances, not cell IDs.
const A = preload("res://assets/prototypes/camp_cliff_continuous/wall-a.png")
const RIM_A = preload("res://assets/prototypes/camp_cliff_continuous/rim-a.png")
const RIM_B = preload("res://assets/prototypes/camp_cliff_continuous/rim-b.png")
const B = preload("res://assets/prototypes/camp_cliff_continuous/wall-b.png")
const PROFILE_A = preload("res://resources/prototypes/camp_terrace_profiles/profile-a.png")
const PROFILE_B = preload("res://resources/prototypes/camp_terrace_profiles/profile-b.png")
const FRONT_CORNER = preload("res://resources/prototypes/camp_terrace_profiles/front-corner.png")

static func build(parent: Node2D, edges: Array[Dictionary], rim_parent: Node2D = null) -> void:
	var groups: Dictionary = {}
	for edge in edges:
		var start: Vector2 = edge.a if edge.a.x < edge.b.x else edge.b
		var finish: Vector2 = edge.b if edge.a.x < edge.b.x else edge.a
		var slope := (finish.y-start.y)/(finish.x-start.x)
		var key := "%s:%s:%s" % [slope,start.y-slope*start.x,edge.height]
		if not groups.has(key): groups[key] = []
		groups[key].append({"a":start,"b":finish,"height":edge.height})
	for group in groups.values():
		group.sort_custom(func(x: Dictionary,y: Dictionary): return x.a.x<y.a.x)
		var run: Dictionary = group[0].duplicate()
		for index in range(1,group.size()):
			var next: Dictionary = group[index]
			if run.b.is_equal_approx(next.a): run.b = next.b
			else:
				_draw_run(parent,run,rim_parent)
				run = next.duplicate()
		_draw_run(parent,run,rim_parent)
	# At front-facing convex vertices use the original two-face corner intact.
	if rim_parent != null:
		var endpoints: Dictionary = {}
		for edge in edges:
			var a: Vector2 = edge.a if edge.a.x < edge.b.x else edge.b
			var b: Vector2 = edge.b if edge.a.x < edge.b.x else edge.a
			var point: Vector2 = b if b.y>a.y else a
			var key := "%s:%s" % [point.x,point.y]
			if not endpoints.has(key): endpoints[key] = []
			endpoints[key].append({"point":point,"height":edge.height,"slope":signf(b.y-a.y)})
		for values in endpoints.values():
			if values.size() != 2 or values[0].slope == values[1].slope: continue
			var cap := Polygon2D.new()
			cap.texture = FRONT_CORNER
			cap.position = values[0].point-Vector2(32,28)
			# Clip the toe to the two sloping wall bases, not a rectangular sprite edge.
			var bottom := 28+minf(48,float(values[0].height))+2
			cap.polygon = PackedVector2Array([Vector2(0,0),Vector2(64,0),Vector2(64,bottom-16),Vector2(32,bottom),Vector2(0,bottom-16)])
			cap.uv = cap.polygon
			cap.set_meta("native_corner",true)
			rim_parent.add_child(cap)

static func _draw_run(parent: Node2D, run: Dictionary, rim_parent: Node2D) -> void:
	var a: Vector2 = run.a
	var b: Vector2 = run.b
	for level in range(ceili(float(run.height)/48.0)):
		var height := minf(48,float(run.height)-level*48)
		var start := a+Vector2(0,level*48)
		var finish := b+Vector2(0,level*48)
		var face := Polygon2D.new()
		face.texture = A if b.y>a.y else B
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		face.polygon = PackedVector2Array([start,finish,finish+Vector2(0,height),start+Vector2(0,height)])
		face.uv = PackedVector2Array([Vector2(a.x,0),Vector2(b.x,0),Vector2(b.x,height),Vector2(a.x,height)])
		face.set_meta("run_length",b.x-a.x)
		face.set_meta("height",height)
		parent.add_child(face)

	if rim_parent != null:
		var inset := Vector2(8,-4) if b.y>a.y else Vector2(-8,-4)
		var rim := Polygon2D.new()
		rim.texture = RIM_A if b.y>a.y else RIM_B
		rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rim.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		rim.polygon = PackedVector2Array([a,b,b+inset,a+inset])
		rim.uv = PackedVector2Array([Vector2(a.x,7),Vector2(b.x,7),Vector2(b.x+inset.x,0),Vector2(a.x+inset.x,0)])
		rim.set_meta("boundary_length",b.x-a.x)
		rim_parent.add_child(rim)
		# The complete source profile overlays the seam, including soil, lip and foot.
		# Unlike the old 8px rim this preserves the full source cross-section.
		var profile := Polygon2D.new()
		profile.texture = PROFILE_A if b.y>a.y else PROFILE_B
		profile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		profile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var depth := minf(64,float(run.height)+12)
		var along := (b-a)/(b.x-a.x)
		var taper := minf(48,(b.x-a.x)*0.5)
		profile.polygon = PackedVector2Array([a,a+along*taper-Vector2(0,24),b-along*taper-Vector2(0,24),b,b+Vector2(0,depth),a+Vector2(0,depth)])
		var coordinates := PackedVector2Array()
		for point in profile.polygon:
			coordinates.append(Vector2(point.x,point.y-(a.y+(point.x-a.x)*along.y)+24))
		profile.uv = coordinates
		profile.set_meta("full_profile",true)
		rim_parent.add_child(profile)
