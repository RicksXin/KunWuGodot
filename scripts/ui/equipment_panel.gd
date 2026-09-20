extends Control
signal closed

const LABELS := {"strength":"力道", "magic":"法力", "technique":"神识", "speed":"遁速", "constitution":"肉身", "armor":"护体", "resistance":"定力"}
var hero_id := ""
var slot_choice := "accessory_1"
var notice := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.profile.get("roster", []).is_empty(): hero_id = str(Game.profile["roster"][0].get("instanceId", ""))
	_build()

func _text(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", preload("res://assets/fonts/noto_sans_sc_medium.tres"))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#e8dcbb"))
	parent.add_child(label)
	return label

func _build() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color("#091613f5")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 95)
	panel.size = Vector2(327, 640)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	_text(panel, "装备 · 穿戴与器纹")
	var choose := OptionButton.new()
	panel.add_child(choose)
	var heroes: Array = Game.profile.get("roster", [])
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		choose.add_item(Game.text(str(hero.get("nameKey", "")), str(hero.get("name", "修士"))))
		if hero.get("instanceId") == hero_id: choose.select(index)
	choose.item_selected.connect(func(index): hero_id = str(heroes[index].get("instanceId", "")); _build())
	var state := KWEquipment.ensure(Game.profile)
	var loadout: Dictionary = state["loadouts"].get(hero_id, {})
	for slot in KWEquipment.SLOTS:
		var item: Dictionary = state["instances"].get(loadout.get(slot, ""), {})
		var button := Button.new()
		button.text = "%s：%s%s" % [{"weapon":"武器", "armor":"防具", "accessory_1":"饰品一", "accessory_2":"饰品二"}[slot], item.get("name", "空"), " · 点击卸下" if not item.is_empty() else ""]
		button.disabled = item.is_empty()
		button.pressed.connect(func(): notice = str(Game.unequip_item(hero_id, slot).get("message", "")); _build())
		panel.add_child(button)
	_text(panel, "仓库 %d/%d · 待入库 %d" % [state["instances"].size(), int(Game.equipment_catalog().get("capacity", 100)), state["pending"].size()])
	_text(panel, notice if not notice.is_empty() else "选择修士后穿戴；器纹直接增加七维，无装备等级。")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 235)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for id in state["instances"]:
		var item: Dictionary = state["instances"][id]
		var box := VBoxContainer.new()
		list.add_child(box)
		var quality: String = str(Game.equipment_catalog().get("qualityNames", {}).get(item.get("qualityCode"), item.get("qualityCode", "")))
		_text(box, "%s · %s" % [quality, item.get("name", "装备")])
		var stats: Array[String] = []
		for key in item.get("stats", {}): stats.append("%s +%d" % [LABELS.get(key, key), int(item["stats"][key])])
		_text(box, " / ".join(stats))
		var owner := KWEquipment.owner(state, str(id))
		var row := HBoxContainer.new()
		box.add_child(row)
		var wear := Button.new()
		wear.text = "穿戴" if owner.is_empty() else "已装备"
		wear.disabled = not owner.is_empty()
		row.add_child(wear)
		wear.pressed.connect(func(): notice = str(Game.equip_item(hero_id, str(id), str(item.get("slot", "armor")) if item.get("slot") != "accessory" else slot_choice).get("message", "")); _build())
		var drop := Button.new()
		drop.text = "丢弃"
		drop.disabled = not owner.is_empty() or bool(item.get("locked", false)) or bool(item.get("protected", false))
		row.add_child(drop)
		drop.pressed.connect(func():
			var confirmation := ConfirmationDialog.new()
			confirmation.dialog_text = "确定丢弃 %s？" % item.get("name", "此装备")
			confirmation.confirmed.connect(func(): notice = str(Game.discard_equipment(str(id)).get("message", "")); _build())
			add_child(confirmation)
			confirmation.popup_centered(Vector2i(290, 140)))
	if state["instances"].is_empty(): _text(list, "暂无装备。地图1 Boss首杀获得法器1件、真宝1件。")
	if not state["pending"].is_empty(): _text(list, "仓库已满，新增装备保留在待入库区；整理后自动补入。")
	var close := Button.new()
	close.text = "返回百宝库"
	close.pressed.connect(func(): closed.emit())
	panel.add_child(close)
