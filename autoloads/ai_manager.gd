## AIManager — LLM abstraction layer.
## Reads engine-owned app settings and routes all generation calls
## to the correct backend provider.
## Modders access AI via: AIManager.generate_async(prompt, context)
## Always guard with: if not AIManager.is_available(): return
extends Node

class_name OmniAIManager

const APP_SETTINGS := preload("res://core/app_settings.gd")

const PROVIDER_OPENAI_COMPATIBLE := "openai_compatible"
const PROVIDER_ANTHROPIC := "anthropic"
const PROVIDER_NOBODYWHO := "nobodywho"
const PROVIDER_DISABLED := "disabled"
const MAX_RECENT_REQUESTS := 20
const REQUEST_STATUS_PENDING := "pending"
const REQUEST_STATUS_COMPLETED := "completed"
const REQUEST_STATUS_FAILED := "failed"
const REQUEST_STATUS_SKIPPED := "skipped"
const PROVIDER_SCRIPT_PATHS := {
	PROVIDER_OPENAI_COMPATIBLE: "res://systems/ai/providers/openai_provider.gd",
	PROVIDER_ANTHROPIC: "res://systems/ai/providers/anthropic_provider.gd",
	PROVIDER_NOBODYWHO: "res://systems/ai/providers/nobodywho_provider.gd",
}

var _provider: Node = null
var _provider_type: String = PROVIDER_DISABLED
var _ai_enabled: bool = false
var _provider_script_overrides: Dictionary = {}
var _request_counter: int = 0
var _active_requests: Dictionary = {}
var _recent_requests: Array[Dictionary] = []
var _last_error: String = ""

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	return


## Called after application settings are available.
## Instantiates and configures the appropriate provider from engine-owned settings.
func initialize(settings_override: Dictionary = {}) -> void:
	_reset_runtime_state()
	_teardown_provider()
	var ai_config := _extract_ai_settings(settings_override)
	_ai_enabled = bool(ai_config.get(APP_SETTINGS.AI_ENABLED, false))
	_provider_type = str(ai_config.get(APP_SETTINGS.AI_PROVIDER, PROVIDER_DISABLED))

	if not _ai_enabled:
		_provider_type = PROVIDER_DISABLED
		return

	if _provider_type == PROVIDER_DISABLED:
		return

	_provider = _load_provider(_provider_type)
	if _provider == null:
		_set_last_error("AIManager: failed to load provider '%s'." % _provider_type)
		_provider_type = PROVIDER_DISABLED
		return

	add_child(_provider)
	if _provider.has_method("initialize"):
		var provider_config := _build_provider_config(ai_config)
		_provider.call("initialize", provider_config)
	var provider_error := _peek_provider_error()
	if not provider_error.is_empty():
		_last_error = provider_error


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if a working AI provider is configured and ready.
func is_available() -> bool:
	if not _ai_enabled or _provider == null or _provider_type == PROVIDER_DISABLED:
		return false
	if _provider.has_method("is_ready"):
		return bool(_provider.call("is_ready"))
	return _peek_provider_error().is_empty()


## Returns the active provider type string.
func get_provider_name() -> String:
	return _provider_type


## Backward-compatible alias retained while the documented public name stays stable.
func get_provider_type() -> String:
	return get_provider_name()


## Fire-and-forget helper. Returns the request id and invokes callback(response) when done.
func generate(
		prompt: String,
		context: Variant = [],
		callback: Callable = Callable()) -> String:
	var normalized_context := _normalize_context(context)
	var request_id := _begin_request("generate", prompt, normalized_context)
	call_deferred("_run_generate_with_callback", request_id, prompt, normalized_context, callback)
	return request_id


## Generates a response asynchronously. Returns the response string.
## On failure returns an empty string and emits GameEvents.ai_error.
## Always await this call:
##   var response = await AIManager.generate_async(prompt)
func generate_async(prompt: String, context: Variant = []) -> String:
	var normalized_context := _normalize_context(context)
	var request_id := _begin_request("generate_async", prompt, normalized_context)
	return await _run_generate_request(request_id, prompt, normalized_context)


