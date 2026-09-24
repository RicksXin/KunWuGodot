@tool
extends Sprite2D
## All props share one atlas. Decoration cells are visual anchors, not building doors.
const MANIFEST := "res://resources/prototypes/camp_decor/atlas.json"
const LIGHT := preload("res://scripts/prototypes/camp_decor_light.gdshader")
static var catalog: Dictionary = {}
static var shared_texture: Texture2D

func configure(item: Dictionary) -> void:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var prop: Dictionary = catalog.props[item.prop]
	if shared_texture == null:
		if ResourceLoader.exists(catalog.texture):
			shared_texture = load(catalog.texture)
		else:
			# The tool panel can refresh before a new PNG finishes its first import.
			shared_texture = ImageTexture.create_from_image(Image.load_from_file(catalog.texture))
	var atlas := AtlasTexture.new()
	atlas.atlas = shared_texture
	var r: Array = prop.region
	atlas.region = Rect2(r[0],r[1],r[2],r[3])
	atlas.filter_clip = true
	texture = atlas
	centered = false
	offset = -Vector2(prop.anchor[0],prop.anchor[1])
	scale = Vector2.ONE * float(item.get("display_width",64.0))/float(r[2])
	if item.get("mirror_x",false): scale.x *= -1.0
	rotation_degrees = float(item.get("rotation_degrees",0.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = item.get("preview_visible",true)
	if item.prop in ["lantern", "formation_lamp", "soul_shrine"]:
		var light := ShaderMaterial.new()
		light.shader = LIGHT
		light.set_shader_parameter("phase",float(str(item.id).hash()%1000)/100.0)
		light.set_shader_parameter("spirit_light",item.prop != "lantern")
		material = light
	else:
		material = null

func place(item: Dictionary, ground_point: Vector2) -> void:
	var shift: Array = item.get("visual_offset",[0,0])
	position = ground_point + Vector2(shift[0],shift[1])
	name = item.id
