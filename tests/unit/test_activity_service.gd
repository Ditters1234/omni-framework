extends GutTest

const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.activities.clear()
	GameEvents.clear_event_history()


func after_each() -> void:
	GameEvents.clear_event_history()


func test_hidden_activities_do_not_appear_on_board() -> void:
	_add_activity(_activity({
		"activity_id": "base:visible_activity",
		"display_name": "Visible",
	}))
	_add_activity(_activity({
		"activity_id": "base:hidden_activity",
		"display_name": "Hidden",
		"visible_if": [
			{"type": "has_flag", "flag_id": "base:show_hidden"},
		],
	}))

	var rows := ACTIVITY_SERVICE.build_board_rows({"include_locked": true})

	assert_eq(rows.size(), 1)
	assert_eq(str(rows[0].get("activity_id", "")), "base:visible_activity")


func test_locked_activities_appear_only_when_configured() -> void:
	_add_activity(_activity({
		"activity_id": "base:locked_activity",
		"requirements": [
			{"type": "has_flag", "flag_id": "base:ready"},
		],
	}))

	var default_rows := ACTIVITY_SERVICE.build_board_rows()
	var locked_rows := ACTIVITY_SERVICE.build_board_rows({"include_locked": true})

	assert_eq(default_rows.size(), 0)
	assert_eq(locked_rows.size(), 1)
	assert_false(bool(locked_rows[0].get("can_start", true)))
	assert_eq(str(locked_rows[0].get("failure_code", "")), "requirements_failed")


func test_requirements_block_execution_before_start() -> void:
	_add_activity(_activity({
		"activity_id": "base:requires_flag",
		"requirements": [
			{"type": "has_flag", "flag_id": "base:ready"},
		],
	}))
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity("base:requires_flag")
	var history := GameState.get_activity_history("base:requires_flag")

	assert_false(bool(result.get("success", true)))
	assert_eq(str(result.get("failure_code", "")), "requirements_failed")
	assert_eq(int(history.get("started_count", 0)), 0)
	assert_signal_not_emitted(GameEvents, "activity_started")


func test_schedule_blocks_execution_before_start() -> void:
	_add_activity(_activity({
		"activity_id": "base:scheduled_later",
		"schedule": {
			"start_tick": 5,
			"end_tick": 6,
		},
	}))
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity("base:scheduled_later")
	var history := GameState.get_activity_history("base:scheduled_later")

	assert_false(bool(result.get("success", true)))
	assert_eq(str(result.get("failure_code", "")), "not_scheduled")
	assert_eq(int(history.get("started_count", 0)), 0)
	assert_signal_not_emitted(GameEvents, "activity_started")


func test_repeat_rules_block_correctly() -> void:
	var once_activity := _activity({
		"activity_id": "base:once",
		"repeat": {"rule": "once"},
	})
	var limited_activity := _activity({
		"activity_id": "base:limited_daily",
		"repeat": {"rule": "limited_per_day", "max_completions_per_day": 2},
	})
	GameState.record_activity_completed("base:once")
	GameState.record_activity_completed("base:limited_daily")
	GameState.record_activity_completed("base:limited_daily")

	var once_status := ACTIVITY_SERVICE.get_activity_status(once_activity)
	var limited_status := ACTIVITY_SERVICE.get_activity_status(limited_activity)

	assert_false(bool(once_status.get("can_start", true)))
	assert_eq(str(once_status.get("failure_code", "")), "repeat_blocked")
	assert_false(bool(limited_status.get("can_start", true)))
	assert_eq(str(limited_status.get("failure_code", "")), "repeat_blocked")