## Generates a streaming response and returns the request id immediately.
## Emits GameEvents.ai_token_received for each chunk and ai_response_received on completion.
func generate_streaming(prompt: String, context: Variant = []) -> String:
	var normalized_context := _normalize_context(context)
	var request_id := _begin_request("generate_streaming", prompt, normalized_context)
	call_deferred("_run_generate_streaming", request_id, prompt, normalized_context, Callable())
	return request_id


## Backward-compatible async wrapper for older callers that pass a chunk callback directly.
## chunk_callback signature: func(chunk: String) -> void
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Variant = []) -> void:
	var normalized_context := _normalize_context(context)
	var request_id := _begin_request("generate_streaming_async", prompt, normalized_context)
	call_deferred("_run_generate_streaming", request_id, prompt, normalized_context, chunk_callback)


func get_debug_snapshot() -> Dictionary:
	var recent_requests: Array[Dictionary] = []
	for entry in _recent_requests:
		recent_requests.append(entry.duplicate(true))
	var provider_snapshot: Dictionary = {}
	if _provider != null and _provider.has_method("get_debug_snapshot"):
		var provider_snapshot_value: Variant = _provider.call("get_debug_snapshot")
		if provider_snapshot_value is Dictionary:
			var snapshot_dict: Dictionary = provider_snapshot_value
			provider_snapshot = snapshot_dict.duplicate(true)
	return {
		"enabled": _ai_enabled,
		"provider": _provider_type,
		"provider_name": get_provider_name(),
		"available": is_available(),
		"has_provider_node": _provider != null,
		"active_request_count": _active_requests.size(),
		"request_count": _request_counter,
		"last_error": _last_error,
		"last_request": _get_last_request_entry(),
		"recent_requests": recent_requests,
		"provider_debug": provider_snapshot,
	}


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Loads and returns the provider script for the given type.
func _load_provider(provider_type: String) -> Node:
	var script_path := str(_provider_script_overrides.get(
		provider_type,
		PROVIDER_SCRIPT_PATHS.get(provider_type, "")
	))
	if script_path.is_empty():
		return null

	var script: GDScript = load(script_path)
	if script == null:
		return null
	return script.new()


func _build_provider_config(ai_config: Dictionary) -> Dictionary:
	var result := ai_config.duplicate(true)
	result.erase(APP_SETTINGS.AI_ENABLED)
	result.erase(APP_SETTINGS.AI_PROVIDER)
	return result


func _extract_ai_settings(settings_override: Dictionary) -> Dictionary:
	if settings_override.is_empty():
		return APP_SETTINGS.get_ai_settings()
	var ai_source: Dictionary = settings_override.duplicate(true)
	if settings_override.has(APP_SETTINGS.SECTION_AI):
		var ai_section_value: Variant = settings_override.get(APP_SETTINGS.SECTION_AI, {})
		if ai_section_value is Dictionary:
			ai_source = (ai_section_value as Dictionary).duplicate(true)
	var normalized := APP_SETTINGS.get_ai_settings({
		APP_SETTINGS.SECTION_AI: ai_source
	})
	for key_value in ai_source.keys():
		var key := str(key_value)
		if normalized.has(key):
			continue
		normalized[key] = ai_source.get(key_value, null)
	return normalized


func set_provider_script_override(provider_type: String, script_path: String) -> void:
	if provider_type.is_empty():
		return
	if script_path.is_empty():
		_provider_script_overrides.erase(provider_type)
		return
	_provider_script_overrides[provider_type] = script_path


func clear_provider_script_overrides() -> void:
	_provider_script_overrides.clear()


func _normalize_context(context: Variant) -> Dictionary:
	if context is Dictionary:
		var context_dict: Dictionary = context
		return context_dict.duplicate(true)
	if context is Array:
		var history: Array = context
		return {"history": history.duplicate(true)}
	return {}


