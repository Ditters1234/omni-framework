extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	GameState.active_status_effects.clear()
	GameEvents.clear_event_history()
	DataManager.status_effects["base:test_focus"] = {
		"status_effect_id": "base:test_focus",
		"display_name": "Test Focus",
		"duration": 3,
		"max_stacks": 2,
		"stack_mode": "stack",
		"stat_modifiers": {"power": 2},
	}
	DataManager.status_effects["base:test_regen"] = {
		"status_effect_id": "base:test_regen",
		"display_name": "Test Regen",
		"duration": 2,
		"tick_interval": 1,
		"on_tick": [
			{"type": "modify_stat", "stat": "health", "delta": 2}
		],
		"on_expire": [
			{"type": "set_flag", "flag_id": "regen_expired", "value": true}
		],
	}


func test_status_effect_stat_modifiers_stack_and_expire_on_ticks() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var before_power := player.effective_stat("power")

	var first_runtime_id := GameState.apply_status_effect("base:test_focus", "player")
	assert_false(first_runtime_id.is_empty())
	assert_eq(player.effective_stat("power"), before_power + 2.0)
	var second_runtime_id := GameState.apply_status_effect("base:test_focus", "player")
	assert_eq(second_runtime_id, first_runtime_id)
	assert_eq(player.effective_stat("power"), before_power + 4.0)

	TimeKeeper.advance_ticks(3)

	assert_eq(GameState.active_status_effects.size(), 0)
	assert_eq(player.effective_stat("power"), before_power)


func test_status_effect_tick_and_expire_actions_use_target_entity() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	player.set_stat("health", 10.0)

	var runtime_id := GameState.apply_status_effect("base:test_regen", "player")
	assert_false(runtime_id.is_empty())
	TimeKeeper.advance_tick()
	assert_eq(player.get_stat("health"), 12.0)
	TimeKeeper.advance_tick()

	assert_false(GameState.active_status_effects.has(runtime_id))
	assert_true(player.get_flag("regen_expired", false))


func test_action_dispatcher_applies_and_removes_status_effects() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	ActionDispatcher.dispatch({
		"type": "apply_status_effect",
		"status_effect_id": "base:test_focus",
		"entity_id": "player",
	})
	assert_eq(GameState.active_status_effects.size(), 1)
	ActionDispatcher.dispatch({
		"type": "remove_status_effect",
		"status_effect_id": "base:test_focus",
		"entity_id": "player",
	})
	assert_eq(GameState.active_status_effects.size(), 0)
