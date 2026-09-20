extends RefCounted
## Reusable boundary rails; the logical terrain remains the source of truth.
const POST = preload("res://resources/prototypes/camp_railings/post.png")
static func build(parent: Node2D, heights: Dictionary, stairs: Dictionary, height: int) -> void:
	var root := Node2D.new()
	root.name = "Railings"
	parent.add_child(root)
	var posts: Dictionary = {}
	# A short rail beside each upper stair approach, never a perimeter fence.
	var short_sections: Dictionary = {}
	for stair in stairs.values():
		if int(stair.high) != height: continue
		var upper := Vector2i(stair.from[0],stair.from[1])
		var offset := Vector2i.DOWN if stair.axis == "x" else Vector2i.LEFT
		var outward := Vector2i.RIGHT if stair.axis == "x" else Vector2i.DOWN
		short_sections[upper+offset] = outward
	var directions := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
	for cell: Vector2i in heights:
		if heights[cell] != height or stairs.has(cell) or not short_sections.has(cell): continue
		for axis: Vector2i in directions:
			if axis != short_sections[cell]: continue
			var neighbor := cell+axis
			if stairs.has(neighbor) or int(heights.get(neighbor,-48)) >= height: continue
			var centre := Vector2(cell)+Vector2(axis)*0.5
			var tangent := Vector2(-axis.y,axis.x)*0.5
			var a := project(centre-tangent)-Vector2(0,height)
			var b := project(centre+tangent)-Vector2(0,height)
			# No inset per segment: adjacent sides share one exact corner/post.
			posts[a] = true
			posts[b] = true
			var segment := Node2D.new()
			segment.set_meta("cell",cell)
			segment.set_meta("neighbor",neighbor)
			root.add_child(segment)
			for elevation in [24.0]:
				var rail := Line2D.new()
				rail.points = PackedVector2Array([a-Vector2(0,elevation),a.lerp(b,0.5)-Vector2(0,elevation-2),b-Vector2(0,elevation)])
				rail.width = 3
				rail.default_color = Color("494b3b")
				segment.add_child(rail)
				var highlight := Line2D.new()
				highlight.points = rail.points
				highlight.position.y = -1
				highlight.width = 1
				highlight.default_color = Color("8b8871")
				segment.add_child(highlight)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	void fragment() {
	 vec4 c = texture(TEXTURE,UV);
	 if(c.a < 0.94) discard;
	 COLOR = vec4(c.rgb*vec3(0.75,0.79,0.75),1.0);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for location: Vector2 in posts:
		var post := Sprite2D.new()
		post.texture = POST
		post.centered = false
		post.offset = Vector2(-512,-1340)
		post.scale = Vector2.ONE*(0.027+absf(sin(location.x*0.13+location.y*0.07))*0.004)
		post.position = location
		post.material = material
		root.add_child(post)
static func project(cell: Vector2) -> Vector2:
	return Vector2((cell.x-cell.y)*64,(cell.x+cell.y)*32)
