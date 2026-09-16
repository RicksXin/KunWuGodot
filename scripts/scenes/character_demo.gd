extends Node2D
# Settings-only character preview; does not mutate Game.profile or expedition state.
var camp: Control
var previous_size := Vector2i.ZERO
var previous_content := Vector2i.ZERO
var rng := RandomNumberGenerator.new()
var nav = preload("res://scripts/maps/map_navigation.gd").new()
var camera: Camera2D
var people: Array = []
var pool: Array[Vector2] = []
var covered: Array[Vector2] = []
var overlay: Node2D
var player: Dictionary
var interact_button: Button
var dialogue: Control
var nearby: Dictionary = {}
const INTERACTION_DISTANCE := 32.0
var touch_directions: Dictionary = {}
const CHARACTER_FILES := ["001-1787889793963-frames64-oldfix2.png", "107-1787907675175-frames64-oldfix2.png", "109-1787907852864-frames64-oldfix2.png", "1787896671002-frames64-oldfix2.png", "1787901929352-frames64-oldfix2.png", "1787902379826-frames64-oldfix2.png", "1787903639277-frames64-oldfix2.png", "1787905054773-frames64-oldfix2.png", "1787905239433-frames64-oldfix2.png", "1787918031573-frames64-oldfix2.png", "1787918031573-frames64.png", "1787918394098-frames64.png", "1787918483969-frames64.png", "1787918755283-frames64-oldfix2.png", "1787918845829-frames64-oldfix2.png", "1787918936199-frames64-oldfix2.png", "1787919480487-frames64.png", "1787919847862-frames64.png", "1787925153880-frames64.png", "1787925244917-frames64.png"]

