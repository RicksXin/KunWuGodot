extends Sprite2D
var activating := false
var effects: Node2D
func setup(config: Dictionary) -> void:
	texture = load(config.texture)
	var bitmap := texture.get_image()
	if bitmap.is_compressed(): bitmap.decompress()
	bitmap.generate_mipmaps()
	texture = ImageTexture.create_from_image(bitmap)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	position = Vector2(config.position[0],config.position[1])
	scale = Vector2.ONE * float(config.width) / texture.get_width()
	z_index = 0
	effects = Node2D.new()
	effects.set_script(load("res://scripts/maps/return_platform_fx.gd"))
	effects.scale = Vector2.ONE / scale
	effects.set("display_width",float(config.width))
	effects.z_index = 3
	add_child(effects)
	var label := Label.new()
	label.text = "归营阵"
	label.position = Vector2(-24,23) / scale
	label.scale = Vector2.ONE / scale
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color("#c4d4cb"))
	label.add_theme_color_override("font_outline_color",Color("#172322"))
	label.add_theme_constant_override("outline_size",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
func activate() -> void:
	if activating: return
	activating = true
	var tween := create_tween()
	tween.tween_method(_set_activation,0.0,1.0,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.15)
	tween.tween_method(_set_activation,1.0,0.35,0.25)
	await tween.finished

func _set_activation(value: float) -> void:
	effects.set("activation",value)
