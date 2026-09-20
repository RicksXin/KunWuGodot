extends Node2D
## Static layered stream. Authored knots support extension independently of navigation.
const WATER = preload("res://resources/prototypes/camp_stream/water.png")
const ROCK = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
var definition: Dictionary = {}
var waterfall_count := 0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name = "ExteriorStream"
	var source := Node2D.new()
	source.name = "SourceRidge"
	source.modulate = Color(0.64,0.73,0.76)
	add_child(source)
	var bed := Node2D.new()
	bed.name = "Riverbed"
	add_child(bed)
	var surface := Node2D.new()
	surface.name = "WaterSurface"
	add_child(surface)
	var foam := Node2D.new()
	foam.name = "WaterfallFoam"
	add_child(foam)
	var banks := Node2D.new()
	banks.name = "BankRocks"
	banks.modulate = Color(0.64,0.73,0.76)
	add_child(banks)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	varying vec4 tint;
	void vertex() { tint = COLOR; }
	void fragment() { COLOR = texture(TEXTURE,1.0-abs(mod(UV,2.0)-1.0))*tint; }
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var knots: Array = definition.get("knots",[])
	var normals: Array[Vector2] = []
	for i in range(knots.size()):
		var previous := project(knots[maxi(0,i-1)])
		var following := project(knots[mini(knots.size()-1,i+1)])
		normals.append((following-previous).normalized().orthogonal())
	if not knots.is_empty():
		for placement in [Vector3(65,15,0.21),Vector3(180,25,0.15)]:
			var ridge := Sprite2D.new()
			ridge.texture = preload("res://resources/prototypes/camp_rock_slope/slope.png")
			ridge.centered = false
			ridge.offset = Vector2(-768,-920)
			ridge.scale = Vector2.ONE*placement.z
			ridge.position = project(knots[0])+Vector2(placement.x,placement.y)
			source.add_child(ridge)
	var phase := 0.0
	for i in range(knots.size()-1):
		var k: Array = knots[i]
		var next: Array = knots[i+1]
		var a := project(k)
		var b := project(next)
		var falling: bool = k[0]==next[0] and k[1]==next[1] and k[2]>next[2]
		var normal: Vector2 = normals[i]
		var next_normal: Vector2 = normals[i+1]
		var width_a: float = k[3]*0.5
		var width_b: float = next[3]*0.5
		var length := a.distance_to(b)
		strip(bed,a,b,normal,next_normal,width_a+76,width_b+76,ROCK,material,phase,length,Color(0.43,0.52,0.54))
		strip(surface,a,b,normal,next_normal,width_a,width_b,WATER,material,phase,length,Color(0.85,1.0,1.08) if falling else Color(0.68,0.83,0.88))
		if falling:
			waterfall_count += 1
			for j in range(9):
				var line := Line2D.new()
				var x := (float(j)/8.0-0.5)*width_b*1.6
				line.points = PackedVector2Array([a+Vector2(x,3+fmod(j*7,17)),a.lerp(b,0.6)+Vector2(x+sin(j)*5,0),b+Vector2(x*1.2,3-fmod(j*3,9))])
				line.width = 1.5+fmod(j,3)
				line.default_color = Color(0.71,0.85,0.84,0.36)
				foam.add_child(line)
			var splash := Line2D.new()
			splash.points = PackedVector2Array([b-Vector2(width_b,0),b+Vector2(0,5),b+Vector2(width_b,0)])
			splash.width = 5
			splash.default_color = Color(0.71,0.85,0.84,0.65)
			foam.add_child(splash)
		phase += length
		for side in [-1,1]:
			var rock := Sprite2D.new()
			rock.texture = preload("res://resources/prototypes/camp_rock_slope/slope.png")
			rock.region_enabled = true
			rock.region_rect = Rect2(750,600,750,400)
			rock.centered = false
			rock.offset = Vector2(-375,-360)
			rock.scale = Vector2.ONE*(0.09+0.015*(i%3))
			rock.position = a.lerp(b,0.15 if falling else 0.48)+normal*side*(width_a+32)
			banks.add_child(rock)
func strip(parent: Node2D,a: Vector2,b: Vector2,n: Vector2,end_normal: Vector2,wa: float,wb: float,texture: Texture2D,material: Material,phase: float,length: float,tint: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.texture = texture
	polygon.material = material
	polygon.color = tint
	var points := PackedVector2Array()
	var coordinates := PackedVector2Array()
	for side in [-1,1]:
		for step in range(9):
			var t: float = float(step if side == -1 else 8-step)/8.0
			var along := phase+length*t
			var uneven := sin(along*0.12+side)*3.0+sin(along*0.051)*4.0
			var width := lerpf(wa,wb,t)+uneven
			points.append(a.lerp(b,t)+n.lerp(end_normal,t)*side*width)
			coordinates.append(Vector2(0 if side == -1 else width*8,along*4))
	polygon.polygon = points
	polygon.uv = coordinates
	parent.add_child(polygon)
func project(k: Array) -> Vector2:
	return Vector2((k[0]-k[1])*64,(k[0]+k[1])*32-k[2])
