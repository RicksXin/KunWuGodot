extends RefCounted
## Boundary-driven rock faces; texture phase is continuous across adjacent cells.
const ROCK = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
static func build(parent: Node2D, edges: Array[Dictionary], rims: Node2D) -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	varying vec4 vertex_tint;
	void vertex() { vertex_tint = COLOR; }
	void fragment() {
	 vec2 reflected = 1.0-abs(mod(UV,2.0)-1.0);
	 COLOR = texture(TEXTURE,reflected)*vertex_tint;
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for edge in edges:
		var a: Vector2 = edge.a if edge.a.x < edge.b.x else edge.b
		var b: Vector2 = edge.b if edge.a.x < edge.b.x else edge.a
		var depth: float = edge.height
		var face := Polygon2D.new()
		face.texture = ROCK
		face.material = material
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var middle := a.lerp(b,0.5)
		var irregularity := 3.0+absf(sin(middle.x*0.07+middle.y*0.13))*5.0
		face.polygon = PackedVector2Array([a,b,b+Vector2(0,depth),middle+Vector2(0,depth+irregularity),a+Vector2(0,depth)])
		# Same world-space vertical sampling on each direction, without per-tile reset.
		var slope := (b.y-a.y)/(b.x-a.x)
		var uv := PackedVector2Array()
		for p in face.polygon:
			uv.append(Vector2(p.x*4.0,(p.y-p.x*slope)*4.0))
		face.uv = uv
		face.color = Color(0.62,0.70,0.74) if slope>0 else Color(0.47,0.57,0.63)
		parent.add_child(face)
		# A narrow moss lip replaces the wide brown soil/profile band.
		var lip := Polygon2D.new()
		lip.texture = ROCK
		lip.material = material
		lip.polygon = PackedVector2Array([a-Vector2(0,3),a.lerp(b,0.28)-Vector2(0,irregularity+4),a.lerp(b,0.67)-Vector2(0,irregularity),b-Vector2(0,3),b+Vector2(0,5),middle+Vector2(0,irregularity+3),a+Vector2(0,5)])
		var lip_uv := PackedVector2Array()
		for p in lip.polygon:
			lip_uv.append(Vector2(p.x*4.0,300.0+(p.y-(a.y+(p.x-a.x)*slope))*4.0))
		lip.uv = lip_uv
		lip.color = Color(0.48,0.57,0.43)
		rims.add_child(lip)
