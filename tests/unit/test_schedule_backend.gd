extends GutTest

const SCHEDULE_BACKEND := preload("res://ui/screens/backends/schedule_backend.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const ACTIVE_ID := "base:schedule_active"
const UPCOMING_ID := "base:schedule_upcoming"
const LOCKED_ID := "base:schedule_locked"
const HIDDEN_ID := "base:schedule_hidden"
const RANGE_ID := "base:schedule_range"
const WEEK_ID := "base:schedule_week"

var _original_config: Dictionary = {}
var _original_activities: Dictionary = {}
var _original_tick: int = 0
var _original_day: int = 1


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	_original_config = DataManager.config.duplicate(true)
	_original_activities = DataManager.activities.duplicate(true)
	_original_tick = GameState.current_tick
	_original_day = GameState.current_day
	DataManager.activities.clear()
	DataManager.config = {
		"game": {
			"ticks_per_day": 8,
		},
		"calendar": {
			"weekdays": ["First", "Second", "Third", "Fourth"],
			"months": [
				{"month_id": "short", "display_name": "Short", "days": 3, "tags": ["brief"]},
				{"month_id": "long", "display_name": "Long", "days": 5, "tags": ["wide"]},
			],
			"starting_absolute_day": 1,
			"starting_year": 1,
		},
		"ui": {
			"activity_category_labels": {
				"study": "Study",
				"work": "Work",
			},
		},
	}
	GameState.current_tick = 0
	GameState.current_day = 1
	_seed_schedule_data()


func after_each() -> void:
	DataManager.config = _original_config.duplicate(true)
	DataManager.activities = _original_activities.duplicate(true)
	GameState.current_tick = _original_tick
	GameState.current_day = _original_day
	await get_tree().process_frame


func test_schedule_day_view_projects_current_slots() -> void:
	var backend: RefCounted = SCHEDULE_BACKEND.new()
	backend.initialize({"view_mode": "day", "show_past": true})

	var view_model: Dictionary = backend.build_view_model()
	var slots := _slots(view_model)

	assert_eq(int(view_model.get("from_day", 0)), 1)
	assert_eq(int(view_model.get("to_day", 0)), 1)
	assert_eq(str(_slot_for(slots, ACTIVE_ID).get("status", "")), "active")
	assert_eq(str(_slot_for(slots, UPCOMING_ID).get("status", "")), "upcoming")
	assert_eq(str(_slot_for(slots, LOCKED_ID).get("status", "")), "locked")
	assert_true(_slot_for(slots, HIDDEN_ID).is_empty())


func test_schedule_range_view_projects_configured_day_count() -> void:
	var backend: RefCounted = SCHEDULE_BACKEND.new()
	backend.initialize({"view_mode": "range", "day_range": 3, "categories": ["work"]})

	var view_model: Dictionary = backend.build_view_model()
	var range_slot := _slot_for(_slots(view_model), RANGE_ID)

	assert_eq(int(view_model.get("from_day", 0)), 1)
	assert_eq(int(view_model.get("to_day", 0)), 3)
	assert_false(range_slot.is_empty())
	assert_eq(int(range_slot.get("absolute_day", 0)), 3)


func test_schedule_week_view_uses_configured_week_length() -> void:
	var backend: RefCounted = SCHEDULE_BACKEND.new()
	backend.initialize({"view_mode": "week", "categories": ["work"]})

	var view_model: Dictionary = backend.build_view_model()
	var week_slot := _slot_for(_slots(view_model), WEEK_ID)

	assert_eq(int(view_model.get("from_day", 0)), 1)
	assert_eq(int(view_model.get("to_day", 0)), 4)
	assert_false(week_slot.is_empty())
	assert_eq(int(week_slot.get("absolute_day", 0)), 4)


func test_schedule_month_view_uses_configured_month_length() -> void:
	var backend: RefCounted = SCHEDULE_BACKEND.new()
	backend.initialize({"view_mode": "month", "categories": ["work"]})

	var view_model: Dictionary = backend.build_view_model()
	var slots := _slots(view_model)

	assert_eq(int(view_model.get("from_day", 0)), 1)
	assert_eq(int(view_model.get("to_day", 0)), 3)
	assert_false(_slot_for(slots, RANGE_ID).is_empty())
	assert_true(_slot_for(slots, WEEK_ID).is_empty())


func _seed_schedule_data() -> void:
	DataManager.activities[ACTIVE_ID] = _activity({
		"activity_id": ACTIVE_ID,
		"display_name": "Active Study",
		"schedule": {"start_tick": 0, "end_tick": 2},
	})
	DataManager.activities[UPCOMING_ID] = _activity({
		"activity_id": UPCOMING_ID,
		"display_name": "Upcoming Study",
		"schedule": {"start_tick": 3, "end_tick": 4},
	})
	DataManager.activities[LOCKED_ID] = _activity({
		"activity_id": LOCKED_ID,
		"display_name": "Locked Study",
		"schedule": {"start_tick": 1, "end_tick": 2},
		"requirements": [
			{"type": "has_flag", "flag_id": "schedule_locked_ready", "value": true},
		],
	})
	DataManager.activities[HIDDEN_ID] = _activity({
		"activity_id": HIDDEN_ID,
		"display_name": "Hidden Study",
		"schedule": {"start_tick": 1, "end_tick": 2},
		"visible_if": [
			{"type": "has_flag", "flag_id": "schedule_hidden_visible", "value": true},
		],
	})
	DataManager.activities[RANGE_ID] = _activity({
		"activity_id": RANGE_ID,
		"display_name": "Range Work",
		"category": "work",
		"schedule": {"days": [3], "start_tick": 1, "end_tick": 2},
	})
	DataManager.activities[WEEK_ID] = _activity({
		"activity_id": WEEK_ID,
		"display_name": "Week Work",
		"category": "work",
		"schedule": {"days": [4], "start_tick": 1, "end_tick": 2},
	})


func _activity(overrides: Dictionary = {}) -> Dictionary:
	var activity := {
		"activity_id": "base:schedule_activity",
		"display_name": "Schedule Activity",
		"description": "Schedule backend fixture.",
		"category": "study",
		"kind": "standard",
		"duration_ticks": 1,
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"provider_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
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
		"tags": ["schedule"],
		"ui": {},
		"ai": {},
	}
	for key_value in overrides.keys():
		activity[key_value] = overrides.get(key_value)
	return activity


func _slots(view_model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots_value: Variant = view_model.get("slots", [])
	if not slots_value is Array:
		return result
	var slots_array: Array = slots_value
	for slot_value in slots_array:
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			result.append(slot.duplicate(true))
	return result


func _slot_for(slots: Array[Dictionary], activity_id: String) -> Dictionary:
	for slot in slots:
		if str(slot.get("activity_id", "")) == activity_id:
			return slot.duplicate(true)
	return {}
