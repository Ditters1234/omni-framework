extends GutTest

const WEIGHTED_CHOICE_SERVICE := preload("res://systems/weighted_choice_service.gd")


func before_each() -> void:
	GameState.reset()
	GameState.flags.clear()


func test_filter_available_requires_all_conditions_to_pass() -> void:
	GameState.set_flag("base:first", true)
	var entries := [
		{
			"outcome_id": "visible",
			"conditions": [
				{"type": "has_flag", "flag_id": "base:first"},
			],
		},
		{
			"outcome_id": "hidden",
			"conditions": [
				{"type": "has_flag", "flag_id": "base:first"},
				{"type": "has_flag", "flag_id": "base:second"},
			],
		},
	]

	var available := WEIGHTED_CHOICE_SERVICE.filter_available(entries)

	assert_eq(available.size(), 1)
	assert_eq(str(available[0].get("outcome_id", "")), "visible")


func test_pick_weighted_returns_first_available_when_weights_are_zero() -> void:
	var entries := [
		{"outcome_id": "first", "weight": 0.0},
		{"outcome_id": "second", "weight": 0.0},
	]

	var picked := WEIGHTED_CHOICE_SERVICE.pick_weighted(entries)

	assert_eq(str(picked.get("outcome_id", "")), "first")


func test_pick_weighted_uses_rng_for_positive_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var entries := [
		{"outcome_id": "low", "weight": 0.0},
		{"outcome_id": "high", "weight": 10.0},
	]

	var picked := WEIGHTED_CHOICE_SERVICE.pick_weighted(entries, {}, rng)

	assert_eq(str(picked.get("outcome_id", "")), "high")
