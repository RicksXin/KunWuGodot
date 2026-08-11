extends Control

var status_label: Label

func _ready() -> void:
	set_process_input(true)
	var background := ColorRect.new()
	background.color = KWUI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color("#0d2730")
	glow.position = Vector2(38, 180)
	glow.size = Vector2(299, 300)
	add_child(glow)
	KWUI.label(self, "昆吾禁地", Rect2(35, 250, 305, 66), 30, KWUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(self, "山外修士营地", Rect2(35, 310, 305, 34), 15, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status_label = KWUI.label(self, "正在唤醒记忆……", Rect2(35, 560, 305, 34), 13, KWUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var progress := ProgressBar.new()
	progress.position = Vector2(62, 610)
	progress.size = Vector2(251, 8)
	progress.value = 100
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", KWUI.style_box(Color("#132229"), Color("#314b48"), 4, 1))
	progress.add_theme_stylebox_override("fill", KWUI.style_box(KWUI.TEAL, KWUI.TEAL, 4, 0))
	add_child(progress)
	await get_tree().create_timer(0.55).timeout
	status_label.text = "正在搭建营地……"
	await get_tree().create_timer(0.55).timeout
	status_label.text = "已就绪"
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file("res://scenes/camp.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		Game.reset_profile()
		status_label.text = "已重置为新档"
