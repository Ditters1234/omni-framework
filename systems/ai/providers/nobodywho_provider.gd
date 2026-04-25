## NobodyWhoProvider — Embedded local LLM via the NobodyWho GDExtension.
## No server required. The model runs in-process.
## Model file must be a .gguf placed at the configured path (gitignored).
##
## AI settings are engine-owned and persisted in user://settings.cfg.
extends Node

class_name NobodyWhoProvider

const DEFAULT_CTX := 2048
const DEFAULT_MAX_TOKENS := 256
const DEFAULT_TEMPERATURE := 0.7
const DEFAULT_REQUEST_TIMEOUT_SECONDS := 120.0
const DEFAULT_USE_GPU_IF_AVAILABLE := true
const DEFAULT_ALLOW_THINKING := false
const MODEL_CLASS_NAME := "NobodyWhoModel"
const CHAT_CLASS_NAME := "NobodyWhoChat"

var _model_path: String = ""
var _system_prompt: String = ""
var _n_ctx: int = DEFAULT_CTX
var _max_tokens: int = DEFAULT_MAX_TOKENS
var _temperature: float = DEFAULT_TEMPERATURE
var _request_timeout_seconds: float = DEFAULT_REQUEST_TIMEOUT_SECONDS
var _use_gpu_if_available: bool = DEFAULT_USE_GPU_IF_AVAILABLE
var _allow_thinking: bool = DEFAULT_ALLOW_THINKING

var _model_node: Node = null
var _chat_node: Node = null
var _is_ready: bool = false
var _is_generating: bool = false
var _last_error: String = ""
var _pending_response: String = ""
var _stream_chunk_callback: Callable = Callable()
var _streamed_chunk_count: int = 0

signal generation_completed

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	return


## Configures and loads the model from the engine-owned AI settings block.
func initialize(provider_config: Dictionary) -> void:
	_teardown_nodes()
	var model_path_value: Variant = provider_config.get("model_path", "")
	var system_prompt_value: Variant = provider_config.get("system_prompt", "")
	var n_ctx_value: Variant = provider_config.get("n_ctx", DEFAULT_CTX)
	var max_tokens_value: Variant = provider_config.get("max_tokens", DEFAULT_MAX_TOKENS)
	var temperature_value: Variant = provider_config.get("temperature", DEFAULT_TEMPERATURE)
	var timeout_value: Variant = provider_config.get("request_timeout_seconds", DEFAULT_REQUEST_TIMEOUT_SECONDS)
	var use_gpu_value: Variant = provider_config.get("use_gpu_if_available", DEFAULT_USE_GPU_IF_AVAILABLE)
	var allow_thinking_value: Variant = provider_config.get("allow_thinking", DEFAULT_ALLOW_THINKING)
	_model_path = _normalize_model_path(str(model_path_value))
	_system_prompt = str(system_prompt_value).strip_edges()
	_n_ctx = _normalize_positive_int(n_ctx_value, DEFAULT_CTX)
	_max_tokens = _normalize_positive_int(max_tokens_value, DEFAULT_MAX_TOKENS)
	_temperature = _normalize_temperature(temperature_value)
	_request_timeout_seconds = _normalize_positive_float(timeout_value, DEFAULT_REQUEST_TIMEOUT_SECONDS)
	_use_gpu_if_available = bool(use_gpu_value)
	_allow_thinking = bool(allow_thinking_value)
	_last_error = ""
	if _model_path.is_empty():
		_is_ready = false
		_last_error = "NobodyWhoProvider: model_path must not be empty."
		return
	_load_model()


## Returns true if the model loaded successfully.
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
		"model_path": _model_path,
		"is_ready": _is_ready,
		"last_error": _last_error,
		"n_ctx": _n_ctx,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"request_timeout_seconds": _request_timeout_seconds,
		"use_gpu_if_available": _use_gpu_if_available,
		"allow_thinking": _allow_thinking,
		"is_generating": _is_generating,
	}


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

## Generates a response using the embedded model.
func generate_async(prompt: String, context: Dictionary = {}) -> String:
	return await _generate_checked(prompt, context)


## Streaming generation — calls chunk_callback with each text token.
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	var result := await _generate_checked(prompt, context, chunk_callback)
	if not result.is_empty() and _streamed_chunk_count == 0 and chunk_callback.is_valid():
		chunk_callback.call(result)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_model() -> void:
	if not ClassDB.class_exists(MODEL_CLASS_NAME) or not ClassDB.class_exists(CHAT_CLASS_NAME):
		_is_ready = false
		_last_error = "NobodyWhoProvider: NobodyWho GDExtension classes are not available."
		push_warning(_last_error)
		return
	if not FileAccess.file_exists(_model_path):
		_is_ready = false
		_last_error = "NobodyWhoProvider: model_path does not exist: %s" % _model_path
		push_warning(_last_error)
		return

	var model_value: Variant = ClassDB.instantiate(MODEL_CLASS_NAME)
	var model_node: Node = model_value as Node
	if model_node == null:
		_is_ready = false
		_last_error = "NobodyWhoProvider: failed to instantiate %s." % MODEL_CLASS_NAME
		push_warning(_last_error)
		return

	var chat_value: Variant = ClassDB.instantiate(CHAT_CLASS_NAME)
	var chat_node: Node = chat_value as Node
	if chat_node == null:
		model_node.queue_free()
		_is_ready = false
		_last_error = "NobodyWhoProvider: failed to instantiate %s." % CHAT_CLASS_NAME
		push_warning(_last_error)
		return

	_model_node = model_node
	_chat_node = chat_node
	add_child(_model_node)
	add_child(_chat_node)
	_configure_model_node()
	_configure_chat_node()

	_is_ready = true
	_last_error = ""


