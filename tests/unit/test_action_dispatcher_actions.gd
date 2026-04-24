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
	assert_false(GameState.entity_instances.has("base:fixture_vendor"))
	# fixture_vendor is in DataManager.entities but not instantiated in data-only fixture
	DataManager.entities["base:spawn_target"] = {
		"entity_id": "base:spawn_target",
		"display_name": "Spawned NPC",
		"description": "Created by spawn action.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"currencies": {},
		"stats": {},
	}
	ActionDispatcher.dispatch({"type": "spawn_entity", "template_id": "base:spawn_target"})
	assert_true(GameState.entity_instances.has("base:spawn_target"))


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
