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

	backend.select_action("finish")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_eq(backend.get_resolved_outcome_id(), "victory")


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
			"outcomes": [
				{
					"outcome_id": "victory",
					"conditions": {"type": "stat_check", "entity_id": "encounter:opponent", "stat": "health", "op": "<=", "value": 0},
					"screen_text": "Won.",
				},
			],
		},
	}
