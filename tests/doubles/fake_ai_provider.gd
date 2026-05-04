extends Node


var _is_ready: bool = true
var _last_error: String = ""
var _last_context: Dictionary = {}
var _default_response: String = "fake response"
var _default_stream_chunks: Array[String] = []
var _default_delay_frames: int = 0
var _default_simulate_error: bool = false
var _default_error_text: String = "FakeAIProvider: simulated failure."
var _request_count: int = 0
var _active_request_count: int = 0
var _max_concurrent_requests: int = 0


func initialize(provider_config: Dictionary) -> void:
	_is_ready = bool(provider_config.get("ready", true))
	_last_error = str(provider_config.get("initial_error", ""))
	_default_response = str(provider_config.get("response", "fake response"))
	_default_delay_frames = int(provider_config.get("delay_frames", 0))
	_default_simulate_error = bool(provider_config.get("simulate_error", false))
	_default_error_text = str(provider_config.get("error_text", "FakeAIProvider: simulated failure."))
	_request_count = 0
	_active_request_count = 0
	_max_concurrent_requests = 0
	_default_stream_chunks.clear()
	var stream_chunks_value: Variant = provider_config.get("chunks", [])
	if stream_chunks_value is Array:
		var stream_chunks: Array = stream_chunks_value
		for chunk_value in stream_chunks:
			_default_stream_chunks.append(str(chunk_value))


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
		"request_count": _request_count,
		"active_request_count": _active_request_count,
		"max_concurrent_requests": _max_concurrent_requests,
	}


func generate_async(prompt: String, context: Dictionary = {}) -> String:
	_begin_fake_request()
	_last_context = context.duplicate(true)
	_last_context["prompt"] = prompt
	_request_count += 1
	var delay_frames := int(context.get("delay_frames", _default_delay_frames))
	for _frame_index in range(maxi(delay_frames, 0)):
		await get_tree().process_frame
	var simulate_error := bool(context.get("simulate_error", _default_simulate_error))
	if simulate_error:
		_last_error = str(context.get("error_text", _default_error_text))
		_end_fake_request()
		return ""
	var response := str(context.get("response", _default_response))
	_end_fake_request()
	return response


func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	_begin_fake_request()
	_last_context = context.duplicate(true)
	_last_context["prompt"] = prompt
	_request_count += 1
	var delay_frames := int(context.get("delay_frames", _default_delay_frames))
	for _frame_index in range(maxi(delay_frames, 0)):
		await get_tree().process_frame
	var simulate_error := bool(context.get("simulate_error", _default_simulate_error))
	if simulate_error:
		_last_error = str(context.get("error_text", "FakeAIProvider: simulated streaming failure."))
		_end_fake_request()
		return
	var chunks_value: Variant = context.get("chunks", [])
	if chunks_value is Array:
		var chunks: Array = chunks_value
		if not chunks.is_empty():
			for chunk_value in chunks:
				chunk_callback.call(str(chunk_value))
			_end_fake_request()
			return
	if not _default_stream_chunks.is_empty():
		for chunk in _default_stream_chunks:
			chunk_callback.call(chunk)
		_end_fake_request()
		return
	var response := str(context.get("response", _default_response))
	if not response.is_empty():
		chunk_callback.call(response)
	_end_fake_request()


func _begin_fake_request() -> void:
	_active_request_count += 1
	_max_concurrent_requests = maxi(_max_concurrent_requests, _active_request_count)


func _end_fake_request() -> void:
	_active_request_count = maxi(_active_request_count - 1, 0)
