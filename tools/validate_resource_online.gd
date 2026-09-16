extends Node

func _ready() -> void:
	var repository: Node = Game.get_resource_repository()
	var ok: bool = await repository.synchronize()
	if not ok:
		push_error("RESOURCE_ONLINE_SYNC_FAILED: " + repository.message)
		get_tree().quit(1)
		return
	var original: Dictionary = {}
	for code in repository.CODES: original[code] = 0
	for worker in repository.snapshot.state.workers:
		if worker.job is String: original[worker.job] += 1
	var allocation := original.duplicate(true)
	for code in allocation: allocation[code] = 0
	allocation["spiritGrain"] = 1
	ok = await repository.command({"type": "allocation", "allocations": allocation})
	if not ok:
		push_error("RESOURCE_ONLINE_ALLOCATION_FAILED: " + repository.message)
		get_tree().quit(1)
		return
	ok = await repository.command({"type": "allocation", "allocations": original})
	if not ok:
		push_error("RESOURCE_ONLINE_RESTORE_FAILED")
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--resource-full-validation"):
		var count: int = repository.snapshot.state.workers.size()
		ok = await repository.command({"type": "recruit"})
		if not ok or repository.snapshot.state.workers.size() != count + 1:
			push_error("RESOURCE_RECRUIT_FAILED")
			get_tree().quit(1)
			return
		ok = await repository.command({"type": "storage", "asset": "spiritWood"})
		if not ok or int(repository.snapshot.state.storageLevels.spiritWood) != 2:
			push_error("RESOURCE_STORAGE_FAILED")
			get_tree().quit(1)
			return
		var before: String = repository.snapshot.state.balances.spiritWood
		ok = await repository.command({"type": "storage", "asset": "spiritWood"})
		if ok or str(repository.snapshot.state.balances.spiritWood) != before:
			push_error("RESOURCE_INSUFFICIENT_BALANCE_NOT_REJECTED")
			get_tree().quit(1)
			return
		await repository.synchronize()
		var service_url: String = repository.base_url
		repository.base_url = "http://127.0.0.1:1"
		ok = await repository.synchronize()
		if ok or repository.connected or repository.pending.is_empty():
			push_error("RESOURCE_OFFLINE_STATE_FAILED")
			get_tree().quit(1)
			return
		repository.base_url = service_url
		ok = await repository.synchronize()
		if not ok or not repository.pending.is_empty():
			push_error("RESOURCE_PENDING_RECOVERY_FAILED")
			get_tree().quit(1)
			return
		print("RESOURCE_FULL_E2E_OK: recruitment, storage, insufficient funds, offline and pending recovery")
	print("RESOURCE_ONLINE_SMOKE_OK: authenticated sync, allocation, restore; real profile untouched")
	get_tree().quit(0)
