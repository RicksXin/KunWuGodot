extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	var game := root.get_node("Game")
	var wallet_before: Dictionary = game.profile["wallet"].duplicate(true)
	var inventory_before: Dictionary = game.profile["inventory"].duplicate(true)
	camp._open_market(true)
	await process_frame
	var market = camp.modal
	assert(market.purchase_buttons.size() == 7)
	assert(market.purchase_buttons[3].disabled)
	assert(market.purchase_buttons[5].disabled)
	market.purchase_buttons[0].pressed.emit()
	assert(is_instance_valid(market.notice))
	market.notice.queue_free()
	await process_frame
	market.get_node("Tab1").pressed.emit()
	assert(is_instance_valid(market.notice))
	market.notice.queue_free()
	await process_frame
	market.get_node("Tab2").pressed.emit()
	assert(is_instance_valid(market.notice))
	market.notice.queue_free()
	await process_frame
	assert(game.profile["wallet"] == wallet_before)
	assert(game.profile["inventory"] == inventory_before)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Docs/Artifacts/figma-market/preview.png")
	market.get_node("Close").pressed.emit()
	await process_frame
	assert(not is_instance_valid(camp.modal))
	camp._open_market()
	await process_frame
	assert(not camp.modal.preview)
	camp._close_modal()
	print("MARKET_OK: seven rows, sold/locked states, notices, no wallet/inventory writes, close and camp entry")
	quit()
