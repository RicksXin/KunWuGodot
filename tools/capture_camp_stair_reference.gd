extends SceneTree
## Render existing procedural stair geometry as an art reference; never writes profile.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var fullcamp_y := OS.get_cmdline_user_args().has("--fullcamp-y")
	var canvas := Vector2i(144,144) if fullcamp_y else Vector2i(128,128)
	var viewport := SubViewport.new()
	viewport.size = canvas
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	if fullcamp_y:
		preload("res://scripts/prototypes/camp_stonework.gd").stairs(stage,Vector2(72,8),Vector2(136,40),Vector2(72,120),Vector2(8,88))
	else:
		preload("res://scripts/prototypes/camp_stonework.gd").stairs(stage,Vector2(16,36),Vector2(56,16),Vector2(112,92),Vector2(72,112))
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	assert(result.get_size() == canvas)
	var output := "res://art/candidates/camp-stairs/fullcamp-y-v1/structure-reference.png" if fullcamp_y else "res://art/candidates/camp-stairs/v1/structure-reference.png"
	var error := result.save_png(output)
	assert(error == OK)
	print("PASS: captured existing eight-step geometry, ",canvas," transparent reference")
	quit()
