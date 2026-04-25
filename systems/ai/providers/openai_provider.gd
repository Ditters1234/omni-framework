## OpenAIProvider — OpenAI-compatible HTTP provider.
## Covers: OpenAI, Ollama (http://localhost:11434/v1), LM Studio, and any
## service that implements the OpenAI Chat Completions API.
extends Node

class_name OpenAIProvider

const DEFAULT_ENDPOINT := "http://localhost:11434/v1/chat/completions"
const DEFAULT_MODEL := "llama3"
const DEFAULT_MAX_TOKENS := 256
const DEFAULT_TEMPERATURE := 0.7

var _endpoint: String = DEFAULT_ENDPOINT
var _api_key: String = ""
var _model: String = DEFAULT_MODEL
var _max_tokens: int = DEFAULT_MAX_TOKENS
var _temperature: float = DEFAULT_TEMPERATURE
var _system_prompt: String = ""
var _is_ready: bool = false
var _last_error: String = ""


func _ready() -> void:
	return


## Configures the provider from engine-owned AI settings.
func initialize(provider_config: Dictionary) -> void:
	_endpoint      = str(provider_config.get("endpoint", DEFAULT_ENDPOINT))
	_api_key       = str(provider_config.get("api_key", ""))
	_model         = str(provider_config.get("model", DEFAULT_MODEL))
	_max_tokens    = int(provider_config.get("max_tokens", DEFAULT_MAX_TOKENS))
	_temperature   = float(provider_config.get("temperature", DEFAULT_TEMPERATURE))
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
		"endpoint": _endpoint,
		"model": _model,
		"has_api_key": not _api_key.is_empty(),
		"is_ready": _is_ready,
		"last_error": _last_error,
	}


## Sends a chat completion request and returns the response string.
func generate_async(prompt: String, context: Dictionary = {}) -> String:
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "OpenAIProvider: provider is not ready."
		return ""
	_last_error = ""
	var messages := _build_messages(prompt, context)
	var body := _build_request_body(messages)
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
			_last_error = "OpenAIProvider: provider is not ready."
		return
	_last_error = ""
	var messages := _build_messages(prompt, context)
	var body := _build_streaming_request_body(messages)
	var headers := _build_headers()
	await _send_streaming_request(body, headers, chunk_callback)


func _build_messages(prompt: String, context: Dictionary) -> Array:
	var messages: Array = []
	var system: String = str(context.get("system_prompt", _system_prompt))
	if not system.is_empty():
		messages.append({"role": "system", "content": system})
	var history_value: Variant = context.get("history", [])
	if history_value is Array:
		var history: Array = history_value
		messages.append_array(history)
	messages.append({"role": "user", "content": prompt})
	return messages


func _build_request_body(messages: Array) -> String:
	var payload := {
		"model": _model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"stream": false,
	}
	return JSON.stringify(payload)


func _build_streaming_request_body(messages: Array) -> String:
	var payload := {
		"model": _model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"stream": true,
	}
	return JSON.stringify(payload)


func _build_headers() -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	if not _api_key.is_empty():
		headers.append("Authorization: Bearer " + _api_key)
	return headers


func _send_request(body: String, headers: PackedStringArray) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	var request_error := http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		_last_error = "OpenAIProvider: request start failed (%d)." % request_error
		http.queue_free()
		return []
	var response: Array = await http.request_completed
	http.queue_free()
	return response


func _parse_response(response: Array) -> String:
	if response.is_empty():
		if _last_error.is_empty():
			_last_error = "OpenAIProvider: no response received."
		return ""
	var result_code: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]
	if result_code != OK or response_code != 200:
		_last_error = "OpenAIProvider: request failed (result=%d, http=%d)." % [result_code, response_code]
		push_warning(_last_error)
		return ""
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_last_error = "OpenAIProvider: invalid JSON response."
		return ""
	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		_last_error = "OpenAIProvider: response payload must be an object."
		return ""
	var data: Dictionary = parsed_data
	var choices_value: Variant = data.get("choices", [])
	if not choices_value is Array:
		_last_error = "OpenAIProvider: response choices must be an array."
		return ""
	var choices: Array = choices_value
	if choices.is_empty():
		_last_error = "OpenAIProvider: response choices were empty."
		return ""
	var first_choice: Variant = choices[0]
	if not first_choice is Dictionary:
		_last_error = "OpenAIProvider: first choice must be an object."
		return ""
	var message: Variant = first_choice.get("message", {})
	if not message is Dictionary:
		_last_error = "OpenAIProvider: choice message must be an object."
		return ""
	var content := str(message.get("content", ""))
	if content.is_empty():
		_last_error = "OpenAIProvider: response content was empty."
		return ""
	return content


