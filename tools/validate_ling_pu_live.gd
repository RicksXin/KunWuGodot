extends Node

func _ready() -> void:
	if not Game.suppress_profile_writes:
		push_error("Use --no-profile-write for this validation")
		get_tree().quit(1)
		return
	Game.profile = Game.default_profile.duplicate(true)
	Game.profile.camp.workerAssignments = {"spiritGrain": 1, "spiritWood": 0, "darkIron": 0}
	Game.profile.wallet.spiritGrain = 10
	Game.profile.camp.lastSettledAtUtc = Game.now()
	var camp := preload("res://scenes/camp.tscn").instantiate()
	add_child(camp)
	camp.call("_open_ling_pu")
	var stock := camp.find_child("spiritGrainStockLabel", true, false) as Label
	var countdown := camp.find_child("ProductionCycleLabel", true, false) as Label
	if stock == null or countdown == null:
		_fail("Production labels missing")
		return
	var before := stock.text
	var label_id := stock.get_instance_id()
	Game.profile.camp.lastSettledAtUtc = Game.now() - int(Game.ling_pu_config.get("baseCycleSeconds", 30))
	await get_tree().create_timer(1.25).timeout
	if stock.text == before or Game.wallet_value("spiritGrain") <= 10:
		_fail("Standing on page did not settle and refresh inventory")
		return
	if stock.get_instance_id() != label_id or not countdown.text.contains("下次结算"):
		_fail("Refresh rebuilt the modal or countdown is missing")
		return
	# Regression: 9 grain workers produce 9 while 12 wood + 5 iron consume 39.
	Game.profile.camp.workerAssignments = {"spiritGrain": 9, "spiritWood": 12, "darkIron": 5}
	Game.profile.wallet.spiritGrain = 800
	Game.profile.wallet.spiritWood = 0
	Game.profile.wallet.darkIron = 0
	Game.profile.camp.lastSettledAtUtc = Game.now() - int(Game.ling_pu_config.get("baseCycleSeconds", 30))
	camp.call("_refresh_production_display")
	if Game.wallet_value("spiritGrain") != 770 or not stock.text.begins_with("770 /"):
		_fail("Net upkeep must decrease grain and refresh the open panel")
		return
	var rate := camp.find_child("spiritGrainNetRateLabel", true, false) as Label
	if rate == null or rate.text != "净变化 -30":
		_fail("Grain rate must include upkeep, not gross worker output")
		return
	var before_preview := Game.profile.duplicate(true)
	var preview: Dictionary = Game.production_forecast()
	if Game.profile != before_preview or int(preview.balances.spiritGrain) != 740:
		_fail("Production forecast must be read-only and match the next cycle")
		return
	# Existing above-capacity balances remain spendable, never clamped up to their old value.
	var legacy_stock := Game.resource_capacity("spiritGrain") + 100
	Game.profile.wallet.spiritGrain = legacy_stock
	Game.profile.camp.lastSettledAtUtc = Game.now() - int(Game.ling_pu_config.get("baseCycleSeconds", 30))
	Game.settle_production()
	if Game.wallet_value("spiritGrain") != legacy_stock - 30:
		_fail("Over-capacity legacy grain must still pay upkeep")
		return
	camp.call("_close_modal")
	await get_tree().create_timer(1.1).timeout
	print("LING_PU_LIVE_REFRESH_OK: growth + net upkeep + legacy excess, HUD refresh, labels preserved, closed panel safe")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
