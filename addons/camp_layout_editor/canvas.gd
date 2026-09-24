@tool
extends Control
signal selected(index: int)
signal moved(index: int, offset: Vector2i)
signal nudged(index: int, offset: Vector2)
var snap_to_grid := false
var preview_nudge := Vector2.ZERO
var model: RefCounted
var active := 0
var zoom := 0.65
var pan := Vector2(650,160)
var show_grid := true
var translucent := false
var sprites: Array[Sprite2D] = []
var live_sprites: Dictionary = {}
var world: Node2D
var overlay: Node2D
var npcs: Node2D
var live_stream: Node2D
var stream_definition: Dictionary = {}
var drag := false
var panning := false
var pressed_at := Vector2.ZERO
var origin_at := Vector2.ZERO
var preview_delta := Vector2i.ZERO
var ground: Texture2D
class Guides extends Node2D:
	var canvas: Control
	func _draw() -> void: canvas.draw_guides(self)
func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://addons/camp_layout_editor/ground_preview.png"):
		ground = load("res://addons/camp_layout_editor/ground_preview.png")
	world = Node2D.new()
	add_child(world)
	var mist := preload("res://scripts/prototypes/camp_mist.gd").new()
	mist.z_index = 4091
	world.add_child(mist)
	var ground_sprite := Sprite2D.new()
	ground_sprite.name = "CachedGround"
	ground_sprite.texture = ground
	ground_sprite.centered = false
	ground_sprite.position = Vector2(-1024,-256)
	world.add_child(ground_sprite)
	if ResourceLoader.exists("res://addons/camp_layout_editor/foreground_preview.png"):
		var foreground := Sprite2D.new()
		foreground.name = "ForegroundRocks"
		foreground.texture = load("res://addons/camp_layout_editor/foreground_preview.png")
		foreground.centered = false
		foreground.position = Vector2(-1024,-256)
		foreground.z_index = 4090
		world.add_child(foreground)
	overlay = Guides.new()
	overlay.canvas = self
	overlay.z_index = 4094
	add_child(overlay)
	resized.connect(queue_redraw)
