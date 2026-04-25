extends GutTest

const AI_CHAT_SERVICE := preload("res://systems/ai/ai_chat_service.gd")
const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"
const FIXTURE_PERSONA_ID := "base:fixture_vendor_persona"
const FIXTURE_FACTION_ID := "base:fixture_faction"
const FIXTURE_QUEST_ID := "base:fixture_job"


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	_seed_ai_chat_fixture()
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
	}))


func after_each() -> void:
	AIManager.clear_provider_script_overrides()
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
	}))
	await get_tree().process_frame


func test_build_system_prompt_resolves_known_fixture_tokens() -> void:
	TimeKeeper.advance_ticks(18)
	var service: AIChatService = AI_CHAT_SERVICE.new()

	assert_true(service.configure_for_entity(TEST_FIXTURE_WORLD.fixture_vendor_id()))

	var system_prompt := service.build_system_prompt()

	assert_true(system_prompt.contains("Fixture Vendor"))
	assert_true(system_prompt.contains("Fixture Field"))
	assert_true(system_prompt.contains("Fixture Faction"))
	assert_true(system_prompt.contains("Friendly"))
	assert_true(system_prompt.contains("Player"))
	assert_true(system_prompt.contains("power: 1"))
	assert_true(system_prompt.contains("Fix the Relay"))
	assert_true(system_prompt.contains("evening"))
	assert_true(system_prompt.contains("Repair contracts"))


func test_history_window_keeps_only_most_recent_turns() -> void:
	var service: AIChatService = AI_CHAT_SERVICE.new()

	assert_true(service.configure_for_entity(TEST_FIXTURE_WORLD.fixture_vendor_id(), 1))
	service.add_message(AIChatService.ROLE_USER, "First question")
	service.add_message(AIChatService.ROLE_ASSISTANT, "First answer")
	service.add_message(AIChatService.ROLE_USER, "Second question")
	service.add_message(AIChatService.ROLE_ASSISTANT, "Second answer")

	var history := service.get_history()

	assert_eq(history.size(), 2)
	assert_eq(str(history[0].get("content", "")), "Second question")
	assert_eq(str(history[1].get("content", "")), "Second answer")


func test_validate_response_uses_fallback_for_empty_and_character_breaking_text() -> void:
	var service: AIChatService = AI_CHAT_SERVICE.new()

	assert_true(service.configure_for_entity(TEST_FIXTURE_WORLD.fixture_vendor_id()))

	var empty_validation := service.validate_response("")
	assert_true(bool(empty_validation.get("used_fallback", false)))
	assert_eq(str(empty_validation.get("reason", "")), "empty_response")

	var character_break_validation := service.validate_response("As an AI language model, I cannot help with that.")
	assert_true(bool(character_break_validation.get("used_fallback", false)))
	assert_eq(str(character_break_validation.get("reason", "")), "character_break")


func test_validate_response_truncates_overlong_reply_and_deflects_forbidden_topics() -> void:
	var service: AIChatService = AI_CHAT_SERVICE.new()

	assert_true(service.configure_for_entity(TEST_FIXTURE_WORLD.fixture_vendor_id()))

	var long_validation := service.validate_response(
		"One. Two. Three. Four. Five."
	)
	assert_false(bool(long_validation.get("used_fallback", false)))
	assert_true(bool(long_validation.get("truncated", false)))
	assert_eq(str(long_validation.get("response", "")), "One. Two. Three. Four.")

	var forbidden_validation := service.validate_response("Let me tell you about my personal_history and why it matters.")
	assert_true(bool(forbidden_validation.get("used_fallback", false)))
	assert_eq(str(forbidden_validation.get("reason", "")), "forbidden_topic")
	assert_eq(str(forbidden_validation.get("response", "")), "Let's keep this on business.")


