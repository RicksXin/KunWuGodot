extends Control
## User-supplied candidates: independent visual layers, never navigation geometry.
const ROOT := "res://resources/prototypes/camp_exterior_candidate/"
var layers: Array[TextureRect] = []
var reference_camera := Vector2.ZERO
var reference_zoom := 1.0
var enabled := true

func _ready() -> void:
	position = Vector2(0,145)
	size = Vector2(1280,455)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_layer("sky",Vector2.ZERO,Vector2(1280,640),0.0)
	# A restrained earth-colour distance bed replaces sky below the camp.
	# This is presentation only; it does not add navigable ground.
	var ground_shader := Shader.new()
	ground_shader.code = """shader_type canvas_item;
	uniform sampler2D soil : repeat_enable, filter_nearest;
	uniform bool cloudscape = false;
	void fragment() {
		vec4 sky = texture(TEXTURE, UV);
		vec3 ground = texture(soil, UV * vec2(24.0, 18.0)).rgb * vec3(0.50, 0.57, 0.52);
		float land = smoothstep(0.05, 0.48, UV.y);
		if (cloudscape) {
			vec3 clouds = texture(TEXTURE, vec2(UV.x,0.45+UV.y*0.5)).rgb;
			vec3 mist = mix(clouds*vec3(0.43,0.49,0.57),vec3(0.12,0.17,0.21),0.45);
			sky.rgb *= vec3(0.40,0.46,0.55);
			ground = mix(ground,mist,0.88);
		}
		COLOR = vec4(mix(sky.rgb, ground, land), 1.0);
	}"""
	var ground_material := ShaderMaterial.new()
	ground_material.shader = ground_shader
	ground_material.set_shader_parameter("soil",preload("res://resources/prototypes/camp_ground_candidate/surface.png"))
	layers[0].material = ground_material
	_add_layer("rear",Vector2(160,-65),Vector2(960,540),0.18)
	_add_layer("left",Vector2(35,105),Vector2(390,292.5),0.35)
	_add_layer("right",Vector2(870,130),Vector2(390,260),0.35)
	layers[1].self_modulate = Color(0.78,0.83,0.81)
	# Reuse the supplied mountain silhouette at a quieter, more distant depth.
	_add_layer("rear",Vector2(250,-160),Vector2(780,440),0.08)
	var distant := layers[-1]
	distant.name = "DistantRidge"
	move_child(distant,1)
	var haze := Shader.new()
	haze.code = """shader_type canvas_item;
	void fragment() {
	 vec4 c = texture(TEXTURE,UV);
	 vec3 rock = mix(c.rgb*vec3(0.40,0.49,0.57),vec3(0.105,0.16,0.20),0.64);
	 COLOR = vec4(rock,c.a*0.72);
	}"""
	var haze_material := ShaderMaterial.new()
	haze_material.shader = haze
	distant.material = haze_material


func _add_layer(id: String, point: Vector2, dimensions: Vector2, parallax: float) -> void:
	var layer := TextureRect.new()
	layer.name = id
	layer.texture = load(ROOT+id+".png")
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if id == "sky" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.position = point
	layer.size = dimensions
	layer.set_meta("origin",point)
	layer.set_meta("dimensions",dimensions)
	layer.set_meta("parallax",parallax)
	add_child(layer)
	layers.append(layer)

func sync_camera(camera: Vector2, is_full: bool, zoom: float = -1.0) -> void:
	visible = enabled and is_full
	var delta := camera-reference_camera
	# Bounded offsets retain background coverage at extreme map pans.
	delta = delta.clamp(Vector2(-180,-80),Vector2(180,80))
	for layer in layers:
		layer.position = layer.get_meta("origin")+delta*float(layer.get_meta("parallax"))
		if layer.name in ["left","right"] and zoom > 0:
			# Near rock feet stay attached to the terrain when panning or zooming.
			var ratio := zoom/reference_zoom
			layer.position = camera+(Vector2(layer.get_meta("origin"))+position-reference_camera)*ratio-position
			layer.size = Vector2(layer.get_meta("dimensions"))*ratio

func set_cloudscape(active: bool) -> void:
	if not layers.is_empty():
		layers[0].material.set_shader_parameter("cloudscape",active)
		get_node("DistantRidge").visible = active
		for i in range(1,layers.size()):
			layers[i].self_modulate = Color(0.55,0.64,0.71) if active else (Color(0.78,0.83,0.81) if i == 1 else Color.WHITE)