func refresh() -> void:
	if world == null or model == null or model.data.is_empty(): return
	var current_stream: Dictionary = model.data.get("stream",{})
	if live_stream == null or current_stream != stream_definition:
		if live_stream != null:
			world.remove_child(live_stream)
			live_stream.queue_free()
		stream_definition = current_stream.duplicate(true)
		live_stream = preload("res://scripts/prototypes/camp_stream.gd").new()
		live_stream.definition = stream_definition
		world.add_child(live_stream)
		world.move_child(live_stream,0)
	if npcs == null:
		npcs = preload("res://scripts/prototypes/camp_npcs.gd").new()
		npcs.name = "CampNPCs"
		npcs.explicit_depth = true
		world.add_child(npcs)
	npcs.configure(model.data)
	for key in live_sprites.keys():
		var keep := false
		for item in model.items():
			if item.id == key and item.get("model_3d", "") == live_sprites[key].model_path: keep = true
		if not keep:
			live_sprites[key].queue_free()
			live_sprites.erase(key)
	for sprite in sprites:
		if sprite.get_script() == preload("res://scripts/prototypes/camp_building_3d_sprite.gd"): continue
		world.remove_child(sprite)
		sprite.queue_free()
	sprites.clear()
	for item in model.items():
		if item.has("prop"):
			var prop = preload("res://scripts/prototypes/camp_decoration.gd").new()
			prop.configure(item)
			prop.place(item,model.point(Vector2i(item.origin[0],item.origin[1])))
			prop.z_index = 0 if item.get("ground_decal",false) else roundi(prop.position.y)
			world.add_child(prop)
			sprites.append(prop)
			continue
		if item.has("model_3d"):
			var live = live_sprites.get(item.id)
			if live == null:
				live = preload("res://scripts/prototypes/camp_building_3d_sprite.gd").new()
				world.add_child(live)
				live_sprites[item.id] = live
			live.configure(item)
			var shift: Array = item.get("visual_offset", [0,0])
			live.position = model.point(Vector2i(item.door[0],item.door[1])) + Vector2(shift[0],shift[1])
			live.z_index = roundi(live.position.y) if item.get("occlusion_enabled",true) else -1000
			live.modulate.a = 0.35 if translucent else 1.0
			sprites.append(live)
			continue
		var sprite: Sprite2D = preload("res://scripts/prototypes/camp_building_sequence.gd").new() if item.has("sprite_frames") else Sprite2D.new()
		# Editor plugins may enter before a newly added PNG finishes its first import.
		if ResourceLoader.exists(item.texture):
			sprite.texture = load(item.texture)
		else:
			var raw := Image.load_from_file(item.texture)
			if raw != null: sprite.texture = ImageTexture.create_from_image(raw)
		if sprite.texture == null:
			world.add_child(sprite)
			sprites.append(sprite)
			continue
		sprite.rotation_degrees = float(item.get("rotation_degrees",0.0))
		sprite.centered = false
		var anchor: Array = item.get("door_anchor",[sprite.texture.get_width()*0.5,sprite.texture.get_height()])
		sprite.offset = -Vector2(anchor[0],anchor[1])
		sprite.scale = Vector2.ONE*float(item.get("display_width",220))/sprite.texture.get_width()
		if item.get("mirror_x",false): sprite.scale.x *= -1
		var offset: Array = item.get("visual_offset",[0,0])
		sprite.position = model.point(Vector2i(item.door[0],item.door[1]))+Vector2(offset[0],offset[1])
		sprite.visible = item.get("preview_visible",false)
		sprite.z_index = 0 if item.get("kind", "") == "portal" else (roundi(sprite.position.y) if item.get("occlusion_enabled",true) else -1000)
		if not item.has("sprite_frames"):
			var shader := Shader.new()
			shader.code = "shader_type canvas_item; uniform float alpha_cut=0.0; uniform float opacity=1.0; void fragment(){vec4 c=texture(TEXTURE,UV); if(c.a<alpha_cut)discard; float timber=smoothstep(0.04,0.16,c.r-c.b)*smoothstep(0.42,0.60,UV.y); COLOR=vec4(mix(c.rgb*vec3(0.69,0.77,0.85),c.rgb*vec3(1.12,0.94,0.70),timber*0.70),c.a*opacity);}"
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("alpha_cut",float(item.get("alpha_cut",0)))
			material.set_shader_parameter("opacity",0.35 if translucent else 1.0)
			sprite.material = material
		if item.has("sprite_frames"):
			sprite.modulate.a = 0.35 if translucent else 1.0
			sprite.configure(item)
		world.add_child(sprite)
		sprites.append(sprite)
	queue_redraw()
func fit() -> void:
	zoom = minf(size.x/1800.0,size.y/1200.0)
	pan = Vector2(size.x*0.5,size.y*0.08)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("18262c"))
	if world == null: return
	world.position = pan
	world.scale = Vector2.ONE*zoom
	overlay.position = pan
	overlay.scale = Vector2.ONE*zoom
	overlay.queue_redraw()
func diamond(centre: Vector2) -> PackedVector2Array:
	return PackedVector2Array([centre+Vector2(0,-32),centre+Vector2(64,0),centre+Vector2(0,32),centre+Vector2(-64,0),centre+Vector2(0,-32)])