func _generate_checked(prompt: String, context: Dictionary, chunk_callback: Callable = Callable()) -> String:
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "NobodyWhoProvider: model not ready."
		push_warning(_last_error)
		return ""
	if _is_generating:
		_last_error = "NobodyWhoProvider: generation is already in progress."
		push_warning(_last_error)
		return ""
	_last_error = ""
	return await _run_inference(prompt, context, chunk_callback)


func _run_inference(prompt: String, context: Dictionary, chunk_callback: Callable = Callable()) -> String:
	if _chat_node == null:
		_is_ready = false
		_last_error = "NobodyWhoProvider: chat node is missing."
		push_warning(_last_error)
		return ""

	_pending_response = ""
	_stream_chunk_callback = chunk_callback
	_streamed_chunk_count = 0
	_is_generating = true
	_apply_context(context)

	var tree := get_tree()
	if tree != null:
		var timeout_timer := tree.create_timer(_request_timeout_seconds)
		timeout_timer.timeout.connect(Callable(self, "_on_generation_timeout"), CONNECT_ONE_SHOT)

	var ask_result: Variant = _chat_node.call("ask", prompt)
	if ask_result is String:
		var immediate_response := str(ask_result).strip_edges()
		if not immediate_response.is_empty():
			_pending_response = immediate_response
			_is_generating = false
			_stream_chunk_callback = Callable()
			return _pending_response

	await generation_completed
	_is_generating = false
	_stream_chunk_callback = Callable()
	if not _last_error.is_empty():
		push_warning(_last_error)
		return ""
	return _pending_response


func _configure_model_node() -> void:
	if _model_node == null:
		return
	_model_node.set("model_path", _model_path)
	_model_node.set("use_gpu_if_available", _use_gpu_if_available)
	if _model_node.has_method("set_log_level"):
		_model_node.call("set_log_level", "warn")


func _configure_chat_node() -> void:
	if _chat_node == null:
		return
	_chat_node.set("model_node", _model_node)
	_chat_node.set("system_prompt", _system_prompt)
	_chat_node.set("context_length", _n_ctx)
	_chat_node.set("allow_thinking", _allow_thinking)
	if _chat_node.has_method("set_sampler_preset_temperature"):
		_chat_node.call("set_sampler_preset_temperature", _temperature)
	if _chat_node.has_method("set_log_level"):
		_chat_node.call("set_log_level", "warn")
	if not _chat_node.is_connected("response_updated", Callable(self, "_on_response_updated")):
		_chat_node.connect("response_updated", Callable(self, "_on_response_updated"))
	if not _chat_node.is_connected("response_finished", Callable(self, "_on_response_finished")):
		_chat_node.connect("response_finished", Callable(self, "_on_response_finished"))
	if _chat_node.has_method("start_worker"):
		_chat_node.call("start_worker")


func _apply_context(context: Dictionary) -> void:
	if _chat_node == null:
		return
	if _chat_node.has_method("reset_context"):
		_chat_node.call("reset_context")

	var system_prompt_value: Variant = context.get("system_prompt", "")
	var context_system_prompt := str(system_prompt_value).strip_edges()
	var active_system_prompt := _system_prompt
	if not context_system_prompt.is_empty():
		active_system_prompt = context_system_prompt
	_chat_node.set("system_prompt", active_system_prompt)

	var history_value: Variant = context.get("history", [])
	if history_value is Array and _chat_node.has_method("set_chat_history"):
		var history: Array = history_value
		var untyped_history: Array = []
		untyped_history.append_array(history)
		_chat_node.call("set_chat_history", untyped_history.duplicate(true))


func _on_response_updated(new_token: String) -> void:
	if not _is_generating or new_token.is_empty():
		return
	_streamed_chunk_count += 1
	if _stream_chunk_callback.is_valid():
		_stream_chunk_callback.call(new_token)


func _on_response_finished(response: String) -> void:
	if not _is_generating:
		return
	_pending_response = response
	generation_completed.emit()


func _on_generation_timeout() -> void:
	if not _is_generating:
		return
	_last_error = "NobodyWhoProvider: generation timed out after %.1f seconds." % _request_timeout_seconds
	if _chat_node != null and _chat_node.has_method("stop_generation"):
		_chat_node.call("stop_generation")
	generation_completed.emit()


func _teardown_nodes() -> void:
	_is_generating = false
	_is_ready = false
	_pending_response = ""
	_stream_chunk_callback = Callable()
	if _chat_node != null:
		if _chat_node.get_parent() == self:
			remove_child(_chat_node)
		_chat_node.queue_free()
		_chat_node = null
	if _model_node != null:
		if _model_node.get_parent() == self:
			remove_child(_model_node)
		_model_node.queue_free()
		_model_node = null


func _normalize_model_path(raw_path: String) -> String:
	var normalized_path := raw_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty() or normalized_path.contains("://") or normalized_path.is_absolute_path():
		return normalized_path
	return "res://%s" % normalized_path


func _normalize_positive_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		var normalized := int(value)
		if normalized > 0:
			return normalized
	return maxi(fallback, 1)


func _normalize_positive_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var normalized := float(value)
		if normalized > 0.0:
			return normalized
	return maxf(fallback, 0.1)


func _normalize_temperature(value: Variant) -> float:
	if value is int or value is float:
		return maxf(float(value), 0.0)
	return DEFAULT_TEMPERATURE
