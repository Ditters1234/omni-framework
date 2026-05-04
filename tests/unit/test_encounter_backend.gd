extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")
const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"


func before_each() -> void:
	watch_signals(GameEvents)
	ScriptHookService.reset_world_gen_state()
	AIManager.clear_provider_script_overrides()
	_configure_saved_ai_settings(false)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
		}
	})
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	_seed_encounter_fixture()


func after_each() -> void:
	AIManager.clear_provider_script_overrides()
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
		}
	})
	ScriptHookService.reset_world_gen_state()
	await get_tree().process_frame


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

	var navigation := backend.select_action("finish")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_true(navigation.is_empty())
	assert_eq(backend.get_resolved_outcome_id(), "victory")
	var view_model := backend.build_view_model()
	assert_true(bool(view_model.get("resolved", false)))
	assert_eq(str(view_model.get("resolved_screen_text", "")), "Won.")
	assert_true(_reward_line_exists(view_model, "Credits +5"))


func test_encounter_completion_notifies_and_records_reward_summary() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("finish")

	assert_signal_emitted(GameEvents, "ui_notification_requested")
	var notification_params: Array = get_signal_parameters(GameEvents, "ui_notification_requested")
	assert_eq(str(notification_params[0]), "Encounter complete: Fixture Encounter | Rewards: Credits +5")
	assert_eq(str(notification_params[1]), OmniConstants.NOTIFICATION_LEVEL_INFO)
	assert_false(GameState.event_history.is_empty())
	if not GameState.event_history.is_empty():
		var latest: Dictionary = GameState.event_history.back()
		assert_eq(str(latest.get("event_type", "")), "encounter_resolved")
		var payload_value: Variant = latest.get("payload", {})
		assert_true(payload_value is Dictionary)
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			assert_eq(str(payload.get("encounter_id", "")), "base:test_encounter")
			assert_eq(str(payload.get("outcome_id", "")), "victory")
			assert_eq(str(payload.get("reward_summary", "")), "Credits +5")


func test_ai_encounter_log_flavor_updates_log_without_changing_mechanics() -> void:
	_configure_saved_ai_settings(true)
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "The test opponent buckles as the finishing blow lands.",
		}
	})
	ScriptHookService.invalidate_world_gen_settings_cache()
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("finish")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(backend.get_resolved_outcome_id(), "victory")
	assert_signal_emitted(GameEvents, "event_narrated")
	var view_model := backend.build_view_model()
	assert_true(_log_line_exists(view_model, "The test opponent buckles as the finishing blow lands."))
	assert_true(_reward_line_exists(view_model, "Credits +5"))


func test_ai_encounter_log_flavor_holds_fallback_and_serializes_requests() -> void:
	_configure_saved_ai_settings(true)
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "A generated action line arrives.",
			"delay_frames": 3,
		}
	})
	ScriptHookService.invalidate_world_gen_settings_cache()
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("double_log")
	var pending_view := backend.build_view_model()
	assert_true(bool(pending_view.get("resolving_action", false)))
	assert_true(_log_line_exists(pending_view, "Resolving action..."))
	assert_false(_log_line_exists(pending_view, "First authored fallback."))
	assert_false(_log_line_exists(pending_view, "Second authored fallback."))
	assert_false(_action_available(pending_view, "wait"))

	backend.select_action("wait")
	var blocked_view := backend.build_view_model()
	assert_true(bool(blocked_view.get("resolving_action", false)))
	assert_eq(str(blocked_view.get("status_text", "")), "Action is still resolving.")
	assert_false(_log_line_exists(blocked_view, "The test opponent lashes out."))

	var saw_global_queue := false
	var provider_request_count := 0
	var provider_max_concurrent_requests := 0
	for _frame_index in range(8):
		await get_tree().process_frame
		var queue_snapshot := AIManager.get_debug_snapshot()
		if int(queue_snapshot.get("queued_request_count", 0)) > 0 or bool(queue_snapshot.get("queue_processing", false)):
			saw_global_queue = true
		var provider_debug_value: Variant = queue_snapshot.get("provider_debug", {})
		if provider_debug_value is Dictionary:
			var provider_debug: Dictionary = provider_debug_value
			provider_request_count = int(provider_debug.get("request_count", 0))
			provider_max_concurrent_requests = int(provider_debug.get("max_concurrent_requests", 0))
	assert_true(saw_global_queue)
	assert_true(provider_request_count >= 1)
	assert_eq(provider_max_concurrent_requests, 1)

	for _frame_index in range(10):
		await get_tree().process_frame
	var resolved_view := backend.build_view_model()
	assert_false(bool(resolved_view.get("resolving_action", true)))
	assert_true(_action_available(resolved_view, "wait"))
	assert_true(_log_line_exists(resolved_view, "A generated action line arrives."))


func test_ai_encounter_log_flavor_shows_fallback_on_error() -> void:
	_configure_saved_ai_settings(true)
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"simulate_error": true,
			"error_text": "FakeAIProvider: scripted log failure.",
		}
	})
	ScriptHookService.invalidate_world_gen_settings_cache()
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("single_log")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_push_warning("FakeAIProvider: scripted log failure.")
	var view_model := backend.build_view_model()
	assert_true(_log_line_exists(view_model, "Single authored fallback."))


func test_resolve_effect_stops_later_effects() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("resolve_then_damage")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before)
	assert_eq(backend.get_resolved_outcome_id(), "fled")