func draw_guides(target: Node2D) -> void:
	if model == null or model.data.is_empty(): return
	if show_grid:
		for cell in model.heights(): target.draw_polyline(diamond(model.point(cell)),Color(0.6,0.8,0.85,0.2),1.0/zoom)
		for c in model.data.get("west_courtyard",{}).get("reserved_cells",[]):
			target.draw_colored_polygon(diamond(model.point(Vector2i(c[0],c[1]))),Color(0.2,0.8,1,0.12))
	for i in range(model.items().size()):
		var b: Dictionary = model.items()[i]
		if not b.get("preview_visible",false) and i != active: continue
		if b.has("prop") and i != active: continue
		var delta := preview_delta if i==active and drag else Vector2i.ZERO
		var origin := Vector2i(b.origin[0],b.origin[1])+delta
		var door := Vector2i(b.door[0],b.door[1])+delta
		var visual_offset: Array = b.get("visual_offset",[0,0])
		var threshold: Vector2 = model.point(door)+Vector2(visual_offset[0],visual_offset[1])
		if i==active:
			if b.has("collision_polygon"):
				var definition: Dictionary = model.data.duplicate(true)
				definition.buildings = [b]
				for polygon in model.Collision.polygons(definition):
					target.draw_colored_polygon(polygon,Color(1,0.4,0.2,0.22))
					var outline: PackedVector2Array = polygon.duplicate()
					outline.append(outline[0])
					target.draw_polyline(outline,Color("ffbb55"),2/zoom)
			if b.has("approach") and not b.has("collision_polygon"):
				var approach := Vector2i(b.approach[0],b.approach[1])+delta
				target.draw_line(model.point(approach),model.point(door),Color("66ff99"),3/zoom)
			target.draw_circle(threshold,5/zoom,Color("66ff99"))
		var label_offset: Array = b.get("label_offset",[-35,18])
		target.draw_string(ThemeDB.fallback_font,threshold+Vector2(label_offset[0],label_offset[1])+Vector2(0,16),b.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
func zoom_at(factor: float, focus: Vector2) -> void:
	var previous := zoom
	zoom = clampf(zoom*factor,0.1,6.0)
	pan = focus-(focus-pan)*(zoom/previous)
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if model == null or sprites.is_empty(): return
	if event is InputEventMagnifyGesture:
		zoom_at(event.factor,event.position)
		accept_event()
		return
	if event is InputEventPanGesture:
		if event.ctrl_pressed or event.meta_pressed:
			zoom_at(exp(-event.delta.y*0.08),event.position)
		else:
			pan -= event.delta*20.0
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			zoom_at(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12,event.position)
			accept_event()
		elif event.button_index==MOUSE_BUTTON_MIDDLE or event.button_index==MOUSE_BUTTON_RIGHT:
			panning = event.pressed
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse: Vector2 = (event.position-pan)/zoom
				var best := -1
				var depth := -INF
				for i in range(sprites.size()):
					var sprite := sprites[i]
					if not sprite.visible: continue
					var local: Vector2 = sprite.transform.affine_inverse()*mouse
					if sprite.get_rect().has_point(local) and sprite.is_pixel_opaque(local) and sprite.z_index>depth:
						best = i
						depth = sprite.z_index
				if best>=0:
					active = best
					selected.emit(best)
					drag = true
					pressed_at = event.position
					origin_at = sprites[active].position
					preview_delta = Vector2i.ZERO
					preview_nudge = Vector2.ZERO
			elif drag:
				drag = false
				if preview_delta!=Vector2i.ZERO: moved.emit(active,preview_delta)
				if preview_nudge!=Vector2.ZERO: nudged.emit(active,preview_nudge)
				preview_delta = Vector2i.ZERO
				preview_nudge = Vector2.ZERO
				refresh()
	elif event is InputEventMouseMotion:
		if panning:
			pan += event.relative
			queue_redraw()
		elif drag:
			var displacement: Vector2 = (event.position-pressed_at)/zoom
			if not snap_to_grid:
				preview_nudge = displacement.round()
				sprites[active].position = origin_at+preview_nudge
				queue_redraw()
				return
			preview_delta = Vector2i(roundi(displacement.x/128+displacement.y/64),roundi(displacement.y/64-displacement.x/128))
			var item: Dictionary = model.items()[active]
			var door := Vector2i(item.door[0],item.door[1])+preview_delta
			var offset: Array = item.get("visual_offset",[0,0])
			sprites[active].position = model.point(door)+Vector2(offset[0],offset[1])
			queue_redraw()
