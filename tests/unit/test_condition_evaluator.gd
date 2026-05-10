extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)


# ---------------------------------------------------------------------------
# Typed conditions
# ---------------------------------------------------------------------------

func test_has_flag_global_returns_true_when_flag_is_set() -> void:
	GameState.set_flag("tutorial_done", true)
	assert_true(ConditionEvaluator.evaluate({"type": "has_flag", "flag_id": "tutorial_done"}))
	assert_false(ConditionEvaluator.evaluate({"type": "has_flag", "flag_id": "never_set"}))


func test_has_flag_entity_checks_entity_flags() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	player.set_flag("met_npc", true)
	assert_true(ConditionEvaluator.evaluate({
		"type": "has_flag",
		"entity_id": "player",
		"flag_id": "met_npc",
		"value": true,
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "has_flag",
		"entity_id": "player",
		"flag_id": "met_npc",
		"value": false,
	}))


func test_stat_check_evaluates_effective_stat() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	# Fixture player has strength: 2
	assert_true(ConditionEvaluator.evaluate({
		"type": "stat_check",
		"stat": "strength",
		"op": ">=",
		"value": 2,
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "stat_check",
		"stat": "strength",
		"op": ">",
		"value": 2,
	}))
	assert_true(ConditionEvaluator.evaluate({
		"type": "stat_check",
		"stat": "strength",
		"op": "==",
		"value": 2,
	}))


func test_stat_check_can_compare_against_another_stat() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	player.set_stat("health", 40.0)
	player.set_stat("health_max", 50.0)

	assert_true(ConditionEvaluator.evaluate({
		"type": "stat_check",
		"entity_id": "context:entity",
		"stat": "health",
		"op": "<",
		"value_stat": "health_max",
	}, {"entity": player}))


func test_has_currency_checks_player_balance() -> void:
	# Fixture player has credits: 400
	assert_true(ConditionEvaluator.evaluate({
		"type": "has_currency",
		"currency_id": "credits",
		"amount": 400,
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "has_currency",
		"currency_id": "credits",
		"amount": 401,
	}))


func test_has_part_checks_inventory_and_equipped() -> void:
	# Fixture player has base:human_head equipped
	assert_true(ConditionEvaluator.evaluate({
		"type": "has_part",
		"template_id": "base:human_head",
		"count": 1,
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "has_part",
		"template_id": "base:nonexistent_part",
		"count": 1,
	}))


func test_has_item_tag_checks_for_tagged_parts() -> void:
	# Fixture player has a part with "head" tag equipped
	assert_true(ConditionEvaluator.evaluate({
		"type": "has_item_tag",
		"tag": "head",
		"count": 1,
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "has_item_tag",
		"tag": "weapon",
		"count": 1,
	}))


func test_reach_location_checks_current_player_location() -> void:
	assert_true(ConditionEvaluator.evaluate({
		"type": "reach_location",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "reach_location",
		"location_id": "base:nonexistent_location",
	}))


func test_quest_complete_checks_completed_quests_list() -> void:
	assert_false(ConditionEvaluator.evaluate({
		"type": "quest_complete",
		"quest_id": "base:test_quest",
	}))
	GameState.completed_quests.append("base:test_quest")
	assert_true(ConditionEvaluator.evaluate({
		"type": "quest_complete",
		"quest_id": "base:test_quest",
	}))


func test_reputation_threshold_checks_faction_standing() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	player.add_reputation("base:test_faction", 50.0)
	assert_true(ConditionEvaluator.evaluate({
		"type": "reputation_threshold",
		"faction_id": "base:test_faction",
		"threshold": 25.0,
		"comparison": ">=",
	}))
	assert_false(ConditionEvaluator.evaluate({
		"type": "reputation_threshold",
		"faction_id": "base:test_faction",
		"threshold": 100.0,
		"comparison": ">=",
	}))


func test_activity_history_conditions_use_game_state_history() -> void:
	DataManager.activities["base:study"] = {
		"activity_id": "base:study",
		"display_name": "Study",
		"category": "learning",
		"duration_ticks": 1,
	}
	DataManager.activities["base:train"] = {
		"activity_id": "base:train",
		"display_name": "Train",
		"category": "fitness",
		"duration_ticks": 1,
	}
	GameState.current_tick = 0
	GameState.current_day = 1
	GameState.record_activity_completed("base:study", {"outcome_id": "insight"})
	GameState.record_activity_completed("base:study")

	assert_true(ConditionEvaluator.evaluate({"type": "activity_completed", "activity_id": "base:study"}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_not_completed", "activity_id": "base:train"}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_count_at_least", "activity_id": "base:study", "count": 2}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_count_less_than", "activity_id": "base:train", "count": 1}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_completed_today", "activity_id": "base:study"}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_not_completed_today", "activity_id": "base:train"}))
	assert_true(ConditionEvaluator.evaluate({"type": "activity_category_count_at_least", "category": "learning", "count": 2}))
	assert_true(ConditionEvaluator.evaluate({"type": "last_activity_outcome_is", "activity_id": "base:study", "outcome_id": "insight"}))
	assert_false(ConditionEvaluator.evaluate({"type": "activity_count_at_least", "activity_id": "base:study", "count": 3}))


