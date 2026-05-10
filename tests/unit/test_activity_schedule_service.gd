extends GutTest

const ACTIVITY_SCHEDULE_SERVICE := preload("res://systems/activity_schedule_service.gd")

var _original_config: Dictionary = {}
var _original_tick: int = 0
var _original_day: int = 1


func before_each() -> void:
	_original_config = DataManager.config.duplicate(true)
	_original_tick = GameState.current_tick
	_original_day = GameState.current_day
	DataManager.config = {
		"game": {
			"ticks_per_day": 10,
		},
		"calendar": {
			"weekdays": ["Mon", "Tue", "Wed"],
			"months": [
				{"month_id": "dawn", "display_name": "Dawn", "days": 2, "tags": ["bright"]},
				{"month_id": "dusk", "display_name": "Dusk", "days": 3, "tags": ["dim"]},
			],
			"starting_absolute_day": 1,
			"starting_year": 1,
		},
	}
	GameState.current_tick = 0
	GameState.current_day = 1


func after_each() -> void:
	DataManager.config = _original_config.duplicate(true)
	GameState.current_tick = _original_tick
	GameState.current_day = _original_day


func test_empty_schedule_is_always_scheduled() -> void:
	var activity := _activity({})

	var status := ACTIVITY_SCHEDULE_SERVICE.get_schedule_status(activity, 2, 9)
	var slots := ACTIVITY_SCHEDULE_SERVICE.expand_slots(activity, 1, 3)

	assert_true(bool(status.get("is_scheduled", false)))
	assert_eq(str(status.get("reason", "")), "")
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 99, 4))
	assert_eq(slots.size(), 3)
	assert_eq(int(slots[0].get("tick_of_day", -1)), 0)


func test_weekday_filters_work() -> void:
	var activity := _activity({"weekdays": ["Tue"]})

	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 0))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 2, 0))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 3, 0))

	var blocked_status := ACTIVITY_SCHEDULE_SERVICE.get_schedule_status(activity, 1, 0)
	assert_eq(str(blocked_status.get("reason", "")), "weekday")


func test_tick_windows_work() -> void:
	var activity := _activity({"start_tick": 3, "end_tick": 6})

	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 2))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 3))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 6))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 7))


func test_cross_midnight_windows_work() -> void:
	var activity := _activity({
		"start_tick": 8,
		"end_tick": 2,
		"crosses_midnight": true,
	})

	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 8))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 2, 0))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 2, 2))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 5))


func test_must_fit_windows_block_invalid_starts() -> void:
	var activity := _activity({
		"start_tick": 2,
		"end_tick": 6,
		"must_fit_window": true,
	}, 3)

	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 3))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 1, 4))

	var blocked_status := ACTIVITY_SCHEDULE_SERVICE.get_schedule_status(activity, 1, 4)
	assert_eq(str(blocked_status.get("reason", "")), "must_fit_window")


func test_absolute_day_and_month_filters_work() -> void:
	var activity := _activity({
		"days": [3, 4],
		"available_after_day": 3,
		"available_until_day": 4,
		"months": ["dusk"],
		"day_of_month": [1, 2],
	})

	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 2, 0))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 3, 0))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 4, 0))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(activity, 5, 0))


func test_month_tag_filters_work() -> void:
	var bright_activity := _activity({"month_tags": ["bright"]})
	var dim_activity := _activity({"month_tags": ["dim"]})

	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(bright_activity, 1, 0))
	assert_false(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(bright_activity, 3, 0))
	assert_true(ACTIVITY_SCHEDULE_SERVICE.is_scheduled(dim_activity, 3, 0))


func test_slot_expansion_and_next_slot_are_deterministic() -> void:
	var activity := _activity({
		"weekdays": ["Mon", "Wed"],
		"start_tick": 4,
	})

	var slots := ACTIVITY_SCHEDULE_SERVICE.expand_slots(activity, 1, 5)
	var next_slot := ACTIVITY_SCHEDULE_SERVICE.get_next_slot(activity, 2, 5, 5)

	assert_eq(slots.size(), 3)
	assert_eq(int(slots[0].get("display_day", 0)), 1)
	assert_eq(int(slots[0].get("tick_of_day", 0)), 4)
	assert_eq(int(slots[1].get("display_day", 0)), 3)
	assert_eq(int(slots[2].get("display_day", 0)), 4)
	assert_eq(int(next_slot.get("display_day", 0)), 3)
	assert_eq(int(next_slot.get("tick_of_day", 0)), 4)


func _activity(schedule: Dictionary, duration_ticks: int = 1) -> Dictionary:
	return {
		"activity_id": "base:test_activity",
		"display_name": "Test Activity",
		"category": "test",
		"duration_ticks": duration_ticks,
		"schedule": schedule.duplicate(true),
	}
