extends GutTest

const ACTIVITY_BOARD_BACKEND := preload("res://ui/screens/backends/activity_board_backend.gd")
const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const AVAILABLE_ID := "base:board_available"
const LOCKED_ID := "base:board_locked"
const HIDDEN_ID := "base:board_hidden"
const UPCOMING_ID := "base:board_upcoming"
const ONCE_ID := "base:board_once"


func before_each() -> void:
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: false,
		}
	})
	ScriptHookService.reset_world_gen_state()
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.activities.clear()
	_seed_ui_category_config()
	_seed_activity_board_data()
	GameEvents.clear_event_history()


func after_each() -> void:
	ScriptHookService.reset_world_gen_state()
	GameEvents.clear_event_history()
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
		}
	})
	await get_tree().process_frame


func test_activity_board_renders_available_rows() -> void:
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({"categories": ["training"]})

	var view_model: Dictionary = backend.build_view_model()
	var rows := _rows(view_model)

	assert_eq(rows.size(), 1)
	assert_eq(str(rows[0].get("activity_id", "")), AVAILABLE_ID)
	assert_eq(str(rows[0].get("status", "")), "available")
	assert_eq(str(rows[0].get("category_label", "")), "Training")
	assert_false(str(view_model.get("datetime_text", "")).is_empty())
	assert_true(bool(view_model.get("confirm_enabled", false)))


func test_activity_board_renders_locked_rows_when_enabled() -> void:
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({"show_locked": true})

	var view_model: Dictionary = backend.build_view_model()
	var locked_row := _row_for(_rows(view_model), LOCKED_ID)

	assert_false(locked_row.is_empty())
	assert_eq(str(locked_row.get("status", "")), "locked")
	assert_false(str(locked_row.get("reason", "")).is_empty())


func test_activity_board_renders_upcoming_rows_when_enabled() -> void:
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({"show_upcoming": true})

	var view_model: Dictionary = backend.build_view_model()
	var upcoming_row := _row_for(_rows(view_model), UPCOMING_ID)

	assert_false(upcoming_row.is_empty())
	assert_eq(str(upcoming_row.get("status", "")), "upcoming")
	assert_false(str(upcoming_row.get("time_text", "")).is_empty())
	assert_false(bool(upcoming_row.get("can_start", true)))


func test_activity_board_executes_selected_activity() -> void:
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({})
	backend.select_row(AVAILABLE_ID)

	var action: Dictionary = backend.confirm()
	var history := GameState.get_activity_history(AVAILABLE_ID)

	assert_true(action.is_empty())
	assert_eq(GameState.get_flag("board_available_done", false), true)
	assert_eq(int(history.get("completion_count", 0)), 1)
	assert_true(str(backend.build_view_model().get("status_text", "")).contains("Completed"))


func test_activity_board_refreshes_after_execution_removes_unavailable_rows() -> void:
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({"categories": ["single"]})

	var before_rows := _rows(backend.build_view_model())
	var action: Dictionary = backend.confirm()
	var after_rows := _rows(backend.build_view_model())

	assert_true(action.is_empty())
	assert_eq(before_rows.size(), 1)
	assert_eq(str(before_rows[0].get("activity_id", "")), ONCE_ID)
	assert_eq(after_rows.size(), 0)


func test_activity_board_surfaces_cached_activity_flavor() -> void:
	ScriptHookService.store_activity_flavor(AVAILABLE_ID, "The board carries cached activity flavor.")
	var backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	backend.initialize({})

	var view_model: Dictionary = backend.build_view_model()
	var row := _row_for(_rows(view_model), AVAILABLE_ID)

	assert_eq(str(row.get("ai_flavor_text", "")), "The board carries cached activity flavor.")


func _seed_ui_category_config() -> void:
	var ui_value: Variant = DataManager.config.get("ui", {})
	var ui_config: Dictionary = {}
	if ui_value is Dictionary:
		ui_config = (ui_value as Dictionary).duplicate(true)
	ui_config["activity_category_labels"] = {
		"training": "Training",
		"single": "One Shot",
	}
	ui_config["activity_category_colors"] = {
		"training": "warning",
		"single": "info",
	}
	DataManager.config["ui"] = ui_config


func _seed_activity_board_data() -> void:
	DataManager.activities[AVAILABLE_ID] = _activity({
		"activity_id": AVAILABLE_ID,
		"display_name": "Board Available",
		"completion_actions": [
			{"type": "set_flag", "flag_id": "board_available_done", "value": true},
		],
		"ui": {
			"preview_effects": [
				{"label": "Sets board_available_done"},
			],
		},
	})
	DataManager.activities[LOCKED_ID] = _activity({
		"activity_id": LOCKED_ID,
		"display_name": "Board Locked",
		"requirements": [
			{"type": "has_flag", "flag_id": "board_locked_ready", "value": true},
		],
	})
	DataManager.activities[HIDDEN_ID] = _activity({
		"activity_id": HIDDEN_ID,
		"display_name": "Board Hidden",
		"visible_if": [
			{"type": "has_flag", "flag_id": "board_hidden_visible", "value": true},
		],
	})
	DataManager.activities[UPCOMING_ID] = _activity({
		"activity_id": UPCOMING_ID,
		"display_name": "Board Upcoming",
		"schedule": {
			"start_tick": 5,
			"end_tick": 6,
		},
	})
	DataManager.activities[ONCE_ID] = _activity({
		"activity_id": ONCE_ID,
		"display_name": "Board Once",
		"category": "single",
		"repeat": {
			"rule": "once",
			"max_completions": -1,
			"max_completions_per_day": -1,
			"cooldown_ticks": 0,
			"cooldown_days": 0,
		},
	})


func _activity(overrides: Dictionary = {}) -> Dictionary:
	var activity := {
		"activity_id": "base:board_activity",
		"display_name": "Board Activity",
		"description": "Activity board fixture.",
		"category": "training",
		"kind": "standard",
		"duration_ticks": 0,
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
		"tags": ["board"],
		"ui": {},
		"ai": {},
	}
	for key_value in overrides.keys():
		activity[key_value] = overrides.get(key_value)
	return activity


func _rows(view_model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows_value: Variant = view_model.get("rows", [])
	if not rows_value is Array:
		return result
	var rows_array: Array = rows_value
	for row_value in rows_array:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			result.append(row.duplicate(true))
	return result


func _row_for(rows: Array[Dictionary], activity_id: String) -> Dictionary:
	for row in rows:
		if str(row.get("activity_id", "")) == activity_id:
			return row.duplicate(true)
	return {}
