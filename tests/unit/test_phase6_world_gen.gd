extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const TASK_PROVIDER_BACKEND := preload("res://ui/screens/backends/task_provider_backend.gd")
const EVENT_LOG_BACKEND := preload("res://ui/screens/backends/event_log_backend.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"
const NARRATION_HOOK_PATH := "res://mods/base/scripts/ai_narration_hook.gd"
const TASK_FLAVOR_HOOK_PATH := "res://mods/base/scripts/ai_task_flavor_hook.gd"


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
	_seed_phase6_fixture_data()


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


func test_world_gen_hooks_noop_when_ai_is_disabled() -> void:
	watch_signals(GameEvents)

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:phase6_faction",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("ai_flavor_text", "")), "")

	GameState.travel_to(TEST_FIXTURE_WORLD.connected_location_id())
	TimeKeeper.advance_to_next_day()
	await get_tree().process_frame

	assert_signal_not_emitted(GameEvents, "event_narrated")

	var event_backend: RefCounted = EVENT_LOG_BACKEND.new()
	event_backend.initialize({
		"domain": "game_state",
		"signal_name": "location_changed",
		"newest_first": false,
	})
	var event_view_model: Dictionary = event_backend.build_view_model()
	var event_rows_value: Variant = event_view_model.get("rows", [])

	assert_true(event_rows_value is Array)
	if event_rows_value is Array:
		var event_rows: Array = event_rows_value
		assert_eq(event_rows.size(), 1)
		if not event_rows.is_empty() and event_rows[0] is Dictionary:
			var row: Dictionary = event_rows[0]
			assert_eq(str(row.get("narration_text", "")), "")


func test_location_change_narration_appears_in_event_log_when_enabled() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "Rain hisses across the district as you cross into the field.",
		}
	})
	watch_signals(GameEvents)

	GameState.travel_to(TEST_FIXTURE_WORLD.connected_location_id())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_signal_emitted(GameEvents, "event_narrated")

	var backend: RefCounted = EVENT_LOG_BACKEND.new()
	backend.initialize({
		"domain": "game_state",
		"signal_name": "location_changed",
		"newest_first": false,
	})
	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("signal_name", "")), "location_changed")
			assert_eq(str(row.get("narration_text", "")), "Rain hisses across the district as you cross into the field.")


func test_task_provider_backend_surfaces_cached_ai_flavor_text() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "Slip the package through the checkpoint before dawn.",
		}
	})
	watch_signals(GameEvents)

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:phase6_faction",
	})

	var first_view_model: Dictionary = backend.build_view_model()
	var first_rows_value: Variant = first_view_model.get("rows", [])
	assert_true(first_rows_value is Array)
	await get_tree().process_frame
	await get_tree().process_frame

	var second_view_model: Dictionary = backend.build_view_model()
	var second_rows_value: Variant = second_view_model.get("rows", [])
	var selected_task_value: Variant = second_view_model.get("selected_task", {})

	assert_signal_emitted(GameEvents, "event_narrated")
	assert_true(second_rows_value is Array)
	assert_true(selected_task_value is Dictionary)
	if second_rows_value is Array:
		var rows: Array = second_rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("ai_flavor_text", "")), "Slip the package through the checkpoint before dawn.")
	if selected_task_value is Dictionary:
		var selected_task: Dictionary = selected_task_value
		assert_eq(str(selected_task.get("flavor_text", "")), "Slip the package through the checkpoint before dawn.")


func _configure_saved_ai_settings(enable_world_gen: bool) -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: enable_world_gen,
			APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE if enable_world_gen else APP_SETTINGS.AI_PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: enable_world_gen,
		}
	})
	assert_eq(save_error, OK)


func _seed_phase6_fixture_data() -> void:
	DataManager.config["ai"] = {
		"narration_enabled": true,
		"task_flavor_enabled": true,
		"world_gen_hooks": {
			"narration": NARRATION_HOOK_PATH,
			"task_flavor": TASK_FLAVOR_HOOK_PATH,
		},
	}
	DataManager.ai_templates["base:event_narration_location_changed"] = {
		"template_id": "base:event_narration_location_changed",
		"purpose": "event_narration",
		"prompt_template": "Describe arrival at {new_location_name}.",
		"fallback": "You arrive at {new_location_name}.",
	}
	DataManager.ai_templates["base:event_narration_day_advanced"] = {
		"template_id": "base:event_narration_day_advanced",
		"purpose": "event_narration",
		"prompt_template": "Describe the start of day {day} in {location_name}.",
		"fallback": "Day {day} begins in {location_name}.",
	}
	DataManager.ai_templates["base:event_narration_quest_completed"] = {
		"template_id": "base:event_narration_quest_completed",
		"purpose": "event_narration",
		"prompt_template": "Describe completing {quest_name}.",
		"fallback": "{quest_name} is complete.",
	}
	DataManager.ai_templates["base:task_flavor"] = {
		"template_id": "base:task_flavor",
		"purpose": "task_description",
		"prompt_template": "Describe the task {display_name} for {faction_name} in {location_name}.",
		"fallback": "{display_name} awaits at {location_name}.",
	}
	DataManager.factions["base:phase6_faction"] = {
		"faction_id": "base:phase6_faction",
		"display_name": "Phase 6 Dispatch",
		"quest_pool": ["base:phase6_contract"],
	}
	DataManager.quests["base:phase6_contract"] = {
		"quest_id": "base:phase6_contract",
		"display_name": "Courier Drop",
		"description": "Deliver the package to the connected location.",
		"stages": [
			{
				"description": "Reach the connected location.",
				"objectives": [
					{
						"type": "reach_location",
						"entity_id": "quest:assignee",
						"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
					}
				],
			}
		],
		"reward": {"credits": 5},
		"repeatable": true,
	}
