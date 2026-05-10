extends GutTest

const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"
const ACTIVITY_FLAVOR_HOOK_PATH := "res://mods/base/scripts/ai_activity_flavor_hook.gd"
const ACTIVITY_LIFECYCLE_HOOK_PATH := "res://tests/fixtures/hooks/test_activity_lifecycle_hook.gd"
const ACTIVITY_ID := "base:activity_ai_fixture"
const LIFECYCLE_ACTIVITY_ID := "base:activity_lifecycle_fixture"


func before_each() -> void:
	GameEvents.clear_event_history()
	ScriptHookService.reset_world_gen_state()
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	_configure_saved_ai_settings(false)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
		}
	})
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.activities.clear()
	_seed_activity_ai_fixture_data()


func after_each() -> void:
	AIManager.clear_provider_script_overrides()
	_configure_saved_ai_settings(false)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
		}
	})
	ScriptHookService.reset_world_gen_state()
	GameEvents.clear_event_history()
	await get_tree().process_frame


func test_activity_flavor_noops_when_ai_is_disabled() -> void:
	watch_signals(GameEvents)

	var activity := DataManager.get_activity(ACTIVITY_ID)
	var first_result := ScriptHookService.request_activity_flavor(activity)
	await get_tree().process_frame
	await get_tree().process_frame
	var second_result := ScriptHookService.request_activity_flavor(activity)

	assert_eq(first_result, "")
	assert_eq(second_result, "")
	assert_signal_not_emitted(GameEvents, "event_narrated")
	assert_eq(int(AIManager.get_debug_snapshot().get("request_count", 0)), 0)


func test_activity_flavor_cache_miss_generates_and_stores() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "The fixture activity resolves with a clean trail.",
		}
	})
	watch_signals(GameEvents)

	var activity := DataManager.get_activity(ACTIVITY_ID)
	var first_result := ScriptHookService.request_activity_flavor(activity)
	assert_eq(first_result, "")

	await _wait_frames(5)

	var cached_result := ScriptHookService.request_activity_flavor(activity)
	var snapshot := AIManager.get_debug_snapshot()

	assert_eq(cached_result, "The fixture activity resolves with a clean trail.")
	assert_signal_emitted(GameEvents, "event_narrated")
	assert_eq(_narration_source_for(ACTIVITY_ID), "activity_flavor")
	assert_eq(int(snapshot.get("request_count", 0)), 1)


func test_activity_execution_queues_flavor_without_awaiting_generation() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "The activity echo arrives after the work is done.",
			"delay_frames": 3,
		}
	})
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity(ACTIVITY_ID)
	var pending_result := ScriptHookService.request_activity_flavor(DataManager.get_activity(ACTIVITY_ID))

	assert_true(bool(result.get("success", false)))
	assert_eq(pending_result, "")
	assert_signal_emitted(GameEvents, "activity_completed")
	assert_signal_not_emitted(GameEvents, "event_narrated")

	await _wait_frames(8)

	var cached_result := ScriptHookService.request_activity_flavor(DataManager.get_activity(ACTIVITY_ID))
	assert_eq(cached_result, "The activity echo arrives after the work is done.")
	assert_signal_emitted(GameEvents, "event_narrated")


func test_activity_lifecycle_hooks_are_invoked_through_script_hook_service() -> void:
	DataManager.activities[LIFECYCLE_ACTIVITY_ID] = _activity({
		"activity_id": LIFECYCLE_ACTIVITY_ID,
		"script_path": ACTIVITY_LIFECYCLE_HOOK_PATH,
	})

	var result := ACTIVITY_SERVICE.execute_activity(LIFECYCLE_ACTIVITY_ID, {"entity_id": "player"})

	assert_true(bool(result.get("success", false)))
	assert_eq(str(GameState.get_runtime_state("test_activity_hooks", "started_activity_id", "")), LIFECYCLE_ACTIVITY_ID)
	assert_eq(str(GameState.get_runtime_state("test_activity_hooks", "start_context_entity_id", "")), "player")
	assert_eq(str(GameState.get_runtime_state("test_activity_hooks", "completed_activity_id", "")), LIFECYCLE_ACTIVITY_ID)
	assert_eq(bool(GameState.get_runtime_state("test_activity_hooks", "completion_result_success", false)), true)


func test_activity_service_keeps_ai_calls_behind_script_hook_service() -> void:
	var source_file := FileAccess.open("res://systems/activity_service.gd", FileAccess.READ)
	assert_not_null(source_file)
	if source_file == null:
		return
	var source_text := source_file.get_as_text()

	assert_true(source_text.contains("ScriptHookService.request_activity_flavor"))
	assert_false(source_text.contains("AIManager"))
	assert_false(source_text.contains("generate_async"))


func _configure_saved_ai_settings(enable_world_gen: bool) -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: enable_world_gen,
			APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE if enable_world_gen else APP_SETTINGS.AI_PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: enable_world_gen,
		}
	})
	assert_eq(save_error, OK)
	ScriptHookService.invalidate_world_gen_settings_cache()


func _seed_activity_ai_fixture_data() -> void:
	DataManager.config["ai"] = {
		"narration_enabled": true,
		"activity_flavor_enabled": true,
		"world_gen_hooks": {
			"activity_flavor": ACTIVITY_FLAVOR_HOOK_PATH,
		},
	}
	DataManager.ai_templates["base:activity_flavor"] = {
		"template_id": "base:activity_flavor",
		"purpose": "activity_flavor",
		"prompt_template": "Describe activity {display_name} at {location_name}.",
		"fallback": "{display_name} finishes at {location_name}.",
	}
	DataManager.activities[ACTIVITY_ID] = _activity({"activity_id": ACTIVITY_ID})


func _activity(overrides: Dictionary = {}) -> Dictionary:
	var activity := {
		"activity_id": "base:test_activity",
		"display_name": "Test Activity",
		"description": "A test activity.",
		"category": "test",
		"kind": "standard",
		"duration_ticks": 0,
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"provider_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
		"travel_policy": "must_be_present",
		"schedule": {},
		"visible_if": [],
		"requirements": [],
		"start_actions": [],
		"completion_actions": [],
		"failure_actions": [],
		"outcomes": [],
		"repeat": {
			"rule": "always",
			"max_completions": -1,
			"max_completions_per_day": -1,
			"cooldown_ticks": 0,
			"cooldown_days": 0,
		},
		"tags": [],
		"ui": {},
		"ai": {},
	}
	for key_value in overrides.keys():
		activity[key_value] = overrides.get(key_value)
	return activity


func _narration_source_for(source_key: String) -> String:
	for event_value in GameEvents.get_event_history(0, "ai", "event_narrated"):
		if not event_value is Dictionary:
			continue
		var event_entry: Dictionary = event_value
		var args_value: Variant = event_entry.get("args", [])
		if not args_value is Array:
			continue
		var args: Array = args_value
		if args.size() >= 2 and str(args[1]) == source_key:
			return str(args[0])
	return ""


func _wait_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await get_tree().process_frame
