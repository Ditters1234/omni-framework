extends GutTest

const SLOT := 1

var _original_save_dir := ""

func before_each() -> void:
	_original_save_dir = SaveManager.get_save_directory()
	SaveManager.set_save_directory_for_testing("user://test_saves/save_load_round_trip_hardening/")
	SaveManager.purge_all_saves()
	GameState.new_game()


func after_each() -> void:
	SaveManager.purge_all_saves()
	GameState.reset()
	if not _original_save_dir.is_empty():
		SaveManager.set_save_directory_for_testing(_original_save_dir)


func test_runtime_state_buckets_survive_save_load_round_trip() -> void:
	if GameState.player == null:
		pending("Base fixture did not create a player; check game.starting_player_id.")
		return

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


func test_old_or_incomplete_saves_are_rejected_without_migration() -> void:
	var path := SaveManager.get_slot_path(SLOT)
	var legacy_payload := {
		"save_schema_version": 1,
		"game_state": {
			"player_id": "player",
			"entity_instances": {},
			"current_location_id": "",
			"current_tick": 0,
			"current_day": 1
		}
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(legacy_payload, "\t"))
	file.close()

	assert_false(SaveManager.slot_exists(SLOT), "Old schema save should not be considered loadable.")
	assert_false(SaveManager.load_game(SLOT), "Old schema save should not load.")
	assert_true(str(SaveManager.last_operation_summary.get("reason", "")).contains("not supported"))


func test_purge_all_saves_removes_old_slots() -> void:
	SaveManager.save_game(SLOT)
	assert_true(SaveManager.slot_exists(SLOT))
	var deleted := SaveManager.purge_all_saves()
	assert_gt(deleted, 0)
	assert_false(SaveManager.slot_exists(SLOT))