func test_continue_navigates_after_resolution_review() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	var resolution_navigation := backend.select_action("finish")
	var continue_navigation := backend.continue_after_resolution()

	assert_true(resolution_navigation.is_empty())
	assert_eq(str(continue_navigation.get("type", "")), "pop")


func test_cancel_outcome_waits_for_resolution_review() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	var resolution_navigation := backend.cancel()
	var continue_navigation := backend.continue_after_resolution()

	assert_true(resolution_navigation.is_empty())
	assert_eq(backend.get_resolved_outcome_id(), "fled")
	assert_eq(str(continue_navigation.get("type", "")), "pop")


func test_encounter_tags_gate_followup_actions_and_expire() -> void:
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:test_encounter"})

	backend.select_action("guard")
	var guarded_view := backend.build_view_model()
	assert_true(_action_available(guarded_view, "guarded_finish"))

	backend.select_action("guarded_finish")

	assert_eq(backend.get_resolved_outcome_id(), "victory")


func test_max_rounds_resolves_after_opponent_action() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var health_before := player.get_stat("health")
	var max_round_encounter := DataManager.get_encounter("base:test_encounter")
	var resolution_value: Variant = max_round_encounter.get("resolution", {})
	assert_true(resolution_value is Dictionary)
	if not resolution_value is Dictionary:
		return
	var resolution: Dictionary = resolution_value
	resolution["max_rounds"] = 1
	resolution["max_rounds_outcome"] = "timeout"
	max_round_encounter["resolution"] = resolution
	DataManager.encounters["base:max_round_encounter"] = max_round_encounter
	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": "base:max_round_encounter"})

	backend.select_action("wait")

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_stat("health"), health_before - 5.0)
	assert_eq(backend.get_resolved_outcome_id(), "timeout")


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
	DataManager.ai_templates["base:encounter_log_flavor"] = {
		"template_id": "base:encounter_log_flavor",
		"purpose": "encounter_log_flavor",
		"prompt_template": "Rewrite {fallback_text}. Changes: {stat_delta_summary}.",
		"fallback": "{fallback_text}",
	}
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
						{"effect": "modify_stat", "target": "opponent", "stat": "health", "base_delta": -100},
						{"effect": "log", "text": "{user_name} finishes {target_name}."}
					],
				},
				{
					"action_id": "resolve_then_damage",
					"label": "Resolve Then Damage",
					"on_success": [
						{"effect": "resolve", "outcome_id": "fled"},
						{"effect": "modify_stat", "target": "player", "stat": "health", "base_delta": -10}
					],
				},
				{
					"action_id": "guard",
					"label": "Guard",
					"on_success": [
						{"effect": "apply_tag", "target": "player", "tag": "guarded", "duration_rounds": 2}
					],
				},
				{
					"action_id": "guarded_finish",
					"label": "Guarded Finish",
					"availability": {"type": "has_encounter_tag", "role": "player", "tag": "guarded"},
					"on_success": [
						{"effect": "modify_stat", "target": "opponent", "stat": "health", "base_delta": -100}
					],
				},
				{
					"action_id": "double_log",
					"label": "Double Log",
					"on_success": [
						{"effect": "log", "text": "First authored fallback."},
						{"effect": "log", "text": "Second authored fallback."}
					],
				},
				{
					"action_id": "single_log",
					"label": "Single Log",
					"on_success": [
						{"effect": "log", "text": "Single authored fallback."}
					],
				},
				{
					"action_id": "wait",
					"label": "Wait",
					"on_success": [
						{"effect": "log", "text": "Waiting."}
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
			"cancel_outcome": "fled",
			"outcomes": [
				{
					"outcome_id": "victory",
					"conditions": {"type": "stat_check", "entity_id": "encounter:opponent", "stat": "health", "op": "<=", "value": 0},
					"screen_text": "Won.",
					"reward": {"credits": 5},
					"pop_on_resolve": true,
				},
				{
					"outcome_id": "timeout",
					"trigger": "manual",
					"screen_text": "Timed out.",
					"pop_on_resolve": true,
				},
				{
					"outcome_id": "fled",
					"trigger": "manual",
					"screen_text": "Fled.",
					"pop_on_resolve": true,
				},
			],
		},
	}


func _action_available(view_model: Dictionary, action_id: String) -> bool:
	var actions_value: Variant = view_model.get("actions", [])
	if not actions_value is Array:
		return false
	var actions: Array = actions_value
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		if str(action.get("action_id", "")) == action_id:
			return bool(action.get("available", false))
	return false


func _reward_line_exists(view_model: Dictionary, expected_line: String) -> bool:
	var reward_lines_value: Variant = view_model.get("reward_lines", [])
	if not reward_lines_value is Array:
		return false
	var reward_lines: Array = reward_lines_value
	for reward_line_value in reward_lines:
		if str(reward_line_value) == expected_line:
			return true
	return false


func _log_line_exists(view_model: Dictionary, expected_line: String) -> bool:
	var log_value: Variant = view_model.get("log", [])
	if not log_value is Array:
		return false
	var log_entries: Array = log_value
	for entry_value in log_entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("text", "")) == expected_line:
			return true
	return false


func _configure_saved_ai_settings(enable_world_gen: bool) -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: enable_world_gen,
			APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE if enable_world_gen else APP_SETTINGS.AI_PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: enable_world_gen,
		}
	})
	assert_eq(save_error, OK)
