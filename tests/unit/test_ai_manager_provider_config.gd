extends GutTest


func before_each() -> void:
	DataManager.clear_all()
	DataManager.config = {
		"ai": {
			"provider": AIManager.PROVIDER_DISABLED
		}
	}
	AIManager.initialize()


func after_each() -> void:
	DataManager.config = {
		"ai": {
			"provider": AIManager.PROVIDER_DISABLED
		}
	}
	AIManager.initialize()


func test_initialize_reads_nested_provider_block() -> void:
	DataManager.config = {
		"ai": {
			"provider": AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"system_prompt": "Global system prompt",
			"openai_compatible": {
				"endpoint": "http://127.0.0.1:8080/v1/chat/completions",
				"model": "omni-test",
				"temperature": 0.25,
				"max_tokens": 64
			}
		}
	}

	AIManager.initialize()

	var provider := AIManager._provider as OpenAIProvider
	assert_true(provider != null)
	assert_eq(AIManager.get_provider_type(), AIManager.PROVIDER_OPENAI_COMPATIBLE)
	assert_eq(provider._endpoint, "http://127.0.0.1:8080/v1/chat/completions")
	assert_eq(provider._model, "omni-test")
	assert_eq(provider._temperature, 0.25)
	assert_eq(provider._max_tokens, 64)
	assert_eq(provider._system_prompt, "Global system prompt")
	assert_true(AIManager.is_available())
