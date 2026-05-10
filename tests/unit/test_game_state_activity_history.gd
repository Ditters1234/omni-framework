extends GutTest


func before_each() -> void:
	GameState.reset()
	DataManager.activities.clear()
	DataManager.config = {
		"game": {
			"ticks_per_day": 24,
		},
		"calendar": {
			"day_start_tick": 0,
		},
	}
	DataManager.activities["base:study"] = {
		"activity_id": "base:study",
		"display_name": "Study",
		"category": "learning",
		"duration_ticks": 2,
	}
	DataManager.activities["base:patrol"] = {
		"activity_id": "base:patrol",
		"display_name": "Patrol",
		"category": "security",
		"duration_ticks": 1,
	}


func after_each() -> void:
	GameState.reset()
	DataManager.activities.clear()
	DataManager.config.clear()


func test_record_activity_started_and_completed_updates_history() -> void:
	GameState.current_tick = 26
	GameState.current_day = 2

	GameState.record_activity_started("base:study")
	GameState.record_activity_completed("base:study", {"outcome_id": "insight"})

	var history := GameState.get_activity_history("base:study")
	var completed_by_day_value: Variant = history.get("completed_by_day", {})

	assert_eq(int(history.get("started_count", 0)), 1)
	assert_eq(int(history.get("completion_count", 0)), 1)
	assert_eq(int(history.get("last_started_tick", -1)), 2)
	assert_eq(int(history.get("last_completed_tick", -1)), 2)
	assert_eq(int(history.get("last_started_day", -1)), 2)
	assert_eq(int(history.get("last_completed_day", -1)), 2)
	assert_eq(int(history.get("last_started_absolute_tick", -1)), 26)
	assert_eq(int(history.get("last_completed_absolute_tick", -1)), 26)
	assert_eq(GameState.get_last_activity_outcome("base:study"), "insight")
	assert_true(completed_by_day_value is Dictionary)
	if completed_by_day_value is Dictionary:
		var completed_by_day: Dictionary = completed_by_day_value
		assert_eq(int(completed_by_day.get("2", 0)), 1)


func test_activity_history_helpers_count_categories_and_today() -> void:
	GameState.current_tick = 26
	GameState.current_day = 2

	GameState.record_activity_completed("base:study")
	GameState.record_activity_completed("base:study")
	GameState.record_activity_completed("base:patrol")

	assert_eq(GameState.get_activity_completion_count("base:study"), 2)
	assert_eq(GameState.get_activity_category_completion_count("learning"), 2)
	assert_eq(GameState.get_activity_category_completion_count("security"), 1)
	assert_true(GameState.was_activity_completed_today("base:study"))

	GameState.current_tick = 50
	GameState.current_day = 3
	assert_false(GameState.was_activity_completed_today("base:study"))


func test_activity_history_accepts_explicit_timing_payload() -> void:
	GameState.record_activity_started("base:study", {
		"absolute_tick": 173,
		"tick_of_day": 5,
		"day": 8,
	})
	GameState.record_activity_completed("base:study", {
		"absolute_tick": 174,
		"tick": 6,
		"day": 8,
		"last_outcome_id": "fallback_alias",
	})

	var history := GameState.get_activity_history("base:study")

	assert_eq(int(history.get("last_started_absolute_tick", -1)), 173)
	assert_eq(int(history.get("last_started_tick", -1)), 5)
	assert_eq(int(history.get("last_started_day", -1)), 8)
	assert_eq(int(history.get("last_completed_absolute_tick", -1)), 174)
	assert_eq(int(history.get("last_completed_tick", -1)), 6)
	assert_eq(int(history.get("last_completed_day", -1)), 8)
	assert_eq(GameState.get_last_activity_outcome("base:study"), "fallback_alias")


func test_activity_history_returns_copies() -> void:
	GameState.record_activity_completed("base:study")

	var history := GameState.get_activity_history("base:study")
	history["completion_count"] = 99

	assert_eq(GameState.get_activity_completion_count("base:study"), 1)


func test_validate_runtime_state_reports_missing_activity_template() -> void:
	GameState.record_activity_completed("base:missing")

	var issues := GameState.validate_runtime_state()

	assert_true(_messages_contain(issues, "missing activity template"))


func _messages_contain(messages: Array[String], expected_fragment: String) -> bool:
	for message in messages:
		if message.contains(expected_fragment):
			return true
	return false
