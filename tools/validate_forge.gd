extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	var game := root.get_node("Game")
	var wallet: Dictionary = game.profile["wallet"].duplicate(true)
	var inventory: Dictionary = game.profile["inventory"].duplicate(true)
	camp._open_forge(true)
	await process_frame
	var forge = camp.modal
	assert(forge.recipe_buttons.size() == 6)
	assert(forge.recipe_buttons[2].disabled and forge.recipe_buttons[5].disabled)
	forge._select_recipe(1)
	assert(forge.recipe_title.text.contains("剑器制式"))
	forge.recipe_buttons[4].pressed.emit()
	assert(is_instance_valid(forge.notice))
	forge.notice.queue_free()
	await process_frame
	forge.get_node("ForgeFooter0").pressed.emit()
	assert(is_instance_valid(forge.notice))
	forge.notice.queue_free()
	await process_frame
	forge._select_recipe(0)
	assert(game.profile["wallet"] == wallet and game.profile["inventory"] == inventory)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Docs/Artifacts/figma-forge/preview.png")
	forge.get_node("ForgeFooter2").pressed.emit()
	await process_frame
	assert(not is_instance_valid(camp.modal))
	camp._open_forge()
	assert(not camp.modal.preview)
	camp._close_modal()
	print("FORGE_OK: six recipes, selection, disabled states, notices, unchanged inventory/wallet, close and camp entry")
	quit()
