extends GutTest

const SLOT := 1

var _original_save_dir := ""

func before_each() -> void:
	_original_save_dir = SaveManager.get_save_directory()
	SaveManager.set_save_directory_for_testing("user://test_saves/save_load_round_trip_hardening/")
	SaveManager.purge_all_saves()
	_build_minimal_save_fixture()


func after_each() -> void:
	SaveManager.purge_all_saves()
	GameState.reset()
	if not _original_save_dir.is_empty():
		SaveManager.set_save_directory_for_testing(_original_save_dir)


func _build_minimal_save_fixture() -> void:
	# Do not call GameState.new_game() here. In focused GUT runs, config/mod
	# loading can be intentionally minimal, and new_game() requires
	# game.starting_player_id. This fixture tests SaveManager, not boot config.
	GameState.reset()
	var player := EntityInstance.new()
	player.entity_id = "test:player"
	player.template_id = ""
	player.location_id = ""
	player.stats = {"health": 10.0, "health_max": 10.0}
	player.currencies = {"credits": 25.0}
	GameState.player = player
	GameState.entity_instances[player.entity_id] = player
	GameState.current_location_id = ""
	GameState.current_tick = 12
	GameState.current_day = 1


func test_runtime_state_buckets_survive_save_load_round_trip() -> void:
	assert_not_null(GameState.player, "Fixture should create a player without relying on game.starting_player_id.")

	GameState.set_flag("audit.flag", true)
	GameState.track_achievement_stat("audit_counter", 3.0)
	GameState.remember_ai_lore("audit:lore", {"text": "remember me", "score": 7})
	GameState.record_event("audit_event", {"value": 42})
	GameState.set_runtime_state("audit_bucket", "audit_key", {"nested": ["a", "b", "c"]})

	var before := GameState.to_dict()
	SaveManager.save_game(SLOT)
	assert_true(SaveManager.slot_exists(SLOT), "Slot should exist after saving.")
	var loaded := SaveManager.load_game(SLOT)
	assert_true(loaded, "Saved slot should load.")

	var after := GameState.to_dict()
	assert_eq(after.get("flags", {}).get("audit.flag", false), true)
	assert_eq(after.get("achievement_stats", {}).get("audit_counter", 0.0), 3.0)
	assert_eq(after.get("ai_lore_cache", {}).get("audit:lore", {}).get("text", ""), "remember me")
	assert_eq(after.get("runtime_state_buckets", {}).get("audit_bucket", {}).get("audit_key", {}).get("nested", []), ["a", "b", "c"])
	assert_gt(after.get("event_history", []).size(), 0)
	assert_eq(after.get("current_location_id", ""), before.get("current_location_id", ""))


func test_incomplete_current_schema_saves_are_rejected() -> void:
	var path := SaveManager.get_slot_path(SLOT)
	var incomplete_payload := {
		"save_schema_version": SaveManager.SCHEMA_VERSION,
		"game_state": {
			"player_id": "test:player",
			"entity_instances": {},
			"current_location_id": "",
			"current_tick": 0,
			"current_day": 1
		}
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(incomplete_payload, "\t"))
	file.close()

	assert_false(SaveManager.slot_exists(SLOT), "Incomplete current-schema save should not be considered loadable.")
	assert_false(SaveManager.load_game(SLOT), "Incomplete current-schema save should not load.")
	assert_true(str(SaveManager.last_operation_summary.get("reason", "")).contains("missing required field"))


func test_future_schema_saves_are_rejected() -> void:
	var path := SaveManager.get_slot_path(SLOT)
	var payload := SaveManager._build_save_payload({}, SLOT)
	payload["save_schema_version"] = SaveManager.SCHEMA_VERSION + 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	assert_false(SaveManager.slot_exists(SLOT), "Future-schema save should not be considered loadable.")
	assert_false(SaveManager.load_game(SLOT), "Future-schema save should not load.")
	assert_true(str(SaveManager.last_operation_summary.get("reason", "")).contains("newer than supported"))


func test_purge_all_saves_removes_old_slots() -> void:
	assert_not_null(GameState.player, "Fixture should create a valid player before saving.")
	SaveManager.save_game(SLOT)
	assert_true(SaveManager.slot_exists(SLOT), str(SaveManager.last_operation_summary.get("reason", "")))
	var deleted := SaveManager.purge_all_saves()
	assert_gt(deleted, 0)
	assert_false(SaveManager.slot_exists(SLOT))
