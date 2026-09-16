extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	camp._open_treasury(true)
	await process_frame
	var panel = camp.modal
	assert(panel.get_node_or_null(".") != null)
	panel.category = "装备"
	panel._refresh()
	panel._filter()
	panel.category = "全部"
	panel.quality = -1
	panel._refresh()
	panel.message.text = ""
	if not DisplayServer.get_name() == "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Docs/Artifacts/figma-inventory/preview.png")
	camp._close_modal()
	camp._open_treasury()
	await process_frame
	assert(not camp.modal.preview)
	camp._close_modal()
	print("TREASURY_OK: design preview, categories, quality filter, live inventory, close")
	quit()
