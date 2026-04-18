extends GutTest


const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"


func before_each() -> void:
	GameEvents.clear_event_history()
	DataManager.clear_all()
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	DataManager.config = {
		"ai": {
			"enabled": false,
			"provider": AIManager.PROVIDER_DISABLED
		}
	}
	AIManager.initialize()


func after_each() -> void:
	AIManager.clear_provider_script_overrides()
	DataManager.config = {
		"ai": {
			"enabled": false,
			"provider": AIManager.PROVIDER_DISABLED
		}
	}
	AIManager.initialize()


func test_initialize_respects_enabled_flag_even_with_real_provider_value() -> void:
	DataManager.config = {
		"ai": {
			"enabled": false,
			"provider": AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"openai_compatible": {
				"endpoint": "http://127.0.0.1:8080/v1/chat/completions",
				"model": "ignored"
			}
		}
	}

	AIManager.initialize()

	assert_eq(AIManager.get_provider_name(), AIManager.PROVIDER_DISABLED)
	assert_false(AIManager.is_available())
	assert_true(AIManager._provider == null)


func test_generate_async_noops_without_ai_error_when_disabled() -> void:
	watch_signals(GameEvents)

	var response := await AIManager.generate_async("Describe the room.")

	assert_eq(response, "")
	assert_signal_not_emitted(GameEvents, "ai_error")
	var snapshot := AIManager.get_debug_snapshot()
	var last_request_value: Variant = snapshot.get("last_request", {})
	assert_true(last_request_value is Dictionary)
	var last_request: Dictionary = last_request_value
	assert_eq(str(last_request.get("status", "")), AIManager.REQUEST_STATUS_SKIPPED)


func test_invalid_provider_config_stays_unavailable_and_reports_error() -> void:
	DataManager.config = {
		"ai": {
			"enabled": true,
			"provider": AIManager.PROVIDER_ANTHROPIC,
			"anthropic": {
				"model": "claude-test"
			}
		}
	}

	AIManager.initialize()

	assert_eq(AIManager.get_provider_name(), AIManager.PROVIDER_ANTHROPIC)
	assert_false(AIManager.is_available())
	var snapshot := AIManager.get_debug_snapshot()
	assert_true(str(snapshot.get("last_error", "")).contains("api_key"))


func test_generate_async_emits_ai_response_event_and_records_debug_history() -> void:
	_configure_fake_provider()
	watch_signals(GameEvents)

	var response := await AIManager.generate_async("Describe the room.", {
		"response": "Dust hangs in the air."
	})

	assert_eq(response, "Dust hangs in the air.")
	assert_signal_emitted(GameEvents, "ai_response_received")
	var response_params_value: Variant = get_signal_parameters(GameEvents, "ai_response_received")
	assert_true(response_params_value is Array)
	var response_params: Array = response_params_value
	assert_eq(response_params.size(), 2)
	assert_eq(str(response_params[1]), "Dust hangs in the air.")

	var history := GameEvents.get_event_history(10, "ai", "ai_response_received")
	assert_eq(history.size(), 1)
	assert_eq(str(history[0].get("args", ["", ""])[1]), "Dust hangs in the air.")

	var snapshot := AIManager.get_debug_snapshot()
	var last_request_value: Variant = snapshot.get("last_request", {})
	assert_true(last_request_value is Dictionary)
	var last_request: Dictionary = last_request_value
	assert_eq(str(last_request.get("status", "")), AIManager.REQUEST_STATUS_COMPLETED)
	assert_eq(str(last_request.get("response_preview", "")), "Dust hangs in the air.")


func test_generate_async_emits_ai_error_when_provider_fails() -> void:
	_configure_fake_provider()
	watch_signals(GameEvents)

	var response := await AIManager.generate_async("Describe the room.", {
		"simulate_error": true,
		"error_text": "FakeAIProvider: scripted failure."
	})

	assert_eq(response, "")
	assert_signal_emitted(GameEvents, "ai_error")
	var error_params_value: Variant = get_signal_parameters(GameEvents, "ai_error")
	assert_true(error_params_value is Array)
	var error_params: Array = error_params_value
	assert_eq(error_params.size(), 2)
	assert_eq(str(error_params[1]), "FakeAIProvider: scripted failure.")

	var snapshot := AIManager.get_debug_snapshot()
	assert_eq(str(snapshot.get("last_error", "")), "FakeAIProvider: scripted failure.")


func test_generate_streaming_returns_request_id_and_emits_tokens_and_response() -> void:
	_configure_fake_provider()
	watch_signals(GameEvents)

	var request_id := AIManager.generate_streaming("Stream it.", {
		"chunks": ["Dust", " ", "hangs"]
	})
	await get_tree().process_frame

	assert_false(request_id.is_empty())
	assert_signal_emitted(GameEvents, "ai_token_received")
	assert_signal_emitted(GameEvents, "ai_response_received")

	var token_history := GameEvents.get_event_history(10, "ai", "ai_token_received")
	assert_eq(token_history.size(), 3)
	assert_eq(str(token_history[0].get("args", ["", ""])[0]), request_id)
	assert_eq(str(token_history[2].get("args", ["", ""])[1]), "hangs")

	var response_history := GameEvents.get_event_history(10, "ai", "ai_response_received")
	assert_eq(response_history.size(), 1)
	assert_eq(str(response_history[0].get("args", ["", ""])[0]), request_id)
	assert_eq(str(response_history[0].get("args", ["", ""])[1]), "Dust hangs")


func test_generate_async_accepts_documented_array_context_shape() -> void:
	_configure_fake_provider()

	var response := await AIManager.generate_async("Describe the room.", [
		{"role": "system", "content": "Stay brief."}
	])

	assert_eq(response, "fake response")
	var snapshot := AIManager.get_debug_snapshot()
	var provider_debug_value: Variant = snapshot.get("provider_debug", {})
	assert_true(provider_debug_value is Dictionary)
	var provider_debug: Dictionary = provider_debug_value
	var last_context_value: Variant = provider_debug.get("last_context", {})
	assert_true(last_context_value is Dictionary)
	var last_context: Dictionary = last_context_value
	var history_value: Variant = last_context.get("history", [])
	assert_true(history_value is Array)
	var history: Array = history_value
	assert_eq(history.size(), 1)


func test_initialize_resets_debug_history_between_boot_cycles() -> void:
	_configure_fake_provider()
	await AIManager.generate_async("Describe the room.", {"response": "Dust hangs in the air."})

	var before_snapshot := AIManager.get_debug_snapshot()
	assert_eq(int(before_snapshot.get("request_count", 0)), 1)

	DataManager.config = {
		"ai": {
			"enabled": false,
			"provider": AIManager.PROVIDER_DISABLED
		}
	}
	AIManager.initialize()

	var after_snapshot := AIManager.get_debug_snapshot()
	assert_eq(int(after_snapshot.get("request_count", 0)), 0)
	assert_eq(int(after_snapshot.get("active_request_count", 0)), 0)
	var recent_requests_value: Variant = after_snapshot.get("recent_requests", [])
	assert_true(recent_requests_value is Array)
	var recent_requests: Array = recent_requests_value
	assert_eq(recent_requests.size(), 0)


func _configure_fake_provider() -> void:
	DataManager.config = {
		"ai": {
			"enabled": true,
			"provider": AIManager.PROVIDER_OPENAI_COMPATIBLE,
			"openai_compatible": {
				"ready": true
			}
		}
	}
	AIManager.initialize()
