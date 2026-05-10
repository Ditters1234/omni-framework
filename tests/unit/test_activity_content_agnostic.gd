extends GutTest

const ACTIVITY_BOARD_BACKEND := preload("res://ui/screens/backends/activity_board_backend.gd")
const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const SCHEDULE_BACKEND := preload("res://ui/screens/backends/schedule_backend.gd")

const ORIGIN_ID := "wild:module:hub"
const DESTINATION_ID := "wild:module:lab"
const PLAYER_ID := "wild:module:traveler"
const PROVIDER_ID := "wild:module:mentor"
const ACTIVITY_ID := "wild:module:calibration"
const CATEGORY_ID := "custom_category"


func before_each() -> void:
	GameEvents.clear_event_history()
	GameState.reset()
	DataManager.clear_all()
	_seed_content_agnostic_world()
	TimeKeeper.stop()


func after_each() -> void:
	GameEvents.clear_event_history()
	GameState.reset()
	DataManager.clear_all()
	await get_tree().process_frame


func test_activity_surfaces_and_execution_use_authored_ids_without_base_assumptions() -> void:
	var board_backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
	board_backend.initialize({"categories": [CATEGORY_ID], "show_locked": true})
	var board_rows := _rows(board_backend.build_view_model())
	var board_row := _row_for(board_rows, ACTIVITY_ID)

	var schedule_backend: RefCounted = SCHEDULE_BACKEND.new()
	schedule_backend.initialize({"view_mode": "day", "categories": [CATEGORY_ID], "show_past": true})
	var schedule_slots := _slots(schedule_backend.build_view_model())
	var schedule_slot := _slot_for(schedule_slots, ACTIVITY_ID)

	var result: Dictionary = ACTIVITY_SERVICE.execute_activity(ACTIVITY_ID)
	var history := GameState.get_activity_history(ACTIVITY_ID)

	assert_false(board_row.is_empty())
	assert_eq(str(board_row.get("location_id", "")), DESTINATION_ID)
	assert_eq(str(board_row.get("provider_entity_id", "")), PROVIDER_ID)
	assert_eq(str(board_row.get("category_label", "")), "Custom Category")
	assert_eq(str(schedule_slot.get("status", "")), "active")
	assert_true(bool(result.get("success", false)))
	assert_eq(GameState.current_location_id, DESTINATION_ID)
	assert_eq(GameState.current_tick, 3)
	assert_eq(GameState.get_flag("wild.module.calibration_complete", false), true)
	assert_eq(int(history.get("completion_count", 0)), 1)
	assert_eq(GameState.get_activity_category_completion_count(CATEGORY_ID), 1)


func _seed_content_agnostic_world() -> void:
	DataManager.config = {
		"game": {
			"starting_player_id": PLAYER_ID,
			"starting_location": ORIGIN_ID,
			"ticks_per_day": 11,
		},
		"calendar": {
			"weekdays": ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"],
			"months": [
				{"month_id": "arc", "display_name": "Arc", "days": 4, "tags": ["test"]},
			],
			"starting_absolute_day": 1,
			"starting_year": 7,
		},
		"ui": {
			"activity_category_labels": {
				CATEGORY_ID: "Custom Category",
			},
		},
	}
	DataManager.locations = {
		ORIGIN_ID: {
			"location_id": ORIGIN_ID,
			"display_name": "Origin",
			"connections": {
				DESTINATION_ID: 2,
			},
		},
		DESTINATION_ID: {
			"location_id": DESTINATION_ID,
			"display_name": "Destination",
			"connections": {
				ORIGIN_ID: 2,
			},
		},
	}
	DataManager.entities = {
		PLAYER_ID: {
			"entity_id": PLAYER_ID,
			"display_name": "Traveler",
			"location_id": ORIGIN_ID,
			"stats": {},
			"currencies": {},
			"inventory": [],
		},
		PROVIDER_ID: {
			"entity_id": PROVIDER_ID,
			"display_name": "Mentor",
			"location_id": DESTINATION_ID,
			"stats": {},
			"currencies": {},
			"inventory": [],
		},
	}
	GameState.player = EntityInstance.from_template(DataManager.get_entity(PLAYER_ID))
	GameState.entity_instances[PLAYER_ID] = GameState.player
	GameState.current_location_id = ORIGIN_ID
	GameState.current_tick = 0
	GameState.current_day = 1
	DataManager.activities[ACTIVITY_ID] = {
		"activity_id": ACTIVITY_ID,
		"display_name": "Calibration",
		"description": "Runs without base content assumptions.",
		"category": CATEGORY_ID,
		"kind": "standard",
		"duration_ticks": 1,
		"location_id": DESTINATION_ID,
		"provider_entity_id": PROVIDER_ID,
		"travel_policy": "auto_travel",
		"schedule": {
			"start_tick": 0,
			"end_tick": 2,
		},
		"visible_if": [],
		"requirements": [],
		"start_actions": [],
		"completion_actions": [
			{"type": "set_flag", "flag_id": "wild.module.calibration_complete", "value": true},
		],
		"failure_actions": [],
		"outcomes": [],
		"repeat": {
			"rule": "always",
			"max_completions": -1,
			"max_completions_per_day": -1,
			"cooldown_ticks": 0,
			"cooldown_days": 0,
		},
		"tags": ["content_agnostic"],
		"ui": {},
		"ai": {},
	}


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


func _row_for(rows: Array[Dictionary], activity_id: String) -> Dictionary:
	for row in rows:
		if str(row.get("activity_id", "")) == activity_id:
			return row.duplicate(true)
	return {}


func _slot_for(slots: Array[Dictionary], activity_id: String) -> Dictionary:
	for slot in slots:
		if str(slot.get("activity_id", "")) == activity_id:
			return slot.duplicate(true)
	return {}
