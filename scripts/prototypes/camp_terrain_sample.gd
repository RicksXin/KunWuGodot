extends Control
## Landscape candidate lab. All edits are transient and profile writes are suppressed.
const VIEW := Vector2i(1280, 720)
const Terrain = preload("res://scripts/prototypes/camp_dual_terrain.gd")
var terrain: Terrain
var world: Node2D
var exterior: Control
var mountain_mist: TextureRect
var structure: Node2D
var marker: Polygon2D
var status: Label
var mode := 0
var current_pattern := 0
var dragging := false
var show_structure := true
var terrace: Node2D
var layout_selector: OptionButton
var building_toggle: CheckButton
var connected_sample: Node2D
var connected_controls: HBoxContainer
var corner_sample: Node2D
var corner_controls: HBoxContainer
var stair_style_toggle: CheckButton
var edit_buttons: Array[Button] = []
var environment_toggle: CheckButton
var image_rebuild: Node2D
var tile_rebuild: Node2D
var rebuild: Node2D
var rebuild_controls: HBoxContainer
var full_camp: Node2D
var full_controls: HBoxContainer
var full_style_selector: OptionButton
var walk_controls: HBoxContainer
var scene_hint: Label
var heading: Label
var subheading: Label
var mouse_down := Vector2.ZERO
var mouse_moved := false
var camp: Control
var previous_profile_write_suppression := true
var previous_content := Vector2i.ZERO
var previous_size := Vector2i.ZERO
var previous_position := Vector2i.ZERO
var previous_orientation := DisplayServer.SCREEN_PORTRAIT

func _enter_tree() -> void:
	previous_content = get_window().content_scale_size
	get_window().content_scale_size = VIEW
	if OS.has_feature("mobile"):
		previous_orientation = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	elif DisplayServer.get_name() != "headless":
		previous_size = DisplayServer.window_get_size()
		previous_position = DisplayServer.window_get_position()
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect()
			var factor := minf(1.0, minf((usable.size.x - 40.0) / VIEW.x, (usable.size.y - 40.0) / VIEW.y))
			var target := Vector2i(Vector2(VIEW) * factor)
			DisplayServer.window_set_size(target)
			DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)

func _exit_tree() -> void:
	get_window().content_scale_size = previous_content
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(previous_orientation)
	elif DisplayServer.get_name() != "headless" and previous_size != Vector2i.ZERO:
		DisplayServer.window_set_size(previous_size)
		DisplayServer.window_set_position(previous_position)
	Game.suppress_profile_writes = previous_profile_write_suppression
	if is_instance_valid(camp):
		camp.process_mode = Node.PROCESS_MODE_INHERIT
		camp.show()

func _return_to_camp() -> void:
	if is_instance_valid(camp):
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/camp.tscn")

func _ready() -> void:
	previous_profile_write_suppression = Game.suppress_profile_writes
	Game.suppress_profile_writes = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme_local := Theme.new()
	theme_local.default_font = preload("res://assets/fonts/NotoSansSC.ttf")
	theme_local.default_font_size = 18
	theme = theme_local
	var background := ColorRect.new()
	background.color = Color("161e22")
	background.size = Vector2(VIEW)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	exterior = preload("res://scripts/prototypes/camp_exterior_preview.gd").new()
	add_child(exterior)
	world = Node2D.new()
	world.position = Vector2(610, 206)
	add_child(world)
	terrain = Terrain.new()
	world.add_child(terrain)
	terrain.load_fixture(0)
	structure = Node2D.new()
	world.add_child(structure)
	_build_structure()
	marker = Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-10,0),Vector2(0,-5),Vector2(10,0),Vector2(0,5)])
	marker.color = Color("e9bc65")
	marker.visible = false
	world.add_child(marker)
	_build_mountain_mist()
	_build_hud()
	terrace = preload("res://scripts/prototypes/camp_terrace_slice.gd").new()
	world.add_child(terrace)
	terrace.feedback.connect(func(text: String): status.text = text)
	load_fixture(_initial_fixture())
	exterior.reference_camera = world.position
	exterior.reference_zoom = world.scale.x