func test_cooldowns_block_until_elapsed() -> void:
	var cooldown_activity := _activity({
		"activity_id": "base:cooldown",
		"repeat": {"rule": "cooldown", "cooldown_ticks": 3},
	})
	GameState.current_tick = 0
	GameState.current_day = 1
	GameState.record_activity_completed("base:cooldown")
	GameState.current_tick = 2

	var blocked_status := ACTIVITY_SERVICE.get_activity_status(cooldown_activity)
	GameState.current_tick = 3
	var ready_status := ACTIVITY_SERVICE.get_activity_status(cooldown_activity)

	assert_false(bool(blocked_status.get("can_start", true)))
	assert_eq(str(blocked_status.get("failure_code", "")), "cooldown_active")
	var cooldown_status_value: Variant = blocked_status.get("cooldown_status", {})
	assert_true(cooldown_status_value is Dictionary)
	if cooldown_status_value is Dictionary:
		var cooldown_status: Dictionary = cooldown_status_value
		assert_eq(int(cooldown_status.get("remaining_ticks", 0)), 1)
	assert_true(bool(ready_status.get("can_start", false)))


func test_location_policies_resolve_correctly() -> void:
	var destination_id := TEST_FIXTURE_WORLD.connected_location_id()
	var must_be_present := _activity({
		"activity_id": "base:must_be_present",
		"location_id": destination_id,
		"travel_policy": "must_be_present",
	})
	var ignore_location := _activity({
		"activity_id": "base:ignore_location",
		"location_id": destination_id,
		"travel_policy": "ignore_location",
	})
	var current_or_none := _activity({
		"activity_id": "base:current_or_none",
		"location_id": destination_id,
		"travel_policy": "current_or_none",
	})

	assert_eq(str(ACTIVITY_SERVICE.get_activity_status(must_be_present).get("failure_code", "")), "wrong_location")
	assert_true(ACTIVITY_SERVICE.can_start(ignore_location))
	assert_eq(str(ACTIVITY_SERVICE.get_activity_status(current_or_none).get("failure_code", "")), "wrong_location")


func test_auto_travel_uses_route_cost() -> void:
	_add_activity(_activity({
		"activity_id": "base:auto_travel",
		"duration_ticks": 0,
		"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
		"travel_policy": "auto_travel",
	}))

	var result := ACTIVITY_SERVICE.execute_activity("base:auto_travel")

	assert_true(bool(result.get("success", false)))
	assert_eq(int(result.get("travel_ticks", -1)), 1)
	assert_eq(GameState.current_location_id, TEST_FIXTURE_WORLD.connected_location_id())
	assert_eq(GameState.current_tick, 1)


func test_auto_travel_respects_location_entry_gates() -> void:
	var start_id := TEST_FIXTURE_WORLD.starting_location_id()
	var locked_id := "base:locked_activity_location"
	var start_location_value: Variant = DataManager.locations.get(start_id, {})
	assert_true(start_location_value is Dictionary)
	if not start_location_value is Dictionary:
		return
	var start_location: Dictionary = start_location_value
	var connections_value: Variant = start_location.get("connections", {})
	var connections: Dictionary = connections_value if connections_value is Dictionary else {}
	connections[locked_id] = 5
	start_location["connections"] = connections
	DataManager.locations[start_id] = start_location
	DataManager.locations[locked_id] = {
		"location_id": locked_id,
		"display_name": "Locked Activity Location",
		"locked_message": "Gate closed.",
		"entry_condition": {
			"type": "has_flag",
			"flag_id": "base:gate_open",
		},
		"connections": {},
	}
	_add_activity(_activity({
		"activity_id": "base:locked_auto_travel",
		"duration_ticks": 0,
		"location_id": locked_id,
		"travel_policy": "auto_travel",
	}))

	var result := ACTIVITY_SERVICE.execute_activity("base:locked_auto_travel")

	assert_false(bool(result.get("success", true)))
	assert_eq(str(result.get("failure_code", "")), "location_locked")
	assert_eq(str(result.get("reason", "")), "Gate closed.")
	assert_eq(GameState.current_location_id, start_id)
	assert_eq(GameState.current_tick, 0)


func test_duration_advances_time_through_timekeeper() -> void:
	_add_activity(_activity({
		"activity_id": "base:duration",
		"duration_ticks": 3,
	}))

	var result := ACTIVITY_SERVICE.execute_activity("base:duration")
	var tick_events := GameEvents.get_event_history(10, "time", "tick_advanced")

	assert_true(bool(result.get("success", false)))
	assert_eq(GameState.current_tick, 3)
	assert_eq(tick_events.size(), 3)