func _ready() -> void:
	previous_content = get_window().content_scale_size
	previous_size = get_window().size
	get_window().content_scale_size = Vector2i(817,375)
	if DisplayServer.get_name() != "headless": get_window().size = Vector2i(1224,562)
	rng.randomize()
	var definition: Dictionary = Game.get_map_definition()
	nav.setup(definition)
	var layout := preload("res://scenes/maps/map_01.tscn").instantiate()
	add_child(layout)
	var background: Sprite2D = layout.get_node("HDBackground")
	background.scale = nav.world_size / background.texture.get_size()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.z_index = -10
	overlay = Node2D.new()
	overlay.set_script(load("res://scripts/maps/map_annotations_overlay.gd"))
	overlay.setup(background)
	overlay.z_index = 4
	overlay.visible = false
	add_child(overlay)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	for y in range(6,int(nav.world_size.y)-6,6):
		for x in range(6,int(nav.world_size.x)-6,6):
			var p := Vector2(x,y)
			if nav.can_walk(p):
				pool.append(p)
				if nav.is_in_adjust_region(p): covered.append(p)
	assert(not pool.is_empty())
	camera.position = Vector2(450,295)
	camera.zoom = Vector2.ONE*1.2
	camera.force_update_scroll()
	var source := "res://assets/debug/wuxia_characters/"
	for file in CHARACTER_FILES:
		if not file.ends_with(".png"): continue
		var host := Node2D.new()
		host.position = pool[rng.randi_range(0,pool.size()-1)]
		# Distribute NPC spawns across the full map, then wander to unrestricted goals.
		if not people.is_empty():
			var band_start := int(float(people.size()-1)/19.0*pool.size())
			var band_end := mini(pool.size()-1,int(float(people.size())/19.0*pool.size()))
			host.position = pool[rng.randi_range(band_start,band_end)]
		host.z_index=6
		var sprite := Sprite2D.new()
		sprite.texture=load(source+file)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.hframes=6
		sprite.vframes=13
		sprite.scale=Vector2.ONE*0.65
		# Cell bottom is the foot anchor; movement and adjust queries use the host.
		sprite.position.y=-18
		host.add_child(sprite)
		add_child(host)
		people.append({"host":host,"sprite":sprite,"route":PackedVector2Array(),"wait":rng.randf_range(0,0.5),"speed":rng.randf_range(24,39),"phase":rng.randf_range(0,6),"row":7})

	player = people[0]
	player.host.position = Vector2(450,1890)
	if not nav.can_walk(player.host.position): player.host.position = pool[-1]
	player.speed = 95.0
	# Ensure every spawn respects the same foot-circle separation as movement.
	for i in range(1,people.size()):
		var person: Dictionary = people[i]
		if not _person_position_clear(person,person.host.position):
			for candidate in pool:
				if _person_position_clear(person,candidate):
					person.host.position = candidate
					break
	var player_label := Label.new()
	player_label.text = "你"
	player_label.position = Vector2(-6,-43)
	player_label.add_theme_font_size_override("font_size",11)
	player_label.add_theme_color_override("font_outline_color",Color.BLACK)
	player_label.add_theme_constant_override("outline_size",3)
	player.host.add_child(player_label)
	_follow_player()
	var ui := CanvasLayer.new()
	ui.layer = 100
	add_child(ui)
	var bar := ColorRect.new()
	bar.color = Color("#172322ed")
	bar.size = Vector2(817,48)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	var title := Label.new()
	title.text = "人物 Demo · 你 + 19 位漫游角色"
	title.position = Vector2(16,12)
	ui.add_child(title)
	var regions := Button.new()
	regions.text = "碰撞 / 调节层"
	regions.position = Vector2(490,7)
	regions.size = Vector2(145,34)
	regions.pressed.connect(func(): overlay.visible = not overlay.visible)
	ui.add_child(regions)
	var back := Button.new()
	back.name = "ReturnToSettings"
	back.text = "返回设置"
	back.position = Vector2(650,7)
	back.size = Vector2(150,34)
	back.pressed.connect(close)
	ui.add_child(back)

	interact_button = Button.new()
	interact_button.name = "TalkToCharacter"
	interact_button.position = Vector2(305,326)
	interact_button.size = Vector2(270,40)
	interact_button.visible = false
	interact_button.pressed.connect(_talk)
	ui.add_child(interact_button)
	var help := Label.new()
	help.text = "WASD 移动 · 靠近按 E 交谈"
	help.position = Vector2(16,337)
	help.add_theme_font_size_override("font_size",12)
	help.add_theme_color_override("font_outline_color",Color.BLACK)
	help.add_theme_constant_override("outline_size",3)
	ui.add_child(help)
	for item in [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]:
		var button := Button.new()
		button.text = item[0]
		button.position = Vector2(595+touch_button_index(ui)*48,326)
		button.size = Vector2(44,40)
		button.set_meta("movement_button",true)
		var key: String = item[0]
		var direction: Vector2 = item[1]
		button.button_down.connect(func(): touch_directions[key] = direction)
		button.button_up.connect(func(): touch_directions.erase(key))
		ui.add_child(button)

func touch_button_index(ui: CanvasLayer) -> int:
	var count := 0
	for child in ui.get_children():
		if child.has_meta("movement_button"): count += 1
	return count

func _follow_player() -> void:
	var half := Vector2(817,375) / camera.zoom / 2.0
	camera.position = Vector2(clampf(player.host.position.x,half.x,nav.world_size.x-half.x),clampf(player.host.position.y,half.y,nav.world_size.y-half.y))
	camera.force_update_scroll()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: touch_directions.clear()

