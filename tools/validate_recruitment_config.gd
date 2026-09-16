extends Node

func _ready() -> void:
	if not Game.suppress_profile_writes:
		_fail("Validation requires --no-profile-write")
		return
	Game.profile = Game.default_profile.duplicate(true)
	Game.profile.camp.lastSettledAtUtc = Game.now()
	Game.profile.camp.workerCount = 6
	Game.profile.wallet.spiritGrain = 1600
	var policy: Node = Game.get_recruitment_config()
	var fixture := {"schemaVersion": 1, "releaseId": "fixture-a", "initialWorkers": 6, "maxWorkers": 12, "workersPerRecruit": 1, "recruitCosts": ["310", "420", "650", "900", "1200", "1600"]}
	if not policy.accept(fixture):
		_fail("Fixture configuration rejected")
		return
	var camp := preload("res://scenes/camp.tscn").instantiate()
	add_child(camp)
	camp.call("_open_ling_pu")
	camp.call("_open_recruit_confirmation")
	var cost := camp.ling_pu_confirmation.find_child("RecruitmentCostLabel", true, false) as Label
	if cost == null or cost.text != "灵粮310":
		_fail("Recruitment dialog is not using the published cost table")
		return
	var old_quote: Dictionary = Game.recruitment_quote()
	fixture.releaseId = "fixture-b"
	fixture.recruitCosts[0] = "355"
	policy.accept(fixture)
	if Game.recruit_workers(old_quote) or Game.wallet_value("spiritGrain") != 1600:
		_fail("An outdated confirmation must not deduct newly changed fees")
		return
	cost = camp.ling_pu_confirmation.find_child("RecruitmentCostLabel", true, false) as Label
	if cost.text != "灵粮355" or not Game.recruit_workers(Game.recruitment_quote()):
		_fail("Updated dialog and deduction must agree")
		return
	if Game.wallet_value("spiritGrain") != 1245 or int(Game.profile.camp.workerCount) != 7 or int(Game.recruitment_quote().cost) != 420:
		_fail("Recruit one worker and select the next configured tier")
		return
	Game.profile.wallet.spiritGrain = 0
	if Game.recruit_workers(Game.recruitment_quote()):
		_fail("Insufficient grain must not recruit")
		return
	Game.profile.camp.workerCount = 61
	if Game.recruitment_quote().get("ok", false) or Game.recruit_workers() or int(Game.profile.camp.workerCount) != 61:
		_fail("Legacy over-limit workers must be retained without further recruitment")
		return
	policy.configuration = {}
	if Game.recruitment_quote().get("ok", false):
		_fail("Missing config must never fall back to the old 50-grain price")
		return
	if OS.get_cmdline_user_args().has("--recruitment-http-check"):
		if not await policy.refresh():
			_fail("Live published recruitment endpoint unavailable")
			return
		Game.profile.camp.workerCount = 6
		if not Game.recruitment_quote().get("ok", false):
			_fail("Live published rules did not reach the formal recruitment quote")
			return
	print("RECRUITMENT_CONFIG_OK: published tiers, dialog/deduction agreement, stale quote rejection, cap preservation, no 50 fallback")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
