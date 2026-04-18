extends GutTest


const SAVE_SLOT_ROLLBACK := 3
const SAVE_SLOT_INVALID_RUNTIME := 4
const SAVE_SLOT_METADATA := 5


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	TimeKeeper.stop()
	GameEvents.clear_event_history()


func test_save_game_rejects_invalid_runtime_state_without_overwriting_existing_slot() -> void:
	GameState.current_day = 1
	GameState.current_tick = 17
	SaveManager.save_game(SAVE_SLOT_INVALID_RUNTIME)
	var slot_path := "user://saves/slot_%d.json" % SAVE_SLOT_INVALID_RUNTIME
	var baseline_contents := FileAccess.get_file_as_string(slot_path)

	watch_signals(GameEvents)
	GameState.player = null
	SaveManager.save_game(SAVE_SLOT_INVALID_RUNTIME)

	assert_signal_emitted(GameEvents, "save_started")
	assert_signal_emitted(GameEvents, "save_failed")
	assert_signal_not_emitted(GameEvents, "save_completed")
	assert_eq(FileAccess.get_file_as_string(slot_path), baseline_contents)
	assert_eq(str(SaveManager.get_debug_snapshot().get("status", "")), "failed")


func test_failed_load_restores_previous_runtime_state() -> void:
	GameState.player.set_stat("health", 33.0)
	GameState.add_currency("credits", 15.0)
	GameState.set_flag("rollback_guard", "live_state")
	GameState.current_day = 6
	GameState.current_tick = 143
	var expected_snapshot := GameState.to_dict()

	GameState.player.set_stat("health", 5.0)
	GameState.spend_currency("credits", 100.0)
	GameState.set_flag("rollback_guard", "save_state")
	GameState.current_day = 2
	GameState.current_tick = 41
	SaveManager.save_game(SAVE_SLOT_ROLLBACK)

	var raw_payload := _read_slot_payload(SAVE_SLOT_ROLLBACK)
	var state_data_value: Variant = raw_payload.get("game_state", {})
	assert_true(state_data_value is Dictionary)
	var state_data: Dictionary = state_data_value
	state_data["current_location_id"] = "base:missing_location_for_rollback_test"
	raw_payload["game_state"] = state_data
	_write_slot_payload(SAVE_SLOT_ROLLBACK, raw_payload)

	GameState.from_dict(expected_snapshot)
	TimeKeeper.sync_from_game_state()

	watch_signals(GameEvents)
	assert_false(SaveManager.load_game(SAVE_SLOT_ROLLBACK))
	assert_signal_emitted(GameEvents, "load_started")
	assert_signal_emitted(GameEvents, "load_failed")
	assert_signal_not_emitted(GameEvents, "load_completed")

	var player := GameState.player as EntityInstance
	assert_true(player != null)
	assert_eq(player.get_stat("health"), 33.0)
	assert_eq(GameState.get_currency("credits"), 115.0)
	assert_eq(GameState.get_flag("rollback_guard", ""), "live_state")
	assert_eq(GameState.current_day, 6)
	assert_eq(GameState.current_tick, 143)


func test_get_slot_info_returns_empty_dictionary_for_malformed_metadata() -> void:
	var payload := {
		"save_schema_version": 1,
		"game_state": GameState.to_dict(),
		"slot_metadata": "broken",
	}
	_write_slot_payload(SAVE_SLOT_METADATA, payload)

	assert_true(SaveManager.slot_exists(SAVE_SLOT_METADATA))
	assert_eq(SaveManager.get_slot_info(SAVE_SLOT_METADATA), {})


func test_slot_exists_requires_required_save_fields() -> void:
	_write_slot_payload(SAVE_SLOT_METADATA, {"slot_metadata": {"display_name": "Broken"}})

	assert_false(SaveManager.slot_exists(SAVE_SLOT_METADATA))


func test_load_game_migrates_legacy_payload_without_optional_metadata() -> void:
	GameState.current_day = 4
	GameState.current_tick = 81
	var payload := {
		"game_state": GameState.to_dict(),
	}
	_write_slot_payload(SAVE_SLOT_METADATA, payload)

	assert_true(SaveManager.load_game(SAVE_SLOT_METADATA))
	var debug_snapshot := SaveManager.get_debug_snapshot()
	assert_eq(int(debug_snapshot.get("schema_version", 0)), SaveManager.SCHEMA_VERSION)
	assert_eq(GameState.current_day, 4)
	assert_eq(GameState.current_tick, 81)


func test_load_game_normalizes_inconsistent_saved_day_from_tick() -> void:
	GameState.current_day = 4
	GameState.current_tick = 9
	var payload := {
		"save_schema_version": SaveManager.SCHEMA_VERSION,
		"game_state": GameState.to_dict(),
	}
	_write_slot_payload(SAVE_SLOT_METADATA, payload)

	assert_true(SaveManager.load_game(SAVE_SLOT_METADATA))
	assert_eq(GameState.current_tick, 9)
	assert_eq(GameState.current_day, 1)


func test_load_game_rejects_future_schema_versions() -> void:
	var payload := {
		"save_schema_version": SaveManager.SCHEMA_VERSION + 1,
		"game_state": GameState.to_dict(),
	}
	_write_slot_payload(SAVE_SLOT_METADATA, payload)

	watch_signals(GameEvents)
	assert_false(SaveManager.load_game(SAVE_SLOT_METADATA))
	assert_signal_emitted(GameEvents, "load_failed")
	assert_signal_not_emitted(GameEvents, "load_completed")


func test_delete_game_removes_existing_slot_and_rejects_repeat_delete() -> void:
	GameState.current_day = 3
	GameState.current_tick = 42
	SaveManager.save_game(SAVE_SLOT_METADATA)

	assert_true(SaveManager.slot_exists(SAVE_SLOT_METADATA))
	assert_true(SaveManager.delete_game(SAVE_SLOT_METADATA))
	assert_false(SaveManager.slot_exists(SAVE_SLOT_METADATA))
	assert_eq(str(SaveManager.last_operation_summary.get("status", "")), "ok")
	assert_false(SaveManager.delete_game(SAVE_SLOT_METADATA))
	assert_eq(str(SaveManager.last_operation_summary.get("status", "")), "failed")


func test_autosave_slot_metadata_and_recency_are_visible() -> void:
	GameState.current_day = 2
	GameState.current_tick = 12
	SaveManager.save_game(SAVE_SLOT_ROLLBACK)
	GameState.current_day = 4
	GameState.current_tick = 77
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT)

	var autosave_info := SaveManager.get_slot_info(SaveManager.AUTOSAVE_SLOT)
	assert_eq(str(autosave_info.get("slot_label", "")), "Autosave")
	assert_eq(str(autosave_info.get("slot_kind", "")), SaveManager.SLOT_KIND_AUTOSAVE)
	assert_true(SaveManager.slot_exists(SaveManager.AUTOSAVE_SLOT))
	assert_eq(SaveManager.get_visible_slots()[0], SaveManager.AUTOSAVE_SLOT)
	assert_eq(SaveManager.get_most_recent_loadable_slot(), SaveManager.AUTOSAVE_SLOT)


func _read_slot_payload(slot: int) -> Dictionary:
	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_%d.json" % slot))
	if raw_data is Dictionary:
		var payload: Dictionary = raw_data
		return payload
	return {}


func _write_slot_payload(slot: int, payload: Dictionary) -> void:
	var file := FileAccess.open("user://saves/slot_%d.json" % slot, FileAccess.WRITE)
	assert_true(file != null)
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
