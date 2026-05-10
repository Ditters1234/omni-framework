extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)


# ---------------------------------------------------------------------------
# Currency actions
# ---------------------------------------------------------------------------

func test_give_currency_adds_to_player() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var before := player.get_currency("credits")
	ActionDispatcher.dispatch({"type": "give_currency", "currency_id": "credits", "amount": 100})
	assert_eq(player.get_currency("credits"), before + 100.0)


func test_take_currency_subtracts_from_player() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var before := player.get_currency("credits")
	ActionDispatcher.dispatch({"type": "take_currency", "currency_id": "credits", "amount": 50})
	assert_eq(player.get_currency("credits"), before - 50.0)


# ---------------------------------------------------------------------------
# Part actions
# ---------------------------------------------------------------------------

func test_give_part_adds_to_player_inventory() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var count_before := player.inventory.size()
	watch_signals(GameEvents)
	ActionDispatcher.dispatch({"type": "give_part", "part_id": "base:body_arm_standard"})
	assert_eq(player.inventory.size(), count_before + 1)
	assert_signal_emitted(GameEvents, "part_acquired")


func test_remove_part_by_template_removes_one_from_inventory() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	# Give a part first, then remove it
	ActionDispatcher.dispatch({"type": "give_part", "part_id": "base:body_arm_standard"})
	var count_after_give := player.inventory.size()
	watch_signals(GameEvents)
	ActionDispatcher.dispatch({"type": "remove_part", "part_id": "base:body_arm_standard"})
	assert_eq(player.inventory.size(), count_after_give - 1)
	assert_signal_emitted(GameEvents, "part_removed")


# ---------------------------------------------------------------------------
# Stat + flag actions
# ---------------------------------------------------------------------------

func test_modify_stat_changes_player_stat() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var before := player.get_stat("strength")
	ActionDispatcher.dispatch({"type": "modify_stat", "stat": "strength", "delta": 3})
	assert_eq(player.get_stat("strength"), before + 3.0)


func test_set_flag_global_and_entity() -> void:
	ActionDispatcher.dispatch({"type": "set_flag", "flag_id": "global_flag", "value": true})
	assert_true(GameState.has_flag("global_flag"))

	ActionDispatcher.dispatch({
		"type": "set_flag",
		"entity_id": "player",
		"flag_id": "player_flag",
		"value": 42,
	})
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player != null:
		assert_eq(player.get_flag("player_flag", null), 42)


# ---------------------------------------------------------------------------
# Navigation actions
# ---------------------------------------------------------------------------

func test_travel_changes_player_location() -> void:
	ActionDispatcher.dispatch({"type": "travel", "location_id": TEST_FIXTURE_WORLD.connected_location_id()})
	assert_eq(GameState.current_location_id, TEST_FIXTURE_WORLD.connected_location_id())


func test_unlock_location_adds_to_discovered() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	assert_false(player.has_discovered_location("base:secret"))
	ActionDispatcher.dispatch({"type": "unlock_location", "location_id": "base:secret"})
	assert_true(player.has_discovered_location("base:secret"))


# ---------------------------------------------------------------------------
# Quest + task actions
# ---------------------------------------------------------------------------

func test_start_quest_action_begins_quest() -> void:
	DataManager.quests["base:action_quest"] = {
		"quest_id": "base:action_quest",
		"display_name": "Action Quest",
		"description": "Started by dispatcher.",
		"stages": [],
		"reward": {},
		"repeatable": false,
	}
	watch_signals(GameEvents)
	ActionDispatcher.dispatch({"type": "start_quest", "quest_id": "base:action_quest"})
	assert_signal_emitted(GameEvents, "quest_started")


func test_start_task_action_forwards_duration_and_completion_actions() -> void:
	DataManager.status_effects["base:action_recovery"] = {
		"status_effect_id": "base:action_recovery",
		"display_name": "Action Recovery",
		"duration": 2
	}
	DataManager.tasks["base:action_rest"] = {
		"template_id": "base:action_rest",
		"display_name": "Action Rest",
		"type": "WAIT",
		"duration": 5,
		"repeatable": true,
		"completion_actions": [
			{"type": "apply_status_effect", "status_effect_id": "base:action_recovery"}
		]
	}

	ActionDispatcher.dispatch({
		"type": "start_task",
		"task_template_id": "base:action_rest",
		"duration": 1,
		"allow_duplicate": true
	})
	assert_eq(GameState.active_tasks.size(), 1)
	TimeKeeper.advance_tick()

	assert_eq(GameState.active_tasks.size(), 0)
	assert_eq(GameState.active_status_effects.size(), 1)