func _process(_delta: float) -> void:
	if is_instance_valid(exterior):
		exterior.sync_camera(world.position,current_pattern in [11,15],world.scale.x)
		if current_pattern == 15 and is_instance_valid(mountain_mist):
			var ratio: float = world.scale.x / exterior.reference_zoom
			mountain_mist.position = world.position + (Vector2(0,145)-exterior.reference_camera)*ratio
			mountain_mist.size = Vector2(1280,455)*ratio

func _initial_fixture() -> int:
	if OS.get_cmdline_user_args().has("--connected-preview"): return 13
	if OS.get_cmdline_user_args().has("--corner-preview"): return 12
	if OS.get_cmdline_user_args().has("--fullcamp-preview"): return 11
	return 15

func _label(text: String, point: Vector2, size_px := 18) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.add_theme_font_size_override("font_size", size_px)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _button(text: String, point: Vector2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = point
	node.size = Vector2(104,42)
	node.pressed.connect(action)
	add_child(node)
	return node

func _build_hud() -> void:
	# Keep enlarged terrain behind opaque HUD bands during detail inspection.
	for band in [Rect2(0,0,1280,145),Rect2(0,600,1280,120)]:
		var panel := ColorRect.new()
		panel.position = band.position
		panel.size = band.size
		panel.color = Color("161e22")
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
	heading = _label("营地 · 台地行走样板", Vector2(28,18), 26)
	subheading = _label("议事殿 / 连续台地 / 石阶 / 下层道路", Vector2(28,58), 17)
	_button("返回营地", Vector2(1140,22), _return_to_camp)
	_button("地形细看",Vector2(1140,88),func():
		if current_pattern == 15:
			world.scale = Vector2.ONE*0.7
			world.position = Vector2(630,140)
			return
		if current_pattern == 14:
			world.scale = Vector2.ONE*0.7
			world.position = Vector2(55,65)
			return
		load_fixture(11)
		world.scale = Vector2.ONE
		world.position = Vector2(640,-170)
	)
	var select := OptionButton.new()
	layout_selector = select
	select.position = Vector2(480,24)
	select.size = Vector2(220,42)
	for title in ["议事殿前庭", "实心块", "横向窄路", "纵向窄路", "L 形转角", "凹角", "单格", "单格孔洞", "对角 A", "对角 B", "台地行走小样", "全营地完整台地适配", "已确认完整台地", "双台地连通验证", "整图构图对照", "瓦片营地重做"]:
		select.add_item(title)
	select.select(_initial_fixture())
	select.item_selected.connect(load_fixture)
	add_child(select)
	var toggle := CheckButton.new()
	building_toggle = toggle
	toggle.text = "显示建筑"
	toggle.position = Vector2(730,24)
	toggle.button_pressed = show_structure
	toggle.toggled.connect(func(enabled: bool):
		show_structure = enabled
		structure.visible = enabled and current_pattern == 0
		if is_instance_valid(terrace): terrace.hall.visible = enabled
		if is_instance_valid(full_camp): full_camp.set_buildings_visible(enabled)
		if is_instance_valid(rebuild): rebuild.buildings.visible = enabled
	)
	add_child(toggle)
	var scenery_toggle := CheckButton.new()
	environment_toggle = scenery_toggle
	scenery_toggle.text = "环境候选"
	scenery_toggle.position = Vector2(920,24)
	scenery_toggle.button_pressed = true
	scenery_toggle.toggled.connect(func(on: bool):
		if current_pattern in [14,15] and is_instance_valid(rebuild): rebuild.overlay.visible = on
		else: exterior.enabled = on
	)
	add_child(scenery_toggle)
	scene_hint = _label("台地与建筑为结构灰盒，地面采用已确认纹理", Vector2(28,106), 16)
	var group := ButtonGroup.new()
	for i in range(4):
		var button := _button(["浏览拖动", "铺石地", "擦为泥土", "点击行走"][i], Vector2(28+i*120,614), func(): mode = i; dragging = false)
		edit_buttons.append(button)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == 0
	_button("复位样板", Vector2(522,614), func(): load_fixture(current_pattern))
	walk_controls = HBoxContainer.new()
	walk_controls.position = Vector2(660,614)
	add_child(walk_controls)
	for item in [["前往门前",Vector2i(2,2)],["返回下层",Vector2i(2,5)]]:
		var btn := Button.new()
		btn.text = item[0]
		btn.custom_minimum_size = Vector2(110,42)
		var destination: Vector2i = item[1]
		btn.pressed.connect(func(): terrace.move_to(destination))
		walk_controls.add_child(btn)
	var effects := CheckButton.new()
	effects.text = "灯光"
	effects.button_pressed = true
	effects.toggled.connect(func(on: bool): terrace.effects_enabled = on)
	walk_controls.add_child(effects)
	var stonework := OptionButton.new()
	stonework.add_item("台基：灰盒")
	stonework.add_item("台基：砌石")
	stonework.add_item("台基：岩坡")
	stonework.add_item("台基：瓦片候选")
	stonework.set_item_disabled(3,not preload("res://scripts/prototypes/camp_cliff_candidate.gd").available())
	stonework.select(2 if OS.get_cmdline_user_args().has("--rockwork-preview") else (1 if OS.get_cmdline_user_args().has("--stonework-preview") else 0))
	stonework.item_selected.connect(func(style: int): terrace.set_surface_style(style))
	walk_controls.add_child(stonework)
	full_controls = HBoxContainer.new()
	full_controls.position = Vector2(645,614)
	add_child(full_controls)
	var destination := OptionButton.new()
	for title in ["议事殿","百宝库","还魂殿","招贤馆","交易行","炼器坊","灵源院","传送阵"]: destination.add_item(title)
	full_controls.add_child(destination)
	var go := Button.new()
	go.text = "前往"
	go.pressed.connect(func(): full_camp.move_to_building(["council","treasury","revival","recruit","market","forge","garden","portal"][destination.selected]))
	full_controls.add_child(go)
	var full_style := OptionButton.new()
	full_style_selector = full_style
	for title in ["灰盒","砌石","岩坡","瓦片候选","连续岩层"]: full_style.add_item(title)
	full_style.set_item_disabled(3,not preload("res://scripts/prototypes/camp_cliff_candidate.gd").available())
	full_style.item_selected.connect(func(style: int): full_camp.set_surface_style(style))
	full_controls.add_child(full_style)
	var full_effects := CheckButton.new()
	full_effects.text = "动效"
	full_effects.button_pressed = true
	full_effects.toggled.connect(func(on: bool): full_camp.effects_enabled = on)
	full_controls.add_child(full_effects)
	var fit := Button.new()
	fit.text = "总览"
	fit.pressed.connect(_fit_full_camp)
	full_controls.add_child(fit)
	var full_stair_art := CheckButton.new()
	full_stair_art.text = "台阶图"
	full_stair_art.button_pressed = true
	full_stair_art.toggled.connect(func(on: bool):
		if is_instance_valid(full_camp): full_camp.set_stair_art(on)
	)
	full_controls.add_child(full_stair_art)
	corner_controls = HBoxContainer.new()
	corner_controls.position = Vector2(660,614)
	add_child(corner_controls)
	for title in ["显示占格", "48 高差对照", "接台阶", "原版对照"]:
		var check := CheckButton.new()
		check.text = title
		var is_grid: bool = title == "显示占格"
		var is_extended: bool = title == "接台阶"
		var is_original: bool = title == "原版对照"
		check.button_pressed = is_extended
		check.toggled.connect(func(on: bool):
			if not is_instance_valid(corner_sample): return
			if is_grid: corner_sample.show_grid = on
			elif is_original:
				corner_sample.set_original(on)
				status.text = "原版对照：接台阶时补高 14 像素" if on else "已确认连续岩层：保持原生像素，不重复增高"
			elif is_extended:
				corner_sample.set_extended(on)
				status.text = "台阶落差 48；点台地或下层落脚点，黄色标记经台阶行走" if on else "台阶已隐藏 · 保持当前素材原生比例"
			else: corner_sample.show_height = on
			corner_sample.queue_redraw()
		)
		corner_controls.add_child(check)
	stair_style_toggle = CheckButton.new()
	stair_style_toggle.text = "程序台阶对照"
	stair_style_toggle.position = Vector2(900,24)
	stair_style_toggle.toggled.connect(func(on: bool):
		if is_instance_valid(corner_sample): corner_sample.set_procedural_stairs(on)
	)
	add_child(stair_style_toggle)
	connected_controls = HBoxContainer.new()
	connected_controls.position = Vector2(660,614)
	add_child(connected_controls)
	for entry in [["前往左台地",0],["前往右台地",100],["前往中段",1004]]:
		var action := Button.new()
		action.text = entry[0]
		action.custom_minimum_size = Vector2(132,42)
		var id: int = entry[1]
		action.pressed.connect(func(): connected_sample.move_to(id))
		connected_controls.add_child(action)
	status = _label("原尺寸像素预览 · 拖动地图查看 · 修改仅本次有效", Vector2(28,672), 16)
	_label("内置纹理候选已确认 / 不写入存档", Vector2(865,674), 15)

func _build_mountain_mist() -> void:
	mountain_mist = TextureRect.new()
	mountain_mist.name = "MountainFootMist"
	mountain_mist.position = Vector2(0,145)
	mountain_mist.size = Vector2(1280,455)
	mountain_mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mountain_mist.texture = preload("res://resources/prototypes/camp_exterior_candidate/sky.png")
	mountain_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	void fragment() {
		float side = pow(abs(UV.x-0.5)*2.0,0.6);
		float line = mix(0.88,0.57,side);
		vec3 cloud = texture(TEXTURE,vec2(UV.x,0.5+UV.y*0.5)).rgb;
		float detail = (cloud.r+cloud.g+cloud.b)/3.0;
		float haze = smoothstep(line,1.02,UV.y+detail*0.06);
		COLOR = vec4(mix(cloud*vec3(0.43,0.49,0.57),vec3(0.12,0.17,0.21),0.45),haze*0.88);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	mountain_mist.material = material
	add_child(mountain_mist)

func load_fixture(index: int) -> void:
	current_pattern = index
	exterior.set_cloudscape(index == 15)
	mountain_mist.visible = index == 15
	environment_toggle.text = "显示路线" if index in [14,15] else "环境候选"
	environment_toggle.set_pressed_no_signal(false if index in [14,15] else exterior.enabled)
	layout_selector.select(index)
	building_toggle.visible = index < 12 or index in [14,15]
	building_toggle.text = "显示建筑"
	if index == 14 and not is_instance_valid(image_rebuild):
		image_rebuild = preload("res://scripts/prototypes/camp_rebuild.gd").new()
		world.add_child(image_rebuild)
		image_rebuild.feedback.connect(func(text: String): status.text = text)
	if index == 15 and not is_instance_valid(tile_rebuild):
		tile_rebuild = preload("res://scripts/prototypes/camp_tile_rebuild.gd").new()
		world.add_child(tile_rebuild)
		tile_rebuild.feedback.connect(func(text: String): status.text = text)
	if is_instance_valid(image_rebuild): image_rebuild.visible = index == 14
	if is_instance_valid(tile_rebuild): tile_rebuild.visible = index == 15
	if index in [14,15]:
		rebuild = tile_rebuild if index == 15 else image_rebuild
		rebuild.reset_walk()
		rebuild.overlay.hide()
		rebuild.buildings.visible = show_structure

	var is_terrace := index == 10
	var is_full := index == 11
	var is_corner := index == 12
	var is_connected := index == 13
	if is_connected and not is_instance_valid(connected_sample):
		connected_sample = preload("res://scripts/prototypes/camp_connected_terraces.gd").new()
		world.add_child(connected_sample)
		connected_sample.feedback.connect(func(text: String): status.text = text)
	if is_instance_valid(connected_sample):
		connected_sample.visible = is_connected
		connected_sample.set_process(is_connected)
		if is_connected: connected_sample.reset_walk()
	connected_controls.visible = is_connected
	if is_corner and not is_instance_valid(corner_sample):
		corner_sample = preload("res://scenes/prototypes/components/camp_continuous_terrace.tscn").instantiate()
		world.add_child(corner_sample)
		corner_sample.set_extended(true)
		corner_sample.feedback.connect(func(text: String): status.text = text)
	if is_instance_valid(corner_sample): corner_sample.visible = is_corner
	corner_controls.visible = is_corner
	stair_style_toggle.visible = is_corner
	for i in edit_buttons.size(): edit_buttons[i].disabled = (is_corner or is_connected) and i in [1,2]
	if is_corner or is_connected:
		mode = 0
		edit_buttons[0].button_pressed = true
	dragging = false
	if is_full and not is_instance_valid(full_camp):
		full_camp = preload("res://scripts/prototypes/camp_full_layout.gd").new()
		world.add_child(full_camp)
		full_camp.feedback.connect(func(text: String): status.text = text)
	if is_instance_valid(full_camp):
		full_camp.visible = is_full
		if is_full:
			full_camp.reset_walk()
			full_camp.set_buildings_visible(show_structure)
			full_style_selector.select(full_camp.surface_style)
	full_controls.visible = is_full
	heading.text = "营地 · 全景结构预览" if is_full else "营地 · 台地行走样板"
	subheading.text = "三层台地 / 七座建筑 / 四处石阶 / 传送阵" if is_full else "议事殿 / 连续台地 / 石阶 / 下层道路"
	terrain.visible = index < 10
	walk_controls.visible = is_terrace
	if is_instance_valid(terrace):
		terrace.visible = is_terrace
		if is_terrace:
			terrace.reset_walk()
			terrace.hall.visible = show_structure
	if index < 10: terrain.load_fixture(index)
	scene_hint.text = "点击行走：点地面移动，点建筑高亮；也可用下方按钮上下石阶" if is_terrace else "平面拼接验证 · 选择铺石地或擦为泥土编辑"
	world.position = Vector2(630,145) if is_full else Vector2(610,206)
	world.scale = Vector2.ONE*(0.54 if is_full else 1.0)
	if is_full: _fit_full_camp()
	if is_full: scene_hint.text = "全营地结构预览 · 点建筑前往门口 / 滚轮缩放 / 拖动平移 · 建筑与溪流为占位"
	structure.visible = show_structure and index == 0
	marker.visible = false
	if is_instance_valid(status): status.text = "仅石阶连接上下层 · 建筑占地不可穿越 · 修改仅本次有效" if is_terrace else "原尺寸像素预览 · 拖动地图查看 · 修改仅本次有效"
	if is_full: status.text = "选择建筑并前往门口 · 四处石阶形成两条路线 · 修改仅本次有效"
	if is_connected:
		heading.text = "营地 · 双台地连通"
		subheading.text = "已确认台地 / 实体台阶 / 连续下层道路"
		scene_hint.text = "点击左右台地或道路行走 · 途中可改道 · 拖动查看"
		status.text = "两处台阶连接上下层；点击右侧台地，检查完整往返路线"
		world.position = Vector2(320,265)
		world.scale = Vector2.ONE
	if is_corner:
		heading.text = "营地 · 连续岩壁样片"
		subheading.text = "连续顶面 / 内凹角 / 外凸角"
		scene_hint.text = "已确认转角样片 · 拖动查看 / 滚轮切换 1×、2× · 可显示占格与高差对照"
		status.text = "当前验收基准：完整台地与台阶 · 全营地旧适配未通过，不代表最终效果"
		world.position = Vector2(640,230)
		world.scale = Vector2.ONE*2

	if index in [14,15]:
		heading.text = "营地 · 连续山体重做候选"
		subheading.text = "独立建筑 / 标注路线 / 连续岩坡与溪谷"
		scene_hint.text = "点击建筑前往门口 · 拖动查看 · 建筑可隐藏 · 地形仍为视觉底稿候选"
		status.text = "已接入七个建筑门口与传送阵；尚未完成自由行走区域及地形分块"
		world.scale = Vector2.ONE*0.48
		world.position = Vector2(239,145)
		mode = 0
		edit_buttons[0].button_pressed = true
		for i in [1,2]: edit_buttons[i].disabled = true

	if index == 15:
		heading.text = "营地 · 可扩展瓦片重做"
		subheading.text = "TileMap分层 / 独立建筑 / 数据驱动边界"
		scene_hint.text = "点击格子或建筑行走 · 显示路线可查看可走格 · 拖动与滚轮缩放"
		status.text = "原生TileMap候选：增加JSON格子即可扩展；画面仍需材质与边界打磨"
		world.scale = Vector2.ONE*0.44
		world.position = Vector2(630,187)

func _fit_full_camp() -> void:
	if not is_instance_valid(full_camp): return
	var bounds: Rect2 = full_camp.overview_bounds()
	var area := Rect2(28,148,1224,446)
	var zoom := minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	world.scale = Vector2.ONE*zoom
	world.position = area.get_center()-bounds.get_center()*zoom

func _poly(points: Array, color: String) -> void:
	var node := Polygon2D.new()
	node.polygon = PackedVector2Array(points)
	node.color = Color(color)
	structure.add_child(node)

func _build_structure() -> void:
	# Low plinth plus solid placeholder volume; intentionally not mismatched legacy art.
	var origin: Vector2 = terrain.map_to_local(Vector2i(2,0))
	var a := origin + Vector2(-116,-46)
	var b := origin + Vector2(0,-104)
	var c := origin + Vector2(116,-46)
	var d := origin + Vector2(0,12)
	_poly([a,b,c,d], "665e4f")
	_poly([a,d,d+Vector2(0,12),a+Vector2(0,12)], "443f36")
	_poly([d,c,c+Vector2(0,12),d+Vector2(0,12)], "514b3f")
	var lift := Vector2(0,-62)
	_poly([a+lift,b+lift,c+lift,d+lift], "8f8166")
	_poly([a+lift,d+lift,d,a], "5d625f")
	_poly([d+lift,c+lift,c,d], "747570")
	var label := Label.new()
	label.text = "议事殿 · 占地"
	label.position = origin + Vector2(-68,-185)
	label.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC.ttf"))
	label.add_theme_font_size_override("font_size",18)
	structure.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if current_pattern == 12 and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if event.position.y > 145 and event.position.y < 604:
			world.scale = Vector2.ONE*(2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		return
	if current_pattern in [11,14,15] and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if event.position.y > 145 and event.position.y < 604:
			var local_point := world.to_local(event.position)
			var zoom := clampf(world.scale.x*(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),0.45,1.2)
			world.scale = Vector2.ONE*zoom
			world.position = event.position-local_point*zoom
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = event.position.y > 145 and event.position.y < 604
			mouse_down = event.position
			mouse_moved = false
			if dragging and mode in [1,2]: paint_at(event.position)
		else:
			if dragging and not mouse_moved and mode in [0,3] and current_pattern in [10,11,12,13,14,15]:
				var active: Node2D = rebuild if current_pattern in [14,15] else connected_sample if current_pattern == 13 else (corner_sample if current_pattern == 12 else (full_camp if current_pattern == 11 else terrace))
				active.click_at(event.position)
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		mouse_moved = mouse_moved or event.position.distance_to(mouse_down)>5
		if mode == 0:
			world.position += event.relative
			world.position.x = clampf(world.position.x,300,950)
			world.position.y = clampf(world.position.y,100,360)
		elif mode in [1,2] and event.position.y > 145 and event.position.y < 604: paint_at(event.position)

func paint_at(point: Vector2) -> void:
	if current_pattern >= 10:
		status.text = "行走样板地形已锁定；请切换平面布局进行地形编辑"
		return
	var cell := terrain.local_to_map(terrain.to_local(point))
	if terrain.paint(cell, mode == 1):
		marker.position = terrain.map_to_local(cell)
		marker.visible = true
		status.text = "已修改地形点 (%d, %d) · 四个相邻地块已更新 · 复位可恢复" % [cell.x,cell.y]
