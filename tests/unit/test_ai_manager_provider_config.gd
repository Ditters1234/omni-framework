extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")


func before_each() -> void:
	DataManager.clear_all()
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
	}))


func after_each() -> void:
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
	}))
	await get_tree().process_frame


func test_initialize_reads_nested_provider_block() -> void:
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: true,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
		APP_SETTINGS.AI_ENDPOINT: "http://127.0.0.1:8080/v1/chat/completions",
		APP_SETTINGS.AI_MODEL: "omni-test",
		APP_SETTINGS.AI_TEMPERATURE: 0.25,
		APP_SETTINGS.AI_MAX_TOKENS: 64,
		APP_SETTINGS.AI_SYSTEM_PROMPT: "Global system prompt",
	}))

	var provider := AIManager._provider as OpenAIProvider
	assert_true(provider != null)
	assert_eq(AIManager.get_provider_type(), AIManager.PROVIDER_OPENAI_COMPATIBLE)
	assert_eq(provider._endpoint, "http://127.0.0.1:8080/v1/chat/completions")
	assert_eq(provider._model, "omni-test")
	assert_eq(provider._temperature, 0.25)
	assert_eq(provider._max_tokens, 64)
	assert_eq(provider._system_prompt, "Global system prompt")
	assert_true(AIManager.is_available())


func _make_settings(ai_overrides: Dictionary) -> Dictionary:
	var settings := APP_SETTINGS.get_default_settings()
	var ai_settings := APP_SETTINGS.get_ai_settings(settings)
	for key_value in ai_overrides.keys():
		ai_settings[str(key_value)] = ai_overrides.get(key_value, null)
	settings[APP_SETTINGS.SECTION_AI] = ai_settings
	return settings
