extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const ENCOUNTER_RUNTIME := preload("res://systems/encounter_runtime.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()


func test_compute_delta_uses_user_and_target_stat_modifiers() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var opponent := _make_opponent({"armor": 2, "health": 20, "health_max": 20})
	var effect := {
		"base_delta": -4,
		"stat_modifiers": {
			"user.power": -2.0,
			"target.armor": 1.5
		}
	}

	var delta := ENCOUNTER_RUNTIME.compute_delta(effect, player, opponent)

	assert_eq(delta, -3.0)


func test_pick_weighted_action_uses_availability_and_weight_modifiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var context := {
		"encounter_stats": {"pressure": 75.0},
		"encounter_entities": {},
		"encounter_tags": {"player": {}, "opponent": {}},
	}
	var actions := [
		{
			"action_id": "blocked",
			"weight": 100,
			"availability": {"type": "encounter_stat_check", "stat": "pressure", "op": "<", "value": 10}
		},
		{
			"action_id": "weighted",
			"weight": 1,
			"weight_modifiers": [
				{
					"if": {"type": "encounter_stat_check", "stat": "pressure", "op": ">=", "value": 50},
					"weight": 10
				}
			]
		}
	]

	var selected := ENCOUNTER_RUNTIME.pick_weighted_action(actions, context, rng)

	assert_eq(str(selected.get("action_id", "")), "weighted")
	assert_eq(ENCOUNTER_RUNTIME.resolve_weight(actions[1], context), 10.0)


func test_encounter_stat_clamp_respects_meter_and_counter_kinds() -> void:
	var stat_defs := {
		"progress": {"min": 0, "max": 100},
		"round": {"kind": "counter"}
	}

	assert_eq(ENCOUNTER_RUNTIME.clamp_encounter_stat("progress", 125.0, stat_defs), 100.0)
	assert_eq(ENCOUNTER_RUNTIME.clamp_encounter_stat("progress", -5.0, stat_defs), 0.0)
	assert_eq(ENCOUNTER_RUNTIME.clamp_encounter_stat("round", 125.0, stat_defs), 125.0)


func _make_opponent(stats: Dictionary) -> EntityInstance:
	var template := {
		"entity_id": "base:runtime_opponent",
		"display_name": "Runtime Opponent",
		"stats": stats,
		"inventory": [],
	}
	return EntityInstance.from_template(template)
