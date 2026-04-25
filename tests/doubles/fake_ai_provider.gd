extends Node


var _is_ready: bool = true
var _last_error: String = ""
var _last_context: Dictionary = {}


func initialize(provider_config: Dictionary) -> void:
	_is_ready = bool(provider_config.get("ready", true))
	_last_error = str(provider_config.get("initial_error", ""))


func is_ready() -> bool:
	return _is_ready


func get_last_error() -> String:
	return _last_error


func clear_last_error() -> void:
	_last_error = ""


func consume_last_error() -> String:
	var error_text := _last_error
	_last_error = ""
	return error_text


func get_debug_snapshot() -> Dictionary:
	return {
		"is_ready": _is_ready,
		"last_error": _last_error,
		"last_context": _last_context.duplicate(true),
	}


func generate_async(prompt: String, context: Dictionary = {}) -> String:
	_last_context = context.duplicate(true)
	_last_context["prompt"] = prompt
	if context.get("simulate_error", false):
		_last_error = str(context.get("error_text", "FakeAIProvider: simulated failure."))
		return ""
	return str(context.get("response", "fake response"))


func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	_last_context = context.duplicate(true)
	_last_context["prompt"] = prompt
	if context.get("simulate_error", false):
		_last_error = str(context.get("error_text", "FakeAIProvider: simulated streaming failure."))
		return
	var chunks_value: Variant = context.get("chunks", [])
	if chunks_value is Array:
		var chunks: Array = chunks_value
		if not chunks.is_empty():
			for chunk_value in chunks:
				chunk_callback.call(str(chunk_value))
			return
	var response := str(context.get("response", "fake response"))
	if not response.is_empty():
		chunk_callback.call(response)
