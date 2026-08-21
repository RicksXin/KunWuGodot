extends SceneTree

const CANDIDATE_ATLAS := "res://art/review/map01/map01_road_dual_transition_candidate/tilemapdual_map01_road_dual_standard.png"
const CANDIDATE_MANIFEST := "res://art/review/map01/map01_road_dual_transition_candidate/review_manifest.json"
const FORMAL_DIR := "res://assets/compiled/map01_road"
const FORMAL_STANDARD := FORMAL_DIR + "/tilemapdual_standard.png"
const FORMAL_15PIECE := FORMAL_DIR + "/dual_grid_15piece.png"
const FORMAL_CHECK := FORMAL_DIR + "/dual_grid_15piece_check.png"
const FORMAL_BACKGROUND := FORMAL_DIR + "/dual_background_tile.png"
const FORMAL_MANIFEST := FORMAL_DIR + "/dual_grid_15piece_manifest.json"
const FORMAL_TILESET := "res://resources/tilemapdual_map01_road.tres"
const FORMAL_DEMO := "res://scenes/tilemapdual_road_demo.tscn"
const FORMAL_BUILDER := "res://tools/build_tilemapdual_road_scene.gd"
const BACKUP_DIR := "res://art/source_archive/runtime_backups/map01_road_pre_dual_transition_20260821"
const BACKUP_MARKER := BACKUP_DIR + "/backup_manifest.json"
const TILE := Vector2i(256, 256)

const MASK_TO_STANDARD := [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
]


func _init() -> void:
	assert(FileAccess.file_exists(ProjectSettings.globalize_path(CANDIDATE_MANIFEST)), "Candidate review manifest is missing")
	var parsed_review: Variant = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE_MANIFEST))
	assert(parsed_review is Dictionary, "Candidate review manifest is invalid")
	var review: Dictionary = parsed_review
	assert(str(review.get("status", "")) == "candidate_pending_user_visual_gate", "Candidate is not awaiting visual approval")
	assert(str(review.get("source_atlas_sha256", "")) == "8515aa007950600835c41973176a4804577757b1ebd29db618362492a8b48afc", "Candidate source provenance changed")
	_backup_previous_runtime()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMAL_DIR))
	var standard := Image.load_from_file(ProjectSettings.globalize_path(CANDIDATE_ATLAS))
	assert(not standard.is_empty(), "Candidate standard atlas is missing")
	assert(standard.get_size() == TILE * 4, "Candidate standard atlas must be 1024x1024")
	assert(not standard.detect_alpha(), "Dual-terrain candidate must be fully opaque")
	assert(standard.save_png(ProjectSettings.globalize_path(FORMAL_STANDARD)) == OK)
	_build_background(standard)
	_build_15piece(standard)
	_write_formal_manifest()
	print("MAP01_ROAD_DUAL_PROMOTION_PREPARED formal_atlas=%s backup=%s" % [FORMAL_STANDARD, BACKUP_DIR])
	quit.call_deferred(0)


func _backup_previous_runtime() -> void:
	if FileAccess.file_exists(ProjectSettings.globalize_path(BACKUP_MARKER)):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var paths: Array[String] = [
		FORMAL_STANDARD,
		FORMAL_15PIECE,
		FORMAL_CHECK,
		FORMAL_MANIFEST,
		FORMAL_TILESET,
		FORMAL_DEMO,
		FORMAL_BUILDER,
	]
	var copied: Array[String] = []
	for source_path: String in paths:
		var source_absolute: String = ProjectSettings.globalize_path(source_path)
		if not FileAccess.file_exists(source_absolute):
			continue
		var destination: String = BACKUP_DIR + "/" + source_path.get_file()
		assert(DirAccess.copy_absolute(source_absolute, ProjectSettings.globalize_path(destination)) == OK)
		copied.append(source_path)
	var payload: Dictionary = {
		"schema_version": 1,
		"backup_id": "map01_road_pre_dual_transition_20260821",
		"reason": "Preserve the previous transparent-road runtime before the user-approved gray-ground dual-terrain promotion.",
		"copied_paths": copied,
	}
	var manifest_file: FileAccess = FileAccess.open(BACKUP_MARKER, FileAccess.WRITE)
	assert(manifest_file != null)
	manifest_file.store_string(JSON.stringify(payload, "  ") + "\n")


func _build_background(standard: Image) -> void:
	var background: Image = standard.get_region(Rect2i(MASK_TO_STANDARD[0] * TILE, TILE))
	assert(not background.is_empty())
	assert(background.save_png(ProjectSettings.globalize_path(FORMAL_BACKGROUND)) == OK)


func _build_15piece(standard: Image) -> void:
	var atlas: Image = Image.create(TILE.x * 5, TILE.y * 3, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for mask in range(1, 16):
		var source: Vector2i = MASK_TO_STANDARD[mask] * TILE
		var index: int = mask - 1
		var destination := Vector2i(index % 5, index / 5) * TILE
		atlas.blit_rect(standard, Rect2i(source, TILE), destination)
	assert(atlas.save_png(ProjectSettings.globalize_path(FORMAL_15PIECE)) == OK)
	var check: Image = atlas.duplicate()
	var guide := Color("#ff4fd8")
	for x in range(1, 5):
		check.fill_rect(Rect2i(Vector2i(x * TILE.x - 1, 0), Vector2i(2, check.get_height())), guide)
	for y in range(1, 3):
		check.fill_rect(Rect2i(Vector2i(0, y * TILE.y - 1), Vector2i(check.get_width(), 2)), guide)
	assert(check.save_png(ProjectSettings.globalize_path(FORMAL_CHECK)) == OK)


func _write_formal_manifest() -> void:
	var payload: Dictionary = {
		"schema_version": 2,
		"system": "dual_grid_15piece",
		"asset_id": "map01_road_gray_ground_dual_transition_approved_20260821",
		"status": "approved",
		"approved_by": "user_visual_gate",
		"provider": "Meowa",
		"job_id": "job_4c169e3ca7ea44b398716657361d11a8",
		"prompt": "Background is gray rocky ground; foreground is an old ochre dirt road.",
		"source_atlas": "art/source_archive/meowa/map01_road_dual_transition/2026-08-21/Background_is_gray_rocky_ground_foreground_is_an_old_ochre_dirt_road/tileset.png",
		"source_atlas_sha256": "8515aa007950600835c41973176a4804577757b1ebd29db618362492a8b48afc",
		"tile_size_px": 256,
		"background_mode": "dual_opaque_gray_ground",
		"atlas_size_px": [1280, 768],
		"atlas_layout": {
			"columns": 5,
			"rows": 3,
			"order": "row-major masks 0x1 through 0xF",
		},
		"background_tile": FORMAL_BACKGROUND.trim_prefix("res://"),
		"runtime_atlas": FORMAL_STANDARD.trim_prefix("res://"),
		"runtime_tileset": FORMAL_TILESET.trim_prefix("res://"),
		"bit_order": {"nw": 1, "ne": 2, "sw": 4, "se": 8},
		"empty_mask": 0,
		"integration": "TileMapDual v5.0.2; draw only complete world tile 0xF at atlas (2,1).",
		"actual_meowa_credits": 10,
	}
	var file := FileAccess.open(FORMAL_MANIFEST, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(payload, "  ") + "\n")
