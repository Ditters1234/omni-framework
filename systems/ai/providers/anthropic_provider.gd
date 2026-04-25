## AnthropicProvider — Anthropic Messages API provider.
## Calls api.anthropic.com/v1/messages directly via HTTPRequest.
extends Node

class_name AnthropicProvider

const API_ENDPOINT := "https://api.anthropic.com/v1/messages"
const ANTHROPIC_VERSION := "2023-06-01"
const DEFAULT_MODEL := "claude-haiku-4-5-20251001"
const DEFAULT_MAX_TOKENS := 256

var _api_key: String = ""
var _model: String = DEFAULT_MODEL
var _max_tokens: int = DEFAULT_MAX_TOKENS
var _system_prompt: String = ""
var _is_ready: bool = false
var _last_error: String = ""

var _http: HTTPRequest = null

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


func initialize(provider_config: Dictionary) -> void:
	_api_key       = str(provider_config.get("api_key", ""))
	_model         = str(provider_config.get("model", DEFAULT_MODEL))
	_max_tokens    = int(provider_config.get("max_tokens", DEFAULT_MAX_TOKENS))
	_system_prompt = str(provider_config.get("system_prompt", ""))
	_refresh_readiness()


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
		"endpoint": API_ENDPOINT,
		"model": _model,
		"has_api_key": not _api_key.is_empty(),
		"is_ready": _is_ready,
		"last_error": _last_error,
	}


func generate_async(prompt: String, context: Dictionary = {}) -> String:
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "AnthropicProvider: provider is not ready."
		return ""
	_last_error = ""
	var body := _build_request_body(prompt, context)
	var headers := _build_headers()
	var response := await _send_request(body, headers)
	return _parse_response(response)


func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	var result := await generate_async(prompt, context)
	if not result.is_empty():
		chunk_callback.call(result)


func _build_request_body(prompt: String, context: Dictionary) -> String:
	var messages: Array = []
	var history_value: Variant = context.get("history", [])
	var history: Array = []
	if history_value is Array:
		history = history_value
	messages.append_array(history)
	messages.append({"role": "user", "content": prompt})

	var payload: Dictionary = {
		"model": _model,
		"max_tokens": _max_tokens,
		"messages": messages,
	}
	var system: String = str(context.get("system_prompt", _system_prompt))
	if not system.is_empty():
		payload["system"] = system

	return JSON.stringify(payload)


func _build_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: " + _api_key,
		"anthropic-version: " + ANTHROPIC_VERSION,
	])


func _send_request(body: String, headers: PackedStringArray) -> Array:
	# Use a per-request HTTPRequest node. A single HTTPRequest cannot service
	# overlapping calls; reusing one node makes concurrent AI requests fail with
	# ERR_BUSY. AIManager tracks multiple active requests, so provider transport
	# needs to be concurrency-safe.
	var request_node := HTTPRequest.new()
	add_child(request_node)
	var request_error := request_node.request(API_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		_last_error = "AnthropicProvider: request start failed (%d)." % request_error
		request_node.queue_free()
		return []
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	return response


func _parse_response(response: Array) -> String:
	if response.is_empty():
		if _last_error.is_empty():
			_last_error = "AnthropicProvider: no response received."
		return ""
	var result_code: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]
	if result_code != OK or response_code != 200:
		_last_error = "AnthropicProvider: request failed (result=%d, http=%d)." % [result_code, response_code]
		push_warning(_last_error)
		return ""
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_last_error = "AnthropicProvider: invalid JSON response."
		return ""
	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		_last_error = "AnthropicProvider: response payload must be an object."
		return ""
	var data: Dictionary = parsed_data
	var content_value: Variant = data.get("content", [])
	if not content_value is Array:
		_last_error = "AnthropicProvider: content must be an array."
		return ""
	var content: Array = content_value
	if content.is_empty():
		_last_error = "AnthropicProvider: content array was empty."
		return ""
	var first_content: Variant = content[0]
	if not first_content is Dictionary:
		_last_error = "AnthropicProvider: first content entry must be an object."
		return ""
	var text := str(first_content.get("text", ""))
	if text.is_empty():
		_last_error = "AnthropicProvider: response text was empty."
		return ""
	return text


func _refresh_readiness() -> void:
	_is_ready = false
	_last_error = ""
	if _api_key.is_empty():
		_last_error = "AnthropicProvider: api_key must not be empty."
		return
	if _model.is_empty():
		_last_error = "AnthropicProvider: model must not be empty."
		return
	_is_ready = true