func test_time_conditions_use_time_model() -> void:
	DataManager.config["game"] = {"ticks_per_day": 10}
	DataManager.config["calendar"] = {
		"weekdays": ["Mon", "Tue"],
		"months": [
			{"month_id": "spring", "display_name": "Spring", "days": 2, "tags": ["green"]},
			{"month_id": "winter", "display_name": "Winter", "days": 3, "tags": ["cold"]},
		],
		"starting_absolute_day": 1,
		"starting_year": 1,
	}
	GameState.current_tick = 12
	GameState.current_day = 2
	TimeKeeper.sync_from_game_state()

	assert_true(ConditionEvaluator.evaluate({"type": "weekday_is", "weekday": "Tue"}))
	assert_true(ConditionEvaluator.evaluate({"type": "weekday_in", "weekdays": ["Sun", "Tue"]}))
	assert_true(ConditionEvaluator.evaluate({"type": "tick_after", "tick": 1}))
	assert_true(ConditionEvaluator.evaluate({"type": "tick_before", "tick": 3}))
	assert_true(ConditionEvaluator.evaluate({"type": "tick_between", "start": 1, "end": 3}))
	assert_true(ConditionEvaluator.evaluate({"type": "month_is", "month": "spring"}))
	assert_true(ConditionEvaluator.evaluate({"type": "month_in", "months": ["spring", "summer"]}))
	assert_true(ConditionEvaluator.evaluate({"type": "month_tag_is", "tag": "green"}))
	assert_true(ConditionEvaluator.evaluate({"type": "month_tag_in", "tags": ["red", "green"]}))
	assert_true(ConditionEvaluator.evaluate({"type": "day_of_month_is", "day": 2}))
	assert_true(ConditionEvaluator.evaluate({"type": "day_of_month_between", "start": 1, "end": 2}))
	assert_true(ConditionEvaluator.evaluate({"type": "absolute_day_after", "day": 1}))
	assert_true(ConditionEvaluator.evaluate({"type": "absolute_day_before", "day": 3}))
	assert_true(ConditionEvaluator.evaluate({"type": "absolute_tick_after", "tick": 11}))
	assert_true(ConditionEvaluator.evaluate({"type": "absolute_tick_before", "tick": 13}))
	assert_false(ConditionEvaluator.evaluate({"type": "weekday_is", "weekday": "Mon"}))


# ---------------------------------------------------------------------------
# Logic blocks
# ---------------------------------------------------------------------------

func test_and_block_requires_all_conditions_to_pass() -> void:
	GameState.set_flag("a", true)
	GameState.set_flag("b", true)
	assert_true(ConditionEvaluator.evaluate({
		"AND": [
			{"type": "has_flag", "flag_id": "a"},
			{"type": "has_flag", "flag_id": "b"},
		]
	}))
	assert_false(ConditionEvaluator.evaluate({
		"AND": [
			{"type": "has_flag", "flag_id": "a"},
			{"type": "has_flag", "flag_id": "missing"},
		]
	}))


func test_or_block_requires_any_condition_to_pass() -> void:
	GameState.set_flag("x", true)
	assert_true(ConditionEvaluator.evaluate({
		"OR": [
			{"type": "has_flag", "flag_id": "x"},
			{"type": "has_flag", "flag_id": "missing"},
		]
	}))
	assert_false(ConditionEvaluator.evaluate({
		"OR": [
			{"type": "has_flag", "flag_id": "nope"},
			{"type": "has_flag", "flag_id": "missing"},
		]
	}))


func test_not_block_inverts_the_inner_condition() -> void:
	assert_true(ConditionEvaluator.evaluate({
		"NOT": {"type": "has_flag", "flag_id": "never_set"},
	}))
	GameState.set_flag("now_set", true)
	assert_false(ConditionEvaluator.evaluate({
		"NOT": {"type": "has_flag", "flag_id": "now_set"},
	}))


func test_empty_condition_is_vacuously_true() -> void:
	assert_true(ConditionEvaluator.evaluate({}))
