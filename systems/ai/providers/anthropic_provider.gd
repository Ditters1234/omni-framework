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


func _ready() -> void:
	return


## Configures the provider from engine-owned AI settings.
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


## Sends a Messages API request and returns the response text.
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


## Streaming generation — sends stream:true and calls chunk_callback per token.
## Falls back to the non-streaming path if chunk_callback is invalid.
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	if not chunk_callback.is_valid():
		await generate_async(prompt, context)
		return
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "AnthropicProvider: provider is not ready."
		return
	_last_error = ""
	var body := _build_streaming_request_body(prompt, context)
	var headers := _build_headers()
	await _send_streaming_request(body, headers, chunk_callback)


func _build_request_body(prompt: String, context: Dictionary) -> String:
	var messages: Array = []
	var history_value: Variant = context.get("history", [])
	if history_value is Array:
		var history: Array = history_value
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


func _build_streaming_request_body(prompt: String, context: Dictionary) -> String:
	var messages: Array = []
	var history_value: Variant = context.get("history", [])
	if history_value is Array:
		var history: Array = history_value
		messages.append_array(history)
	messages.append({"role": "user", "content": prompt})

	var payload: Dictionary = {
		"model": _model,
		"max_tokens": _max_tokens,
		"messages": messages,
		"stream": true,
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
	var http := HTTPRequest.new()
	add_child(http)
	var request_error := http.request(API_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		_last_error = "AnthropicProvider: request start failed (%d)." % request_error
		http.queue_free()
		return []
	var response: Array = await http.request_completed
	http.queue_free()
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
	var text_parts: Array[String] = []
	for content_item_value in content:
		if not content_item_value is Dictionary:
			continue
		var content_item: Dictionary = content_item_value
		if str(content_item.get("type", "text")) != "text":
			continue
		var text := str(content_item.get("text", ""))
		if not text.is_empty():
			text_parts.append(text)
	if text_parts.is_empty():
		_last_error = "AnthropicProvider: response text was empty."
		return ""
	return "\n".join(text_parts)


## Sends an SSE streaming request and calls chunk_callback for each text delta.
## Uses HTTPClient directly so we can read the response body incrementally.
## Anthropic SSE format: each chunk is an "event:" line followed by "data:" JSON.
## We extract text from "content_block_delta" events with type "text_delta".
func _send_streaming_request(
		body: String,
		headers: PackedStringArray,
		chunk_callback: Callable) -> void:
	const HOST := "api.anthropic.com"
	const PORT := 443
	const PATH := "/v1/messages"

	var http := HTTPClient.new()
	var connect_err := http.connect_to_host(HOST, PORT, TLSOptions.client())
	if connect_err != OK:
		_last_error = "AnthropicProvider: streaming connect failed (%d)." % connect_err
		return

	# Wait for connection.
	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		_last_error = "AnthropicProvider: streaming connection failed (status=%d)." % http.get_status()
		return

	var header_list: PackedStringArray = headers.duplicate()
	header_list.append("Content-Length: %d" % body.to_utf8_buffer().size())
	var request_err := http.request(HTTPClient.METHOD_POST, PATH, header_list, body)
	if request_err != OK:
		_last_error = "AnthropicProvider: streaming request failed (%d)." % request_err
		return

	# Wait for response headers.
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_BODY:
		_last_error = "AnthropicProvider: streaming response error (status=%d, http=%d)." % [
			http.get_status(), http.get_response_code()]
		return
	if http.get_response_code() != 200:
		_last_error = "AnthropicProvider: streaming HTTP error (%d)." % http.get_response_code()
		return

	# Read body chunks as they arrive.
	# Anthropic SSE is a sequence of paired lines:
	#   event: <event_type>
	#   data: <json>
	# We only care about data lines from "content_block_delta" events.
	var buffer := ""
	var current_event_type := ""
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			buffer += chunk.get_string_from_utf8()
			while true:
				var newline_pos := buffer.find("\n")
				if newline_pos == -1:
					break
				var line := buffer.left(newline_pos).strip_edges()
				buffer = buffer.substr(newline_pos + 1)
				if line.begins_with("event: "):
					current_event_type = line.substr(7).strip_edges()
				elif line.begins_with("data: "):
					var data_str := line.substr(6).strip_edges()
					if data_str == "[DONE]":
						return
					if current_event_type == "content_block_delta":
						var delta := _parse_sse_chunk(data_str)
						if not delta.is_empty() and chunk_callback.is_valid():
							chunk_callback.call(delta)
				elif line.is_empty():
					current_event_type = ""
		else:
			await get_tree().process_frame


## Extracts text from an Anthropic content_block_delta SSE data payload.
## Expected shape: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
func _parse_sse_chunk(data_str: String) -> String:
	var json := JSON.new()
	if json.parse(data_str) != OK:
		return ""
	var parsed_value: Variant = json.data
	if not parsed_value is Dictionary:
		return ""
	var parsed: Dictionary = parsed_value
	var delta_value: Variant = parsed.get("delta", {})
	if not delta_value is Dictionary:
		return ""
	var delta: Dictionary = delta_value
	if str(delta.get("type", "")) != "text_delta":
		return ""
	return str(delta.get("text", ""))


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