func test_send_message_async_builds_context_and_appends_history() -> void:
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: true,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
		APP_SETTINGS.AI_MODEL: "fake-model",
		"ready": true,
	}))
	var service: AIChatService = AI_CHAT_SERVICE.new()

	assert_true(service.configure_for_entity(TEST_FIXTURE_WORLD.fixture_vendor_id()))

	var result := await service.send_message_async("Status report?")

	assert_eq(str(result.get("response", "")), "fake response")
	assert_false(bool(result.get("used_fallback", true)))
	var history_value: Variant = result.get("history", [])
	assert_true(history_value is Array)
	var history: Array = history_value
	assert_eq(history.size(), 2)
	assert_eq(str(history[0].get("role", "")), AIChatService.ROLE_USER)
	assert_eq(str(history[0].get("content", "")), "Status report?")
	assert_eq(str(history[1].get("role", "")), AIChatService.ROLE_ASSISTANT)
	assert_eq(str(history[1].get("content", "")), "fake response")

	var manager_snapshot := AIManager.get_debug_snapshot()
	var provider_debug_value: Variant = manager_snapshot.get("provider_debug", {})
	assert_true(provider_debug_value is Dictionary)
	var provider_debug: Dictionary = provider_debug_value
	var last_context_value: Variant = provider_debug.get("last_context", {})
	assert_true(last_context_value is Dictionary)
	var last_context: Dictionary = last_context_value
	assert_true(str(last_context.get("system_prompt", "")).contains("Fixture Vendor"))
	var last_history_value: Variant = last_context.get("history", [])
	assert_true(last_history_value is Array)
	var last_history: Array = last_history_value
	assert_eq(last_history.size(), 0)
	assert_eq(str(last_context.get("prompt", "")), "Status report?")


func _seed_ai_chat_fixture() -> void:
	DataManager.ai_personas[FIXTURE_PERSONA_ID] = {
		"persona_id": FIXTURE_PERSONA_ID,
		"display_name": "Fixture Vendor Persona",
		"system_prompt_template": "You are {display_name}, {description}. You operate from {location_name} for {faction_name}. The player's standing is {reputation_tier}. Player: {player_name}. Stats: {player_stats}. Time: {time_of_day}. Active work: {active_quests}. {knowledge_block}",
		"personality_traits": ["steady", "professional"],
		"speech_style": "Short status updates.",
		"knowledge_scope": ["fixture_faction", "fixture_field", "repair_contracts"],
		"forbidden_topics": ["personal_history"],
		"response_constraints": {
			"max_sentences": 2,
			"tone": "direct",
			"always_in_character": true,
		},
		"fallback_lines": [
			"I don't have anything useful to add to that.",
			"Let's keep this on business.",
			"Ask me something I can act on.",
		],
	}
	var fixture_vendor := DataManager.get_entity(TEST_FIXTURE_WORLD.fixture_vendor_id())
	fixture_vendor["ai_persona_id"] = FIXTURE_PERSONA_ID
	fixture_vendor["description"] = "A reliable contact who handles repair contracts."
	DataManager.entities[TEST_FIXTURE_WORLD.fixture_vendor_id()] = fixture_vendor
	DataManager.factions[FIXTURE_FACTION_ID] = {
		"faction_id": FIXTURE_FACTION_ID,
		"display_name": "Fixture Faction",
		"description": "Keeps the repair network supplied.",
		"territory": [TEST_FIXTURE_WORLD.connected_location_id()],
		"reputation_thresholds": {
			"friendly": 25,
			"neutral": 0,
			"hostile": -25,
		},
	}
	var player := GameState.player as EntityInstance
	if player != null:
		player.reputation[FIXTURE_FACTION_ID] = 25.0
	DataManager.quests[FIXTURE_QUEST_ID] = {
		"quest_id": FIXTURE_QUEST_ID,
		"display_name": "Fix the Relay",
		"description": "Repair contracts are stacking up.",
		"stages": [
			{
				"title": "Awaiting Parts",
				"description": "Hold until the repair job is explicitly advanced.",
				"objectives": [
					{
						"type": "has_flag",
						"flag_id": "fixture_job_complete",
						"value": true,
					}
				]
			}
		],
	}
	GameState.active_quests[FIXTURE_QUEST_ID] = {
		"quest_id": FIXTURE_QUEST_ID,
		"stage_index": 0,
	}


func _make_settings(ai_overrides: Dictionary) -> Dictionary:
	var settings := APP_SETTINGS.get_default_settings()
	var ai_settings := APP_SETTINGS.get_ai_settings(settings)
	for key_value in ai_overrides.keys():
		ai_settings[str(key_value)] = ai_overrides.get(key_value, null)
	settings[APP_SETTINGS.SECTION_AI] = ai_settings
	return settings
