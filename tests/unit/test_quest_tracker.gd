extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const TEST_QUEST_ID := "base:fixture_quest"
const TEST_QUEST := {
	"quest_id": TEST_QUEST_ID,
	"display_name": "Fixture Quest",
	"description": "A quest used for testing.",
	"stages": [
		{
			"description": "Get a head.",
			"objectives": [
				{
					"type": "has_item_tag",
					"tag": "head",
					"count": 1,
				}
			]
		},
		{
			"description": "Go to the field.",
			"objectives": [
				{
					"type": "reach_location",
					"location_id": "base:field",
				}
			]
		}
	],
	"reward": {
		"credits": 50,
	},
	"repeatable": false,
}


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.quests[TEST_QUEST_ID] = TEST_QUEST.duplicate(true)


func test_start_quest_emits_signal_and_creates_active_instance() -> void:
	watch_signals(GameEvents)
	assert_true(GameState.start_quest(TEST_QUEST_ID))

	assert_signal_emitted(GameEvents, "quest_started")
	assert_eq(
		get_signal_parameters(GameEvents, "quest_started"),
		[TEST_QUEST_ID]
	)
	assert_true(GameState.active_quests.has(TEST_QUEST_ID))


func test_duplicate_start_is_rejected() -> void:
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	assert_false(GameState.start_quest(TEST_QUEST_ID))


func test_stage_auto_advances_when_objectives_are_already_met() -> void:
	# Fixture player already has a head equipped, so stage 0 should auto-advance
	watch_signals(GameEvents)
	assert_true(GameState.start_quest(TEST_QUEST_ID))

	assert_signal_emitted(GameEvents, "quest_stage_advanced")
	var quest_data: Variant = GameState.active_quests.get(TEST_QUEST_ID, {})
	assert_true(quest_data is Dictionary)
	if quest_data is Dictionary:
		var quest_dict: Dictionary = quest_data
		assert_eq(int(quest_dict.get("stage_index", -1)), 1)


func test_location_objective_completes_quest_on_travel() -> void:
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	watch_signals(GameEvents)

	# Travel to field — should complete stage 1 (reach_location) and finish the quest
	GameState.travel_to("base:field")

	# Allow quest tracker tick to process
	assert_signal_emitted(GameEvents, "quest_completed")
	assert_eq(
		get_signal_parameters(GameEvents, "quest_completed"),
		[TEST_QUEST_ID]
	)
	assert_true(TEST_QUEST_ID in GameState.completed_quests)
	assert_false(GameState.active_quests.has(TEST_QUEST_ID))


func test_quest_completion_applies_reward() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var credits_before := player.get_currency("credits")
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	GameState.travel_to("base:field")

	assert_eq(player.get_currency("credits"), credits_before + 50.0)


func test_quest_completion_notifies_with_reward_summary() -> void:
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	watch_signals(GameEvents)

	GameState.travel_to("base:field")

	assert_signal_emitted(GameEvents, "ui_notification_requested")
	var notification_params: Array = get_signal_parameters(GameEvents, "ui_notification_requested")
	assert_eq(str(notification_params[0]), "Quest complete: Fixture Quest | Rewards: Credits +50")
	assert_eq(str(notification_params[1]), OmniConstants.NOTIFICATION_LEVEL_INFO)
	var history := GameState.event_history
	assert_gt(history.size(), 0)
	var latest_value: Variant = history[history.size() - 1]
	assert_true(latest_value is Dictionary)
	if latest_value is Dictionary:
		var latest: Dictionary = latest_value
		assert_eq(str(latest.get("event_type", "")), "quest_completed")
		var payload_value: Variant = latest.get("payload", {})
		assert_true(payload_value is Dictionary)
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			assert_eq(str(payload.get("reward_summary", "")), "Credits +50")


func test_assigned_entity_can_complete_quest_objective_for_player_reward() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var robot_template := {
		"entity_id": "base:test_robot",
		"display_name": "Test Robot",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {},
		"inventory": [],
	}
	DataManager.entities["base:test_robot"] = robot_template.duplicate(true)
	var robot := EntityInstance.from_template(robot_template)
	GameState.commit_entity_instance(robot)
	DataManager.quests["base:robot_delivery"] = {
		"quest_id": "base:robot_delivery",
		"display_name": "Robot Delivery",
		"stages": [
			{
				"description": "Send the robot to the field.",
				"objectives": [
					{
						"type": "reach_location",
						"entity_id": "quest:assignee",
						"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
					}
				],
			}
		],
		"reward": {"credits": 25},
	}
	var credits_before := player.get_currency("credits")
	assert_true(GameState.start_quest("base:robot_delivery", {
		"assignee_entity_id": "base:test_robot",
		"reward_recipient_entity_id": "player",
	}))

	GameState.travel_to(TEST_FIXTURE_WORLD.connected_location_id())
	assert_true(GameState.active_quests.has("base:robot_delivery"))
	robot.location_id = TEST_FIXTURE_WORLD.connected_location_id()
	GameState.commit_entity_instance(robot)
	GameEvents.location_changed.emit(TEST_FIXTURE_WORLD.starting_location_id(), TEST_FIXTURE_WORLD.connected_location_id())

	assert_true("base:robot_delivery" in GameState.completed_quests)
	assert_false(GameState.active_quests.has("base:robot_delivery"))
	assert_eq(player.get_currency("credits"), credits_before + 25.0)