func _run_generate_with_callback(
		request_id: String,
		prompt: String,
		context: Dictionary,
		callback: Callable) -> void:
	var response := await _run_generate_request(request_id, prompt, context)
	if callback.is_valid():
		callback.call(response)


func _run_generate_request(request_id: String, prompt: String, context: Dictionary) -> String:
	var noop_reason := _get_noop_reason(prompt)
	if not noop_reason.is_empty():
		_finalize_request_skipped(request_id, noop_reason)
		return ""
	var preflight_error := _get_preflight_error(prompt)
	if not preflight_error.is_empty():
		_finalize_request_error(request_id, preflight_error)
		return ""

	_clear_provider_error()
	var response_value: Variant = await _provider.call("generate_async", prompt, context)
	var response := ""
	if response_value != null:
		response = str(response_value)
	var provider_error := _consume_provider_error()
	if not provider_error.is_empty():
		_finalize_request_error(request_id, provider_error)
		return ""
	if response.is_empty():
		_finalize_request_error(request_id, "AIManager: provider returned an empty response.")
		return ""

	_finalize_request_success(request_id, response)
	return response


func _run_generate_streaming(
		request_id: String,
		prompt: String,
		context: Dictionary,
		chunk_callback: Callable) -> void:
	var noop_reason := _get_noop_reason(prompt)
	if not noop_reason.is_empty():
		_finalize_request_skipped(request_id, noop_reason)
		return
	var preflight_error := _get_preflight_error(prompt)
	if not preflight_error.is_empty():
		_finalize_request_error(request_id, preflight_error)
		return

	_clear_provider_error()
	var chunks: Array[String] = []
	var manager_chunk_callback := Callable(self, "_record_stream_chunk").bind(request_id, chunks, chunk_callback)
	await _provider.call("generate_streaming_async", prompt, manager_chunk_callback, context)
	var provider_error := _consume_provider_error()
	if not provider_error.is_empty():
		_finalize_request_error(request_id, provider_error)
		return

	var response := "".join(chunks)
	if response.is_empty():
		_finalize_request_error(request_id, "AIManager: provider returned an empty streaming response.")
		return
	_finalize_request_success(request_id, response)


func _record_stream_chunk(
		chunk: String,
		request_id: String,
		chunks: Array[String],
		external_callback: Callable) -> void:
	if chunk.is_empty():
		return
	chunks.append(chunk)
	GameEvents.emit_dynamic("ai_token_received", [request_id, chunk])
	if external_callback.is_valid():
		external_callback.call(chunk)


func _get_preflight_error(prompt: String) -> String:
	if prompt.strip_edges().is_empty():
		return "AIManager: prompt must not be empty."
	if _provider == null:
		return "AIManager: no provider is configured."
	if not is_available():
		var provider_error := _peek_provider_error()
		if not provider_error.is_empty():
			return provider_error
		return "AIManager: provider '%s' is not ready." % _provider_type
	return ""


func _get_noop_reason(prompt: String) -> String:
	if prompt.strip_edges().is_empty():
		return ""
	if not _ai_enabled:
		return "AI disabled"
	if _provider_type == PROVIDER_DISABLED:
		return "No AI provider configured"
	return ""


func _begin_request(mode: String, prompt: String, context: Dictionary) -> String:
	_request_counter += 1
	var request_id := "ai_%06d" % _request_counter
	_active_requests[request_id] = {
		"request_id": request_id,
		"mode": mode,
		"provider": _provider_type,
		"status": REQUEST_STATUS_PENDING,
		"started_at": Time.get_datetime_string_from_system(true, true),
		"completed_at": "",
		"prompt_preview": _preview_text(prompt),
		"history_count": _get_history_count(context),
		"has_system_prompt": _has_system_prompt(context),
		"response_preview": "",
		"error": "",
	}
	return request_id