## Sends an SSE streaming request and calls chunk_callback for each text delta.
## Uses HTTPClient directly so we can read the response body incrementally.
func _send_streaming_request(
		body: String,
		headers: PackedStringArray,
		chunk_callback: Callable) -> void:
	var url := _endpoint
	var use_ssl := url.begins_with("https://")
	# Strip scheme to get host + path.
	var stripped := url.trim_prefix("https://").trim_prefix("http://")
	var slash_pos := stripped.find("/")
	var host: String
	var path: String
	if slash_pos == -1:
		host = stripped
		path = "/"
	else:
		host = stripped.left(slash_pos)
		path = stripped.substr(slash_pos)
	var port := 443 if use_ssl else 80
	var colon_pos := host.rfind(":")
	if colon_pos != -1:
		port = int(host.substr(colon_pos + 1))
		host = host.left(colon_pos)

	var http := HTTPClient.new()
	var connect_err := http.connect_to_host(host, port, TLSOptions.client() if use_ssl else null)
	if connect_err != OK:
		_last_error = "OpenAIProvider: streaming connect failed (%d)." % connect_err
		return

	# Wait for connection.
	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		_last_error = "OpenAIProvider: streaming connection failed (status=%d)." % http.get_status()
		return

	# Build header array for HTTPClient (array of strings).
	var header_list: PackedStringArray = headers.duplicate()
	header_list.append("Content-Length: %d" % body.to_utf8_buffer().size())
	var request_err := http.request(HTTPClient.METHOD_POST, path, header_list, body)
	if request_err != OK:
		_last_error = "OpenAIProvider: streaming request failed (%d)." % request_err
		return

	# Wait for response headers.
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_BODY:
		_last_error = "OpenAIProvider: streaming response error (status=%d, http=%d)." % [
			http.get_status(), http.get_response_code()]
		return
	if http.get_response_code() != 200:
		_last_error = "OpenAIProvider: streaming HTTP error (%d)." % http.get_response_code()
		return

	# Read body chunks as they arrive.
	var buffer := ""
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			buffer += chunk.get_string_from_utf8()
			# SSE lines are separated by "\n". Process complete lines.
			while true:
				var newline_pos := buffer.find("\n")
				if newline_pos == -1:
					break
				var line := buffer.left(newline_pos).strip_edges()
				buffer = buffer.substr(newline_pos + 1)
				if line.begins_with("data: "):
					var data_str := line.substr(6).strip_edges()
					if data_str == "[DONE]":
						return
					var delta := _parse_sse_chunk(data_str)
					if not delta.is_empty() and chunk_callback.is_valid():
						chunk_callback.call(delta)
		else:
			await get_tree().process_frame


## Extracts the content delta text from a single OpenAI SSE data payload.
func _parse_sse_chunk(data_str: String) -> String:
	var json := JSON.new()
	if json.parse(data_str) != OK:
		return ""
	var parsed_value: Variant = json.data
	if not parsed_value is Dictionary:
		return ""
	var parsed: Dictionary = parsed_value
	var choices_value: Variant = parsed.get("choices", [])
	if not choices_value is Array:
		return ""
	var choices: Array = choices_value
	if choices.is_empty():
		return ""
	var choice_value: Variant = choices[0]
	if not choice_value is Dictionary:
		return ""
	var choice: Dictionary = choice_value
	var delta_value: Variant = choice.get("delta", {})
	if not delta_value is Dictionary:
		return ""
	var delta: Dictionary = delta_value
	return str(delta.get("content", ""))


func _refresh_readiness() -> void:
	_is_ready = false
	_last_error = ""
	if _endpoint.is_empty():
		_last_error = "OpenAIProvider: endpoint must not be empty."
		return
	if not (_endpoint.begins_with("http://") or _endpoint.begins_with("https://")):
		_last_error = "OpenAIProvider: endpoint must start with http:// or https://."
		return
	if _model.is_empty():
		_last_error = "OpenAIProvider: model must not be empty."
		return
	_is_ready = true
