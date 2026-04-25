extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const ENTITY_SHEET_BACKEND := preload("res://ui/screens/backends/entity_sheet_backend.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"
const LORE_HOOK_PATH := "res://mods/base/scripts/ai_lore_hook.gd"


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
	_seed_phase7_fixture_data()


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


func test_entity_lore_noop_when_ai_is_disabled() -> void:
	var backend: RefCounted = ENTITY_SHEET_BACKEND.new()
	backend.initialize({
		"target_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
	})
	var view_model: Dictionary = backend.build_view_model()
	assert_eq(str(view_model.get("ai_lore", "")), "")


func test_entity_lore_cache_miss_generates_and_stores() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "Theta has seen more chrome than most see in a lifetime.",
		}
	})

	var backend: RefCounted = ENTITY_SHEET_BACKEND.new()
	backend.initialize({
		"target_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
	})

	# First call triggers the async request but returns empty (cache miss)
	var first_view_model: Dictionary = backend.build_view_model()
	assert_eq(str(first_view_model.get("ai_lore", "")), "")

	await get_tree().process_frame
	await get_tree().process_frame

	# Second call should hit the cache
	var second_view_model: Dictionary = backend.build_view_model()
	assert_eq(str(second_view_model.get("ai_lore", "")), "Theta has seen more chrome than most see in a lifetime.")


func test_entity_lore_cache_hit_avoids_redundant_api_calls() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "Known throughout the district.",
		}
	})

	var backend: RefCounted = ENTITY_SHEET_BACKEND.new()
	backend.initialize({
		"target_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
	})

	backend.build_view_model()
	await get_tree().process_frame
	await get_tree().process_frame

	# Cache is now warm — build again and verify lore is returned immediately
	var cached_view_model: Dictionary = backend.build_view_model()
	assert_eq(str(cached_view_model.get("ai_lore", "")), "Known throughout the district.")

	# Build a third time — should still return cached value without new request
	var third_view_model: Dictionary = backend.build_view_model()
	assert_eq(str(third_view_model.get("ai_lore", "")), "Known throughout the district.")


func test_lore_cache_clears_on_reset() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "Old lore text.",
		}
	})

	var backend: RefCounted = ENTITY_SHEET_BACKEND.new()
	backend.initialize({
		"target_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
	})

	backend.build_view_model()
	await get_tree().process_frame
	await get_tree().process_frame

	var before_reset: Dictionary = backend.build_view_model()
	assert_eq(str(before_reset.get("ai_lore", "")), "Old lore text.")

	# Simulate new game / load
	ScriptHookService.reset_world_gen_state()

	var after_reset: Dictionary = backend.build_view_model()
	assert_eq(str(after_reset.get("ai_lore", "")), "")


func test_part_lore_cache_miss_generates_and_stores() -> void:
	_configure_saved_ai_settings(true)
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"response": "A reliable piece of street tech.",
		}
	})

	var part_template := DataManager.get_part("base:human_head")
	assert_false(part_template.is_empty())

	# First call triggers async request
	var first_result := ScriptHookService.request_part_lore(part_template)
	assert_eq(first_result, "")

	await get_tree().process_frame
	await get_tree().process_frame

	# Second call should hit cache
	var second_result := ScriptHookService.request_part_lore(part_template)
	assert_eq(second_result, "A reliable piece of street tech.")


func _configure_saved_ai_settings(enable_world_gen: bool) -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: enable_world_gen,
			APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE if enable_world_gen else APP_SETTINGS.AI_PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: enable_world_gen,
		}
	})
	assert_eq(save_error, OK)


func _seed_phase7_fixture_data() -> void:
	DataManager.config["ai"] = {
		"narration_enabled": true,
		"task_flavor_enabled": true,
		"lore_enabled": true,
		"world_gen_hooks": {
			"narration": "res://mods/base/scripts/ai_narration_hook.gd",
			"task_flavor": "res://mods/base/scripts/ai_task_flavor_hook.gd",
			"lore": LORE_HOOK_PATH,
		},
	}
	DataManager.ai_templates["base:entity_lore"] = {
		"template_id": "base:entity_lore",
		"purpose": "entity_lore",
		"prompt_template": "Write lore about {display_name}. {description}",
		"fallback": "{display_name} is known around {location_name}.",
	}
	DataManager.ai_templates["base:part_lore"] = {
		"template_id": "base:part_lore",
		"purpose": "part_lore",
		"prompt_template": "Write lore about part {display_name}. {description}",
		"fallback": "{display_name} is a recognized piece of kit.",
	}
