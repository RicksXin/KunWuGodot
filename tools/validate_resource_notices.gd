extends Node

func _ready() -> void:
	if not Game.suppress_profile_writes:
		_fail("Validation requires --no-profile-write")
		return
	Game.profile = Game.default_profile.duplicate(true)
	Game.profile.camp.lastSettledAtUtc = Game.now()
	var camp := preload("res://scenes/camp.tscn").instantiate()
	add_child(camp)
	var notice := camp.find_child("ResourceChangeNotice", true, false) as Control
	var label := camp.find_child("ResourceChangeText", true, false) as Label
	if notice == null or notice.visible:
		_fail("Initial wallet must not create a change notice")
		return
	camp.call("_open_ling_pu")
	Game.profile.wallet.spiritGrain -= 30
	Game.profile.wallet.spiritWood += 12
	Game.state_changed.emit()
	if not notice.visible or not label.text.contains("灵粮 -30") or not label.text.contains("灵木 +12"):
		_fail("Mixed resource changes must be shown together above the open modal")
		return
	if notice.z_index <= 0 or notice.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Notice must overlay the modal without blocking input")
		return
	if notice is Panel or label.get_theme_color("font_color").r > 0.2:
		_fail("Resource notice must be dark text without a panel")
		return
	if label.text.split("\n").size() != 2 or label.get_theme_color("font_color").a < 0.95:
		_fail("Each resource must occupy its own line with opaque text")
		return
	var start_y := notice.position.y
	await get_tree().create_timer(0.4).timeout
	if notice.position.y >= start_y - 5.0:
		_fail("Resource text must float upward immediately")
		return
	camp.call("_show_feedback", "操作完成")
	if not notice.visible or not label.text.contains("-30"):
		_fail("Action feedback must not overwrite resource changes")
		return
	camp.call("_refresh_hud")
	if not camp.resource_notice_queue.is_empty():
		_fail("Unchanged balance must not repeat a notice")
		return
	Game.profile.wallet.darkIron += 3
	camp.call("_refresh_hud")
	if camp.resource_notice_queue.size() != 1:
		_fail("Subsequent changes must queue rather than overwrite")
		return
	await get_tree().create_timer(1.55).timeout
	if not label.text.contains("玄铁 +3"):
		_fail("Queued change was not displayed")
		return
	await get_tree().create_timer(1.9).timeout
	if notice.visible:
		_fail("Resource text must fade out after floating")
		return
	var notice_ref: WeakRef = weakref(notice)
	camp.queue_free()
	await get_tree().process_frame
	Game.profile.wallet.spiritGrain += 1
	Game.state_changed.emit()
	if notice_ref.get_ref() != null:
		_fail("Notice survived leaving camp")
		return
	print("CAMP_RESOURCE_NOTICES_OK: dark floating text, upward motion + fade, combined deltas, queue, camp lifetime only")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