func test_unlock_achievement_action_unlocks() -> void:
	DataManager.achievements["base:action_ach"] = {
		"achievement_id": "base:action_ach",
		"display_name": "Action Achievement",
		"description": "Unlocked by dispatcher.",
		"stat_name": "unused",
		"requirement": 999,
	}
	watch_signals(GameEvents)
	ActionDispatcher.dispatch({"type": "unlock_achievement", "achievement_id": "base:action_ach"})
	assert_signal_emitted(GameEvents, "achievement_unlocked")
	assert_true("base:action_ach" in GameState.unlocked_achievements)


# ---------------------------------------------------------------------------
# Spawn entity
# ---------------------------------------------------------------------------

func test_spawn_entity_creates_runtime_instance() -> void:
	var spawn_id := "base:spawned_npc_%d" % randi()
	DataManager.entities[spawn_id] = {
		"entity_id": spawn_id,
		"display_name": "Spawned NPC",
		"description": "Created by spawn action.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"currencies": {},
		"stats": {},
	}
	assert_false(GameState.entity_instances.has(spawn_id))
	ActionDispatcher.dispatch({"type": "spawn_entity", "template_id": spawn_id})
	assert_true(GameState.entity_instances.has(spawn_id))


# ---------------------------------------------------------------------------
# Reward service
# ---------------------------------------------------------------------------

func test_reward_action_delegates_to_reward_service() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var before := player.get_currency("credits")
	ActionDispatcher.dispatch({
		"type": "reward",
		"reward": {
			"credits": 75,
		},
	})
	assert_eq(player.get_currency("credits"), before + 75.0)


# ---------------------------------------------------------------------------
# Time and event actions
# ---------------------------------------------------------------------------

func test_advance_time_action_advances_ticks_and_clamps_negative_values() -> void:
	_use_ten_tick_days()
	GameState.current_tick = 0
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()

	ActionDispatcher.dispatch({"type": "advance_time", "ticks": 3})
	ActionDispatcher.dispatch({"type": "advance_time", "ticks": -4})

	assert_eq(GameState.current_tick, 3)


func test_advance_to_time_action_rolls_forward_without_rewinding() -> void:
	_use_ten_tick_days()
	GameState.current_tick = 2
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()

	ActionDispatcher.dispatch({"type": "advance_to_time", "day_offset": 0, "tick_of_day": 5})
	assert_eq(GameState.current_tick, 5)

	ActionDispatcher.dispatch({"type": "advance_to_time", "day_offset": 0, "tick_of_day": 5})
	assert_eq(GameState.current_tick, 15)


func test_advance_to_next_weekday_action_uses_configured_weekdays() -> void:
	_use_ten_tick_days()
	DataManager.config["calendar"] = {
		"weekdays": ["Mon", "Tue", "Wed"],
		"starting_absolute_day": 1,
	}
	GameState.current_tick = 2
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()

	ActionDispatcher.dispatch({"type": "advance_to_next_weekday", "weekday": "Tue", "tick_of_day": 4})

	assert_eq(GameState.current_tick, 14)


func test_record_event_action_routes_through_game_state() -> void:
	ActionDispatcher.dispatch({
		"type": "record_event",
		"event_type": "action_test_event",
		"payload": {"value": 42},
	})

	assert_eq(GameState.event_history.size(), 1)
	if GameState.event_history[0] is Dictionary:
		var event_entry: Dictionary = GameState.event_history[0]
		assert_eq(str(event_entry.get("event_type", "")), "action_test_event")
		var payload_value: Variant = event_entry.get("payload", {})
		assert_true(payload_value is Dictionary)
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			assert_eq(int(payload.get("value", 0)), 42)


func _use_ten_tick_days() -> void:
	DataManager.config["game"] = {"ticks_per_day": 10}
