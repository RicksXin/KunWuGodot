extends Node2D
# The approved generated rune stays registered to the stone; only its light varies.
var activation := 0.0:
	set(value):
		activation = value
		if rune_material != null:
			rune_material.set_shader_parameter("activation", value)
var display_width := 68.0
var rune_material: ShaderMaterial

func _ready() -> void:
	var rune := Sprite2D.new()
	var source: Texture2D = load("res://assets/maps/map_01/points/return_rune.png")
	var bitmap := source.get_image()
	if bitmap.is_compressed(): bitmap.decompress()
	bitmap.generate_mipmaps()
	rune.texture = ImageTexture.create_from_image(bitmap)
	rune.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Match the approved 360px stone / 300px rune preview registration.
	rune.scale = Vector2.ONE * display_width * (300.0 / 360.0) / bitmap.get_width()
	rune.position.y = display_width * (-15.0 / 360.0)
	rune.modulate.a = 0.48
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float activation = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV - vec2(0.5);
	float angle = atan(p.y, p.x);
	float phase = TIME * 2.094395102;
	float flow = pow(0.5 + 0.5 * cos(angle - phase), 8.0);
	float echo = pow(0.5 + 0.5 * cos(angle - phase + 3.14159265), 12.0);
	float light = 0.27 + 0.68 * flow + 0.25 * echo + activation * 1.3;
	COLOR = vec4(tex.rgb * light, tex.a) * COLOR;
}
"""
	rune_material = ShaderMaterial.new()
	rune_material.shader = shader
	rune_material.set_shader_parameter("activation", activation)
	rune.material = rune_material
	add_child(rune)
