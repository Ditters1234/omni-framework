extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	_seed_encounter_fixture()


func test_unavailable_action_does_not_apply_cost() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("locked")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_eq(backend.get_resolved_outcome_id(), "")


func test_player_resolution_stops_opponent_action() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	var navigation := backend.select_action("finish")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_true(navigation.is_empty())
	assert_eq(backend.get_resolved_outcome_id(), "victory")
	var view_model := backend.build_view_model()
	assert_true(bool(view_model.get("resolved", false)))
	assert_eq(str(view_model.get("resolved_screen_text", "")), "Won.")
	assert_true(_reward_line_exists(view_model, "Credits +5"))


func test_resolve_effect_stops_later_effects() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("resolve_then_damage")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_eq(backend.get_resolved_outcome_id(), "fled")


func test_continue_navigates_after_resolution_review() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	var resolution_navigation := backend.select_action("finish")
	var continue_navigation := backend.continue_after_resolution()

	assert_true(resolution_navigation.is_empty())
	assert_eq(str(continue_navigation.get("type", "")), "pop")


func test_cancel_outcome_waits_for_resolution_review() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	var resolution_navigation := backend.cancel()
	var continue_navigation := backend.continue_after_resolution()

	assert_true(resolution_navigation.is_empty())
	assert_eq(backend.get_resolved_outcome_id(), "fled")
	assert_eq(str(continue_navigation.get("type", "")), "pop")


func test_encounter_tags_gate_followup_actions_and_expire() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("guard")
	var guarded_view := backend.build_view_model()
	assert_true(_action_available(guarded_view, "guarded_finish"))

	backend.select_action("guarded_finish")

	assert_eq(backend.get_resolved_outcome_id(), "victory")


func test_max_rounds_resolves_after_opponent_action() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var max_round_encounter := DataManager.get_encounter("base:test_encounter")
	var resolution_value: Variant = max_round_encounter.get("resolution", {})
	assert_true(resolution_value is Dictionary)
	if not resolution_value is Dictionary:
		return
	var resolution: Dictionary = resolution_value
	resolution["max_rounds"] = 1
	resolution["max_rounds_outcome"] = "timeout"
	max_round_encounter["resolution"] = resolution
	DataManager.encounters["base:max_round_encounter"] = max_round_encounter
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:max_round_encounter"})

	backend.select_action("wait")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before - 5.0)
	assert_eq(backend.get_resolved_outcome_id(), "timeout")


func _seed_encounter_fixture() -> void:
	var opponent_template := {
		"entity_id": "base:test_opponent",
		"display_name": "Test Opponent",
		"description": "Fixture encounter opponent.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {"health": 20, "health_max": 20, "power": 1},
		"inventory": [],
	}
	DataManager.entities["base:test_opponent"] = opponent_template.duplicate(true)
	var opponent := EntityInstance.from_template(opponent_template)
	GameState.commit_entity_instance(opponent)
	DataManager.encounters["base:test_encounter"] = {
		"encounter_id": "base:test_encounter",
		"display_name": "Fixture Encounter",
		"participants": {
			"player": {"entity_id": "player"},
			"opponent": {"entity_id": "base:test_opponent"},
		},
		"actions": {
			"player": [
				{
					"action_id": "locked",
					"label": "Locked",
					"availability": {"type": "stat_check", "entity_id": "encounter:player", "stat": "health", "op": ">=", "value": 999},
					"cost": [
						{"effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -10}
					],
					"on_success": [
						{"effect": "log", "text": "Should not happen."}
					],
				},
				{
					"action_id": "finish",
					"label": "Finish",
					"on_success": [
						{"effect": "modify_stat", "target": "opponent", "stat": "health", "base_delta": -100}
					],
				},
				{
					"action_id": "resolve_then_damage",
					"label": "Resolve Then Damage",
					"on_success": [
						{"effect": "resolve", "outcome_id": "fled"},
						{"effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -10}
					],
				},
				{
					"action_id": "guard",
					"label": "Guard",
					"on_success": [
						{"effect": "apply_tag", "target": "player", "tag": "guarded", "duration_rounds": 2}
					],
				},
				{
					"action_id": "guarded_finish",
					"label": "Guarded Finish",
					"availability": {"type": "has_encounter_tag", "role": "player", "tag": "guarded"},
					"on_success": [
						{"effect": "modify_stat", "target": "opponent", "stat": "health", "base_delta": -100}
					],
				},
				{
					"action_id": "wait",
					"label": "Wait",
					"on_success": [
						{"effect": "log", "text": "Waiting."}
					],
				},
			],
			"opponent": [
				{
					"action_id": "counter",
					"label": "Counter",
					"weight": 1,
					"on_success": [
						{"effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -5}
					],
				},
			],
		},
		"opponent_strategy": {"kind": "weighted_random"},
		"resolution": {
			"cancel_outcome": "fled",
			"outcomes": [
				{
					"outcome_id": "victory",
					"conditions": {"type": "stat_check", "entity_id": "encounter:opponent", "stat": "health", "op": "<=", "value": 0},
					"screen_text": "Won.",
					"reward": {"credits": 5},
					"pop_on_resolve": true,
				},
				{
					"outcome_id": "timeout",
					"trigger": "manual",
					"screen_text": "Timed out.",
					"pop_on_resolve": true,
				},
				{
					"outcome_id": "fled",
					"trigger": "manual",
					"screen_text": "Fled.",
					"pop_on_resolve": true,
				},
			],
		},
	}


func _action_available(view_model: Dictionary, action_id: String) -> bool:
	var actions_value: Variant = view_model.get("actions", [])
	if not actions_value is Array:
		return false
	var actions: Array = actions_value
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		if str(action.get("action_id", "")) == action_id:
			return bool(action.get("available", false))
	return false


func _reward_line_exists(view_model: Dictionary, expected_line: String) -> bool:
	var reward_lines_value: Variant = view_model.get("reward_lines", [])
	if not reward_lines_value is Array:
		return false
	var reward_lines: Array = reward_lines_value
	for reward_line_value in reward_lines:
		if str(reward_line_value) == expected_line:
			return true
	return false
