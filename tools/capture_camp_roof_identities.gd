extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1260,960)
	root.content_scale_size = Vector2i(1260,960)
	var background := ColorRect.new()
	background.color = Color(.065,.085,.10)
	background.size = Vector2(1260,960)
	root.add_child(background)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_tile_rebuild.json"))
	var names := {"treasury":"百宝库 · 木石重檐", "revival":"还魂殿 · 紫黑尖顶", "recruit":"招贤馆 · 深青楼阁", "forge":"炼器坊 · 炭黑烟楼", "garden":"灵源院 · 灰绿卷棚", "market":"交易行 · 暖褐檐与赭红棚"}
	var index := 0
	for kind in names:
		var item: Dictionary
		for b in data.buildings:
			if b.id == kind: item=b.duplicate(true)
		item.display_width=420.0
		item.yaw_degrees=0.0
		var sprite = load("res://scripts/prototypes/camp_building_3d_sprite.gd").new()
		root.add_child(sprite)
		sprite.configure(item)
		sprite.banners.seek_preview(.7)
		sprite.offset=Vector2.ZERO
		sprite.position=Vector2((index%3)*420, int(index/3)*470)
		var label:=Label.new()
		label.text=names[kind]
		label.position=sprite.position+Vector2(36,425)
		label.add_theme_font_size_override("font_size",22)
		root.add_child(label)
		index+=1
	for n in range(12): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/roof-identities.png")
	print("PASS six roof identities rendered")
	quit()
