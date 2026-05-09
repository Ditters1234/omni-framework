extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	GameEvents.clear_event_history()


func test_lifecycle_rule_enters_and_exits_state_from_configured_stat() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.config["entity_lifecycle"] = {
		"rules": [
			{
				"rule_id": "base:test_incapacitated",
				"display_name": "Incapacitated",
				"stat": "health",
				"state_flag": "base:test_incapacitated",
				"condition": {
					"type": "stat_check",
					"entity_id": "context:entity",
					"stat": "health",
					"op": "<=",
					"value": 0,
				},
				"notification": "{entity_name} is incapacitated.",
				"clear_when_condition_false": true,
				"exit_notification": "{entity_name} recovered.",
			}
		]
	}
	watch_signals(GameEvents)

	player.set_stat("health", 0.0)

	assert_eq(player.get_flag("base:test_incapacitated", false), true)
	assert_signal_emitted(GameEvents, "entity_lifecycle_state_changed")
	assert_signal_emitted(GameEvents, "ui_notification_requested")
	assert_eq(
		get_signal_parameters(GameEvents, "ui_notification_requested"),
		["Player is incapacitated.", "warning"]
	)

	player.set_stat("health", 5.0)

	assert_eq(player.get_flag("base:test_incapacitated", true), false)
	var notifications := GameEvents.get_event_history(0, "ui", "ui_notification_requested")
	assert_eq(notifications.size(), 2)
	assert_eq(str(notifications[0].get("signal_name", "")), "ui_notification_requested")


func test_lifecycle_rule_uses_data_authored_non_health_stat() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	player.stats["resolve"] = 5.0
	DataManager.config["entity_lifecycle"] = {
		"rules": [
			{
				"rule_id": "base:test_resolve_broken",
				"stat": "resolve",
				"state_flag": "base:resolve_broken",
				"condition": {
					"type": "stat_check",
					"entity_id": "context:entity",
					"stat": "resolve",
					"op": "<=",
					"value": 0,
				},
				"actions": [
					{"type": "set_flag", "flag_id": "base:resolve_action", "value": true}
				],
			}
		]
	}

	player.set_stat("resolve", 0.0)

	assert_eq(player.get_flag("base:resolve_broken", false), true)
	assert_eq(player.get_flag("base:resolve_action", false), true)


func test_player_lifecycle_rule_can_emit_game_over() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.config["entity_lifecycle"] = {
		"rules": [
			{
				"rule_id": "base:test_game_over",
				"stat": "health",
				"state_flag": "base:test_game_over",
				"condition": {
					"type": "stat_check",
					"entity_id": "context:entity",
					"stat": "health",
					"op": "<=",
					"value": 0,
				},
				"game_over_on_player": true,
			}
		]
	}
	watch_signals(GameEvents)

	player.set_stat("health", 0.0)

	assert_signal_emitted(GameEvents, "game_over")
