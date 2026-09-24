@tool
extends Node2D
## Animated layered stream. Authored knots support extension independently of navigation.
const WATER = preload("res://resources/prototypes/camp_stream/water.png")
const ROCK = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
var definition: Dictionary = {}
var waterfall_count := 0
var flow_material: ShaderMaterial
var waterfall_material: ShaderMaterial
var animation_time := 0.0
var falling_lines: Array[Dictionary] = []
var splashes: Array[Dictionary] = []

func _process(delta: float) -> void:
	animate_water(animation_time + delta)

func animate_water(seconds: float) -> void:
	animation_time = seconds
	if flow_material != null:
		flow_material.set_shader_parameter("flow_time", seconds)
	if waterfall_material != null:
		waterfall_material.set_shader_parameter("flow_time",seconds)
	for fall in falling_lines:
		var t := fposmod(seconds * 0.85 + fall.phase, 1.0)
		var a: Vector2 = fall.a
		var b: Vector2 = fall.b
		var x: float = fall.x
		var start := a.lerp(b,t) + Vector2(x,0)
		var end := a.lerp(b,minf(t+float(fall.get("length",0.32)),1.0)) + Vector2(x+sin(t*PI)*2.0,0)
		fall.line.points = PackedVector2Array([start,start.lerp(end,0.5),end])
		fall.line.modulate.a = sin(t*PI)
	for splash in splashes:
		var pulse := sin(seconds*3.4+splash.phase)
		splash.line.width = 3.5 + pulse*0.8
		splash.line.modulate.a = 0.65 + pulse*0.2

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
	flow_material = ShaderMaterial.new()
	flow_material.shader = preload("res://scripts/prototypes/camp_stream_flow.gdshader")
	var knots: Array = definition.get("knots",[])
	var normals: Array[Vector2] = []
	for i in range(knots.size()):
		var previous := project(knots[maxi(0,i-1)])
		var following := project(knots[mini(knots.size()-1,i+1)])
		normals.append((following-previous).normalized().orthogonal())
	var ridges: Array = definition.get("source_ridges",[])
	if ridges.is_empty() and not knots.is_empty():
		for placement in [Vector3(65,15,0.21),Vector3(180,25,0.15)]:
			add_ridge(source,project(knots[0])+Vector2(placement.x,placement.y),placement.z)
	else:
		for ridge in ridges:
			add_ridge(source,project([ridge.cell[0],ridge.cell[1],ridge.height]),float(ridge.scale))
	# Natural rear waterfall runs behind the building into the existing stream.
	waterfall_material = flow_material.duplicate()
	waterfall_material.set_shader_parameter("vertical_texture_scale",0.16)
	var rear: Dictionary = definition.get("rear_waterfall",{})
	var rear_points: Array = rear.get("points",[])
	var rear_widths: Array = rear.get("widths",[])
	var rear_phase := 0.0
	for i in range(rear_points.size()-1):
		var a := Vector2(rear_points[i][0],rear_points[i][1])
		var b := Vector2(rear_points[i+1][0],rear_points[i+1][1])
		var normal := (b-a).normalized().orthogonal()
		var width_a := float(rear_widths[i])*0.5
		var width_b := float(rear_widths[i+1])*0.5
		strip(bed,a,b,normal,normal,width_a+5,width_b+5,ROCK,material,rear_phase,a.distance_to(b),Color(0.48,0.57,0.56),0.25)
		strip(surface,a,b,normal,normal,width_a,width_b,WATER,waterfall_material,rear_phase,a.distance_to(b),Color(1.1,1.25,1.25),0.25)
		rear_phase += a.distance_to(b)
	if rear_points.size() >= 2:
		var top := Vector2(rear_points[0][0],rear_points[0][1])
		var bottom := Vector2(rear_points[-1][0],rear_points[-1][1])
		for j in range(9):
			var line := Line2D.new()
			line.width = 1.0+float(j%3)*0.6
			line.default_color = Color(0.73,0.87,0.87,0.48)
			foam.add_child(line)
			falling_lines.append({"line":line,"a":top,"b":bottom,"x":float(j-4)*1.5,"phase":float(j)/9.0,"length":0.14})
		var splash := Line2D.new()
		var arc := PackedVector2Array()
		for j in range(13):
			var angle := float(j)/12.0*PI
			arc.append(bottom+Vector2(cos(angle)*23.0,sin(angle)*6.0))
		splash.points = arc
		splash.default_color = Color(0.68,0.83,0.83,0.45)
		foam.add_child(splash)
		splashes.append({"line":splash,"phase":1.7})
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
		strip(surface,a,b,normal,next_normal,width_a,width_b,WATER,flow_material,phase,length,Color(0.85,1.0,1.08) if falling else Color(0.68,0.83,0.88))
		if falling:
			waterfall_count += 1
			for j in range(9):
				var line := Line2D.new()
				var x := (float(j)/8.0-0.5)*width_b*1.6
				line.points = PackedVector2Array([a+Vector2(x,3+fmod(j*7,17)),a.lerp(b,0.6)+Vector2(x+sin(j)*5,0),b+Vector2(x*1.2,3-fmod(j*3,9))])
				line.width = 1.5+fmod(j,3)
				line.default_color = Color(0.71,0.85,0.84,0.36)
				foam.add_child(line)
				falling_lines.append({"line":line,"a":a,"b":b,"x":x,"phase":float(j)/9.0+float(i)*0.17})
			var splash := Line2D.new()
			splash.points = PackedVector2Array([b-Vector2(width_b,0),b+Vector2(0,5),b+Vector2(width_b,0)])
			splash.width = 5
			splash.default_color = Color(0.71,0.85,0.84,0.65)
			foam.add_child(splash)
			splashes.append({"line":splash,"phase":float(i)})
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
func strip(parent: Node2D,a: Vector2,b: Vector2,n: Vector2,end_normal: Vector2,wa: float,wb: float,texture: Texture2D,material: Material,phase: float,length: float,tint: Color,roughness: float = 1.0) -> void:
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
			var width := lerpf(wa,wb,t)+uneven*roughness
			points.append(a.lerp(b,t)+n.lerp(end_normal,t)*side*width)
			coordinates.append(Vector2(0 if side == -1 else width*8,along*4))
	polygon.polygon = points
	polygon.uv = coordinates
	parent.add_child(polygon)
func project(k: Array) -> Vector2:
	return Vector2((k[0]-k[1])*64,(k[0]+k[1])*32-k[2])

func add_ridge(parent: Node2D, at: Vector2, size_scale: float) -> void:
	var ridge := Sprite2D.new()
	ridge.texture = preload("res://resources/prototypes/camp_rock_slope/slope.png")
	ridge.centered = false
	ridge.offset = Vector2(-768,-920)
	ridge.scale = Vector2.ONE*size_scale
	ridge.position = at
	parent.add_child(ridge)
