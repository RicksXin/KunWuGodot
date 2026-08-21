extends SceneTree

const ATTRIBUTE_KEYS := [
	"strength", "magic", "technique", "speed", "constitution", "armor", "resistance"
]
const ROOT_IDS := [
	"mixed_root", "pseudo_root", "triple_root", "dual_root", "heavenly_root", "variant_root"
]
const PRODUCTION_JOBS := [
	"spiritGrain", "spiritWood", "darkIron", "spiritStone", "gengJing"
]
const REQUIRED_JSON_PATHS := [
	"res://data/balance/combat_constants.json",
	"res://data/balance/growth_rates.json",
	"res://data/balance/production_rates.json",
	"res://data/balance/realm_ranges.json",
	"res://data/balance/spiritual_root_multipliers.json",
	"res://data/config/combat_d0.json",
	"res://data/config/default_profile.json",
	"res://data/config/expedition_preparation.json",
	"res://data/config/ling_pu_config.json",
	"res://data/maps/map_01_demo.json",
	"res://data/maps/map_01_manifest.json",
	"res://data/maps/map_02_manifest.json"
]

var errors: Array[String] = []

func _initialize() -> void:
	_validate_required_json()
	_validate_growth_rates()
	_validate_spiritual_roots()
	_validate_combat_constants()
	_validate_production_rates()
	_validate_realm_ranges()
	_validate_map_files()
	if errors.is_empty():
		print("PROJECT_DATA_VALIDATION_OK")
		quit(0)
		return
	for message in errors:
		push_error(message)
	print("PROJECT_DATA_VALIDATION_FAILED: %d error(s)" % errors.size())
	quit(1)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("missing or unreadable JSON: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		_fail("invalid JSON: %s" % path)
	return parsed

func _validate_required_json() -> void:
	for path in REQUIRED_JSON_PATHS:
		var parsed: Variant = _read_json(path)
		if parsed != null and not parsed is Dictionary:
			_fail("JSON root must be an object: %s" % path)

func _validate_growth_rates() -> void:
	var table: Variant = _read_json("res://data/balance/growth_rates.json")
	if not table is Dictionary:
		return
	var careers := table as Dictionary
	for career_id in careers:
		if str(career_id).begins_with("//"):
			continue
		var row: Variant = careers[career_id]
		if not row is Dictionary:
			_fail("growth row must be an object: %s" % career_id)
			continue
		for key in ATTRIBUTE_KEYS:
			if not row.has(key) or not _is_non_negative_json_integer(row[key]):
				_fail("growth row %s has invalid %s" % [career_id, key])
		for key in row:
			if not ATTRIBUTE_KEYS.has(str(key)):
				_fail("growth row %s has unknown attribute %s" % [career_id, key])

func _validate_spiritual_roots() -> void:
	var table: Variant = _read_json("res://data/balance/spiritual_root_multipliers.json")
	if not table is Dictionary:
		return
	var previous_base := -1
	var previous_growth := -1
	for root_id in ROOT_IDS:
		if not table.has(root_id) or not table[root_id] is Dictionary:
			_fail("missing spiritual root row: %s" % root_id)
			continue
		var row: Dictionary = table[root_id]
		var base := int(row.get("basePercent", -1))
		var growth := int(row.get("growthPercent", -1))
		if base <= previous_base or growth <= previous_growth:
			_fail("spiritual root multipliers must increase at %s" % root_id)
		previous_base = base
		previous_growth = growth
	if previous_growth > 200:
		_fail("highest spiritual root growthPercent must not exceed 200")

func _validate_combat_constants() -> void:
	var document: Variant = _read_json("res://data/balance/combat_constants.json")
	if not document is Dictionary:
		return
	var constants: Variant = document.get("combat_constants")
	if not constants is Dictionary:
		_fail("combat_constants object is missing")
		return
	for key in ["constitutionHpFactor", "minActionIntervalTicks", "maxActionIntervalTicks", "minDamage"]:
		if int(constants.get(key, 0)) <= 0:
			_fail("combat constant must be positive: %s" % key)
	var defense: Variant = constants.get("defenseLevelConstant")
	if not defense is Dictionary or int(defense.get("base", 0)) <= 0 or int(defense.get("perTenLevels", -1)) < 0:
		_fail("defenseLevelConstant is invalid")

func _validate_production_rates() -> void:
	var document: Variant = _read_json("res://data/balance/production_rates.json")
	if not document is Dictionary:
		return
	var production: Variant = document.get("production_rates")
	if not production is Dictionary:
		_fail("production_rates object is missing")
		return
	if int(production.get("cycleSeconds", 0)) <= 0:
		_fail("production cycleSeconds must be positive")
	var jobs: Variant = production.get("jobs")
	if not jobs is Dictionary:
		_fail("production jobs object is missing")
		return
	for job_id in PRODUCTION_JOBS:
		if not jobs.has(job_id) or not jobs[job_id] is Dictionary:
			_fail("missing production job: %s" % job_id)
			continue
		var row: Dictionary = jobs[job_id]
		if int(row.get("outputPerWorker", -1)) < 0 or int(row.get("grainUpkeepPerWorker", -1)) < 0:
			_fail("invalid production values: %s" % job_id)
	var shutdown: Array = production.get("shutdownOrder", [])
	if shutdown.has("spiritGrain"):
		_fail("shutdownOrder must not contain spiritGrain")
	for job_id in PRODUCTION_JOBS.slice(1):
		if not shutdown.has(job_id):
			_fail("shutdownOrder is missing %s" % job_id)

func _validate_realm_ranges() -> void:
	var document: Variant = _read_json("res://data/balance/realm_ranges.json")
	if not document is Dictionary:
		return
	var ranges: Variant = document.get("realm_ranges")
	if not ranges is Dictionary:
		_fail("realm_ranges object is missing")
		return
	var expected_min := 1
	var seen_ids: Dictionary = {}
	for row_variant in ranges.get("realms", []):
		if not row_variant is Dictionary:
			_fail("realm row must be an object")
			continue
		var row: Dictionary = row_variant
		var realm_id := str(row.get("id", ""))
		var minimum := int(row.get("min", 0))
		var maximum := int(row.get("max", -1))
		if realm_id.is_empty() or seen_ids.has(realm_id):
			_fail("realm id is empty or duplicated: %s" % realm_id)
		seen_ids[realm_id] = true
		if minimum != expected_min or maximum < minimum:
			_fail("realm range is not continuous at %s" % realm_id)
		expected_min = maximum + 1
	if expected_min - 1 != int(ranges.get("maxLevel", -1)):
		_fail("realm ranges do not end at maxLevel")

func _validate_map_files() -> void:
	var map_document: Variant = _read_json("res://data/maps/map_01_demo.json")
	if map_document is Dictionary:
		var visual: Variant = map_document.get("visual")
		if not visual is Dictionary:
			_fail("map_01 visual object is missing")
		else:
			_validate_res_path(str(visual.get("scenePath", "")), "map_01 scenePath")
			_validate_res_path(str(visual.get("tileSetPath", "")), "map_01 tileSetPath")
			if int(visual.get("tileSourceSize", 0)) <= 0 or int(visual.get("logicalTileSize", 0)) <= 0:
				_fail("map_01 tile sizes must be positive")
	_validate_manifest("res://data/maps/map_01_manifest.json", true)
	_validate_manifest("res://data/maps/map_02_manifest.json", false)

func _validate_manifest(path: String, require_content: bool) -> void:
	var manifest: Variant = _read_json(path)
	if not manifest is Dictionary:
		return
	if str(manifest.get("mapId", "")).is_empty():
		_fail("manifest mapId is missing: %s" % path)
	if int(manifest.get("schemaVersion", 0)) <= 0:
		_fail("manifest schemaVersion is invalid: %s" % path)
	for key in ["scenePath", "mapDataPath", "tileSetPath"]:
		var value: Variant = manifest.get(key)
		if value is String and not value.is_empty():
			_validate_res_path(value, "%s %s" % [path, key])
		elif require_content:
			_fail("manifest requires %s: %s" % [key, path])

func _validate_res_path(path: String, label: String) -> void:
	if not path.begins_with("res://"):
		_fail("%s must use res://: %s" % [label, path])
	elif not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		_fail("%s does not exist: %s" % [label, path])

func _is_non_negative_json_integer(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return number >= 0.0 and number == floor(number)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