func _finalize_request_success(request_id: String, response: String) -> void:
	var request_entry := _get_active_request_entry(request_id)
	request_entry["status"] = REQUEST_STATUS_COMPLETED
	request_entry["completed_at"] = Time.get_datetime_string_from_system(true, true)
	request_entry["response_preview"] = _preview_text(response)
	request_entry["error"] = ""
	_store_completed_request(request_id, request_entry)
	_last_error = ""
	GameEvents.emit_dynamic("ai_response_received", [request_id, response])


func _finalize_request_error(request_id: String, error_text: String) -> void:
	var request_entry := _get_active_request_entry(request_id)
	request_entry["status"] = REQUEST_STATUS_FAILED
	request_entry["completed_at"] = Time.get_datetime_string_from_system(true, true)
	request_entry["response_preview"] = ""
	request_entry["error"] = error_text
	_store_completed_request(request_id, request_entry)
	_set_last_error(error_text)
	GameEvents.emit_dynamic("ai_error", [request_id, error_text])


func _finalize_request_skipped(request_id: String, reason: String) -> void:
	var request_entry := _get_active_request_entry(request_id)
	request_entry["status"] = REQUEST_STATUS_SKIPPED
	request_entry["completed_at"] = Time.get_datetime_string_from_system(true, true)
	request_entry["response_preview"] = ""
	request_entry["error"] = reason
	_store_completed_request(request_id, request_entry)


func _store_completed_request(request_id: String, request_entry: Dictionary) -> void:
	_active_requests.erase(request_id)
	_recent_requests.append(request_entry.duplicate(true))
	if _recent_requests.size() > MAX_RECENT_REQUESTS:
		_recent_requests.pop_front()


func _get_active_request_entry(request_id: String) -> Dictionary:
	var request_value: Variant = _active_requests.get(request_id, {})
	if request_value is Dictionary:
		var request_entry: Dictionary = request_value
		return request_entry.duplicate(true)
	return {
		"request_id": request_id,
		"mode": "",
		"provider": _provider_type,
		"status": REQUEST_STATUS_PENDING,
		"started_at": Time.get_datetime_string_from_system(true, true),
		"completed_at": "",
		"prompt_preview": "",
		"history_count": 0,
		"has_system_prompt": false,
		"response_preview": "",
		"error": "",
	}


func _get_last_request_entry() -> Dictionary:
	if _recent_requests.is_empty():
		return {}
	return _recent_requests[_recent_requests.size() - 1].duplicate(true)


func _preview_text(text: String, max_length: int = 80) -> String:
	var compact_text := text.strip_edges().replace("\n", " ")
	if compact_text.length() <= max_length:
		return compact_text
	return compact_text.left(max_length - 3) + "..."


func _get_history_count(context: Dictionary) -> int:
	var history_value: Variant = context.get("history", [])
	if history_value is Array:
		var history: Array = history_value
		return history.size()
	return 0


func _has_system_prompt(context: Dictionary) -> bool:
	var system_prompt := str(context.get("system_prompt", ""))
	return not system_prompt.is_empty()


func _teardown_provider() -> void:
	if _provider == null:
		return
	if _provider.get_parent() == self:
		remove_child(_provider)
	_provider.queue_free()
	_provider = null


func _reset_runtime_state() -> void:
	_active_requests.clear()
	_recent_requests.clear()
	_request_counter = 0
	_last_error = ""
	_ai_enabled = false


func _set_last_error(error_text: String) -> void:
	_last_error = error_text
	push_warning(error_text)


func _clear_provider_error() -> void:
	if _provider != null and _provider.has_method("clear_last_error"):
		_provider.call("clear_last_error")


func _peek_provider_error() -> String:
	if _provider == null or not _provider.has_method("get_last_error"):
		return ""
	return str(_provider.call("get_last_error"))


func _consume_provider_error() -> String:
	if _provider == null:
		return ""
	if _provider.has_method("consume_last_error"):
		return str(_provider.call("consume_last_error"))
	if _provider.has_method("get_last_error"):
		return str(_provider.call("get_last_error"))
	return ""
