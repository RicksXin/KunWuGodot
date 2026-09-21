@tool
extends Sprite2D
## Shared live 3D visual for the placement editor and candidate camp runtime.
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var building_visual: Node3D
var banners: Node3D
var model_path := ""

func _ready() -> void:
	visibility_changed.connect(update_render_visibility)

func update_render_visibility() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func configure(item: Dictionary) -> void:
	if viewport == null:
		model_path = item.model_3d
		build_view(str(item.id))
	model.rotation_degrees.y = float(item.get("yaw_degrees", 0.0))
	rotation = 0.0
	material = null
	centered = false
	var anchor: Array = item.get("model_anchor", [0.0, 0.0, 0.0])
	offset = -camera.unproject_position(model.transform * Vector3(anchor[0], anchor[1], anchor[2]))
	scale = Vector2.ONE * float(item.get("display_width", 240.0)) / viewport.size.x
	visible = item.get("preview_visible", true)
	update_render_visibility()

func build_view(building_id: String) -> void:
	var revival := building_id == "revival"
	var recruit := building_id == "recruit"
	var crafting := building_id in ["forge", "garden", "market"]
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,960)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08,0.1,0.13,0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.63,0.67,0.72)
	env.environment.ambient_light_energy = 0.50
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color(0.85,0.90,0.95)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	world.add_child(sun)
	model = Node3D.new()
	world.add_child(model)
	building_visual = load(model_path).instantiate()
	model.add_child(building_visual)
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var material: StandardMaterial3D = node.get_active_material(surface).duplicate()
			preload("res://scripts/prototypes/camp_building_palette.gd").apply(material)
			if material.emission_enabled:
				material.emission_energy_multiplier *= 0.85
				if building_id == "treasury":
					material.emission = Color(0.7, 0.23, 0.025)
					material.emission_energy_multiplier = 0.45
			node.set_surface_override_material(surface,material)
	var motion_path := "res://scripts/prototypes/camp_crafting_motion.gd" if crafting else "res://scripts/prototypes/camp_recruit_lanterns.gd" if recruit else ("res://scripts/prototypes/camp_revival_banners.gd" if revival else "res://scripts/prototypes/camp_treasury_lanterns.gd")
	banners = load(motion_path).new()
	banners.name = "BuildingMotion"
	model.add_child(banners)
	banners.attach(building_visual)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = (10.0 if building_id == "garden" else 8.5) if crafting else (10.0 if recruit else (8.0 if revival else 8.8))
	world.add_child(camera)
	camera.position = Vector3(10,9.565,10) if crafting else (Vector3(8,8.8,12) if revival or recruit else Vector3(10,9.565,10))
	camera.look_at(Vector3(0,2.50,0) if crafting else (Vector3(0,2.45,0) if recruit else (Vector3(0,2.05,0) if revival else Vector3(0,1.4,0))))
	add_grounding(building_id)
	texture = viewport.get_texture()

func add_grounding(building_id: String) -> void:
	# Model-local horizontal decal: follows true yaw and the authored entrance anchor.
	# Irregular transparent soil/moss fringe, plus contact occlusion under the plinth.
	var widths := {"treasury": Vector2(5.7,5.3), "revival": Vector2(5.5,5.5), "recruit": Vector2(7.0,5.8), "forge": Vector2(6.0,5.2), "garden": Vector2(8.0,6.4), "market": Vector2(6.4,5.4)}
	var ground := MeshInstance3D.new()
	ground.name = "GroundContact"
	var plane := PlaneMesh.new()
	plane.size = widths.get(building_id, Vector2(5.5,5.5))
	ground.mesh = plane
	ground.position.y = 0.008
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D soil_tex : source_color, filter_nearest, repeat_enable;
void fragment() {
 vec2 p = (UV-vec2(0.5))*2.0;
 vec3 soil = texture(soil_tex, UV*2.5).rgb;
 float grain = dot(soil,vec3(0.333));
 float dist = length(p);
 float edge = 1.0-smoothstep(0.65+grain*0.22,1.0,dist);
 float contact = (1.0-smoothstep(0.34,0.78,dist))*0.38;
 vec3 earth = mix(vec3(0.15,0.17,0.12),soil*vec3(0.38,0.43,0.34),0.6);
 ALBEDO = mix(earth,vec3(0.035,0.043,0.038),contact);
 ALPHA = edge*(0.17+grain*0.30)+contact;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("soil_tex",preload("res://resources/prototypes/camp_ground_candidate/surface.png"))
	ground.material_override = material
	model.add_child(ground)