func test_start_actions_dispatch_before_duration_and_completion_actions_after() -> void:
	_add_activity(_activity({
		"activity_id": "base:ordered_actions",
		"duration_ticks": 2,
		"start_actions": [
			{"type": "emit_signal", "signal_name": "ui_notification_requested", "args": ["started", "info"]},
		],
		"completion_actions": [
			{"type": "emit_signal", "signal_name": "ui_notification_requested", "args": ["completed", "info"]},
		],
	}))

	ACTIVITY_SERVICE.execute_activity("base:ordered_actions")

	var activity_started_sequence := _first_sequence("activity_started")
	var started_notice_sequence := _notification_sequence("started")
	var first_tick_sequence := _first_sequence("tick_advanced")
	var completed_notice_sequence := _notification_sequence("completed")
	var activity_completed_sequence := _first_sequence("activity_completed")
	assert_true(activity_started_sequence < started_notice_sequence)
	assert_true(started_notice_sequence < first_tick_sequence)
	assert_true(first_tick_sequence < completed_notice_sequence)
	assert_true(completed_notice_sequence < activity_completed_sequence)


func test_activity_history_records_starts_completions_and_events() -> void:
	_add_activity(_activity({
		"activity_id": "base:history",
		"duration_ticks": 1,
		"outcomes": [
			{
				"outcome_id": "done",
				"weight": 1.0,
				"actions": [],
			},
		],
	}))
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity("base:history")
	var history := GameState.get_activity_history("base:history")
	var runtime_events := GameState.event_history

	assert_true(bool(result.get("success", false)))
	assert_eq(str(result.get("outcome_id", "")), "done")
	assert_eq(int(history.get("started_count", 0)), 1)
	assert_eq(int(history.get("completion_count", 0)), 1)
	assert_eq(GameState.get_last_activity_outcome("base:history"), "done")
	assert_signal_emitted(GameEvents, "activity_started")
	assert_signal_emitted(GameEvents, "activity_completed")
	assert_eq(runtime_events.size(), 1)
	if runtime_events[0] is Dictionary:
		var event_entry: Dictionary = runtime_events[0]
		assert_eq(str(event_entry.get("event_type", "")), "activity_completed")


func _activity(overrides: Dictionary = {}) -> Dictionary:
	var activity := {
		"activity_id": "base:test_activity",
		"display_name": "Test Activity",
		"description": "A test activity.",
		"category": "test",
		"kind": "standard",
		"duration_ticks": 1,
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"provider_entity_id": "",
		"travel_policy": "must_be_present",
		"schedule": {},
		"visible_if": [],
		"requirements": [],
		"start_actions": [],
		"completion_actions": [],
		"failure_actions": [],
		"outcomes": [],
		"repeat": {
			"rule": "always",
			"max_completions": -1,
			"max_completions_per_day": -1,
			"cooldown_ticks": 0,
			"cooldown_days": 0,
		},
		"tags": [],
		"ui": {},
		"ai": {},
	}
	for key_value in overrides.keys():
		activity[key_value] = overrides.get(key_value)
	return activity


func _add_activity(activity: Dictionary) -> void:
	DataManager.activities[str(activity.get("activity_id", ""))] = activity.duplicate(true)


func _first_sequence(signal_name: String) -> int:
	for event in GameEvents.get_event_history(0):
		if not event is Dictionary:
			continue
		var event_entry: Dictionary = event
		if str(event_entry.get("signal_name", "")) == signal_name:
			return int(event_entry.get("sequence", 0))
	return 0


func _notification_sequence(message: String) -> int:
	for event in GameEvents.get_event_history(0):
		if not event is Dictionary:
			continue
		var event_entry: Dictionary = event
		if str(event_entry.get("signal_name", "")) != "ui_notification_requested":
			continue
		var args_value: Variant = event_entry.get("args", [])
		if not args_value is Array:
			continue
		var args: Array = args_value
		if args.size() >= 1 and str(args[0]) == message:
			return int(event_entry.get("sequence", 0))
	return 0