func test_activity_completion_signal_refreshes_active_quests() -> void:
	_seed_activity("base:study", "learning")
	_seed_activity_quest("base:activity_completion_quest", {
		"type": "activity_completed",
		"activity_id": "base:study",
	})
	assert_true(GameState.start_quest("base:activity_completion_quest"))
	assert_true(GameState.active_quests.has("base:activity_completion_quest"))
	watch_signals(GameEvents)

	GameState.record_activity_completed("base:study")
	GameEvents.activity_completed.emit({"activity_id": "base:study"})

	assert_signal_emitted(GameEvents, "quest_completed")
	assert_true("base:activity_completion_quest" in GameState.completed_quests)
	assert_false(GameState.active_quests.has("base:activity_completion_quest"))


func test_activity_count_objective_completes_from_history() -> void:
	_seed_activity("base:practice", "training")
	_seed_activity_quest("base:activity_count_quest", {
		"type": "activity_count_at_least",
		"activity_id": "base:practice",
		"count": 2,
	})
	assert_true(GameState.start_quest("base:activity_count_quest"))
	watch_signals(GameEvents)

	_record_activity_completion_event("base:practice")
	assert_signal_not_emitted(GameEvents, "quest_completed")
	assert_true(GameState.active_quests.has("base:activity_count_quest"))

	_record_activity_completion_event("base:practice")
	assert_signal_emitted(GameEvents, "quest_completed")
	assert_true("base:activity_count_quest" in GameState.completed_quests)


func test_activity_category_objective_completes_from_history() -> void:
	_seed_activity("base:stretch", "fitness")
	_seed_activity("base:sprint", "fitness")
	_seed_activity_quest("base:activity_category_quest", {
		"type": "activity_category_count_at_least",
		"category": "fitness",
		"count": 2,
	})
	assert_true(GameState.start_quest("base:activity_category_quest"))
	watch_signals(GameEvents)

	_record_activity_completion_event("base:stretch")
	assert_signal_not_emitted(GameEvents, "quest_completed")

	_record_activity_completion_event("base:sprint")
	assert_signal_emitted(GameEvents, "quest_completed")
	assert_true("base:activity_category_quest" in GameState.completed_quests)


func test_activity_outcome_objective_completes_from_history() -> void:
	_seed_activity("base:investigate", "research")
	_seed_activity_quest("base:activity_outcome_quest", {
		"type": "last_activity_outcome_is",
		"activity_id": "base:investigate",
		"outcome_id": "found_clue",
	})
	assert_true(GameState.start_quest("base:activity_outcome_quest"))
	watch_signals(GameEvents)

	_record_activity_completion_event("base:investigate", {"outcome_id": "dead_end"})
	assert_signal_not_emitted(GameEvents, "quest_completed")

	_record_activity_completion_event("base:investigate", {"outcome_id": "found_clue"})
	assert_signal_emitted(GameEvents, "quest_completed")
	assert_true("base:activity_outcome_quest" in GameState.completed_quests)


func test_activity_service_does_not_directly_advance_quest_stages() -> void:
	var file: FileAccess = FileAccess.open("res://systems/activity_service.gd", FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source := file.get_as_text()

	assert_false(source.contains("QuestTracker"))
	assert_false(source.contains("advance_quest"))
	assert_false(source.contains("complete_quest"))


func test_manual_complete_moves_quest_to_completed() -> void:
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	watch_signals(GameEvents)

	GameState.complete_quest(TEST_QUEST_ID)

	assert_signal_emitted(GameEvents, "quest_completed")
	assert_true(TEST_QUEST_ID in GameState.completed_quests)


func test_fail_quest_emits_signal_and_removes_from_active() -> void:
	assert_true(GameState.start_quest(TEST_QUEST_ID))
	watch_signals(GameEvents)

	GameState.fail_quest(TEST_QUEST_ID)

	assert_signal_emitted(GameEvents, "quest_failed")
	assert_false(GameState.active_quests.has(TEST_QUEST_ID))
	assert_false(TEST_QUEST_ID in GameState.completed_quests)


func _seed_activity(activity_id: String, category: String) -> void:
	DataManager.activities[activity_id] = {
		"activity_id": activity_id,
		"display_name": activity_id.get_file(),
		"category": category,
		"duration_ticks": 0,
	}


func _seed_activity_quest(quest_id: String, objective: Dictionary) -> void:
	DataManager.quests[quest_id] = {
		"quest_id": quest_id,
		"display_name": quest_id.get_file(),
		"stages": [
			{
				"description": "Complete activity objective.",
				"objectives": [
					objective.duplicate(true),
				],
			}
		],
		"reward": {},
	}


func _record_activity_completion_event(activity_id: String, payload: Dictionary = {}) -> void:
	var completion_payload := payload.duplicate(true)
	completion_payload["activity_id"] = activity_id
	GameState.record_activity_completed(activity_id, completion_payload)
	GameEvents.activity_completed.emit(completion_payload)