func _physics_process(delta: float) -> void:
	if is_instance_valid(dialogue): return
	var dt := minf(delta,0.1)
	var can_plan := true
	for person in people:
		var host: Node2D = person.host
		var sprite: Sprite2D = person.sprite
		var before := host.position
		if person == player:
			var input := Input.get_vector("move_left","move_right","move_up","move_down")
			for value in touch_directions.values(): input += value
			host.position = _move_person(person,input.limit_length()*person.speed*dt)
		else:
			var route: PackedVector2Array = person.route
			person.wait = maxf(0,person.wait-dt)
			if route.is_empty() and person.wait<=0 and can_plan:
				can_plan = false
				var destination: Vector2 = pool[rng.randi_range(0,pool.size()-1)]
				route = nav.path(host.position,destination)
				person.wait = rng.randf_range(0.5,1.5)
			if not route.is_empty():
				host.position=_move_person(person,(route[0]-before).limit_length(person.speed*dt))
				if host.position.distance_to(route[0])<1.0: route.remove_at(0)
				if host.position.distance_to(before)<0.001: route.clear()
				if route.is_empty(): person.wait=rng.randf_range(0.25,1.1)
			person.route=route
		assert(nav.can_walk(host.position),"Character crossed authored collision")
		var direction := host.position-before
		if direction.length()>0.01:
			person.phase+=dt*8
			sprite.flip_h=false
			if absf(direction.x)>absf(direction.y):
				person.row=8
				sprite.flip_h=direction.x>0
			else: person.row=9 if direction.y<0 else 7
		if direction.length()>0.01:
			sprite.frame = person.row*6 + int(person.phase)%6
		else:
			# Rows 10/11/12 (zero-based) begin with relaxed, feet-together
			# down/left/up poses. Keep horizontal mirroring and facing on stop.
			sprite.frame = (person.row+3)*6
		var occluded: bool = nav.is_in_adjust_region(host.position)
		host.modulate.a=move_toward(host.modulate.a,0.42 if occluded else 1.0,dt*4.0)

	_follow_player()
	_refresh_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(dialogue): _close_dialogue()
		else: close()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_talk()

func close() -> void:
	if is_instance_valid(camp):
		camp.show()
		camp.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()

func _exit_tree() -> void:
	get_window().content_scale_size = previous_content
	if DisplayServer.get_name() != "headless": get_window().size = previous_size

func _person_position_clear(person: Dictionary, at: Vector2) -> bool:
	if not nav.can_walk(at): return false
	var diameter: float = nav.actor_radius * 2.0
	for other in people:
		if other == person: continue
		if at.distance_squared_to(other.host.position) < diameter * diameter - 0.001: return false
	return true

func _move_person(person: Dictionary, displacement: Vector2) -> Vector2:
	var at: Vector2 = person.host.position
	var steps := maxi(1,ceili(displacement.length()/2.0))
	var step := displacement / steps
	for i in steps:
		var next: Vector2 = nav.move(at,step)
		if _person_position_clear(person,next): at = next
		elif _person_position_clear(person,at+Vector2(step.x,0)): at += Vector2(step.x,0)
		elif _person_position_clear(person,at+Vector2(0,step.y)): at += Vector2(0,step.y)
	return at

func _refresh_interaction() -> void:
	nearby = {}
	var nearest := INTERACTION_DISTANCE
	for i in range(1,people.size()):
		var person: Dictionary = people[i]
		var distance: float = player.host.position.distance_to(person.host.position)
		if distance < nearest and nav.segment_clear(player.host.position,person.host.position):
			nearby = person
			nearest = distance
	interact_button.visible = not nearby.is_empty()
	if not nearby.is_empty(): interact_button.text = "与修士 %02d 交谈 [E]" % (people.find(nearby)+1)

func _talk() -> void:
	if is_instance_valid(dialogue): return
	_refresh_interaction()
	if nearby.is_empty(): return
	touch_directions.clear()
	for person in people: person.sprite.frame = (person.row+3)*6
	dialogue = Control.new()
	dialogue.name = "CharacterDialogue"
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interact_button.get_parent().add_child(dialogue)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(218,92)
	panel.size = Vector2(381,205)
	dialogue.add_child(panel)
	var text := Label.new()
	text.text = "修士 %02d\n\n道友，前方山路险峻，行走多加小心。\n我正在这片山中游历，我们有缘再会。" % (people.find(nearby)+1)
	text.position = Vector2(22,20)
	text.add_theme_font_size_override("font_size",15)
	panel.add_child(text)
	var leave := Button.new()
	leave.name = "EndConversation"
	leave.text = "告辞"
	leave.position = Vector2(125,150)
	leave.size = Vector2(130,36)
	leave.pressed.connect(_close_dialogue)
	panel.add_child(leave)

func _close_dialogue() -> void:
	if is_instance_valid(dialogue):
		dialogue.queue_free()
		dialogue = null
	touch_directions.clear()
