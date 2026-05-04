## OpenAIProvider — OpenAI-compatible HTTP provider.
## Covers: OpenAI, Ollama, LM Studio, OpenRouter, Groq, and any service that
## implements the OpenAI Chat Completions API.
extends Node

class_name OpenAIProvider

const DEFAULT_ENDPOINT := "http://localhost:11434/v1/chat/completions"
const DEFAULT_MODEL := "llama3"
const DEFAULT_MAX_TOKENS := 256
const DEFAULT_TEMPERATURE := 0.7
const DEFAULT_TIMEOUT_SECONDS := 120.0
const CHAT_COMPLETIONS_PATH := "/chat/completions"
const V1_CHAT_COMPLETIONS_PATH := "/v1/chat/completions"

var _endpoint: String = DEFAULT_ENDPOINT
var _api_key: String = ""
var _model: String = DEFAULT_MODEL
var _max_tokens: int = DEFAULT_MAX_TOKENS
var _temperature: float = DEFAULT_TEMPERATURE
var _system_prompt: String = ""
var _timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
var _is_ready: bool = false
var _last_error: String = ""


func _ready() -> void:
	return


## Configures the provider from engine-owned AI settings.
func initialize(provider_config: Dictionary) -> void:
	_endpoint      = _normalize_endpoint(str(provider_config.get("endpoint", DEFAULT_ENDPOINT)))
	_api_key       = str(provider_config.get("api_key", "")).strip_edges()
	_model         = str(provider_config.get("model", DEFAULT_MODEL)).strip_edges()
	_max_tokens    = _normalize_positive_int(provider_config.get("max_tokens", DEFAULT_MAX_TOKENS), DEFAULT_MAX_TOKENS)
	_temperature   = maxf(float(provider_config.get("temperature", DEFAULT_TEMPERATURE)), 0.0)
	_system_prompt = str(provider_config.get("system_prompt", "")).strip_edges()
	_timeout_seconds = _normalize_positive_float(provider_config.get("request_timeout_seconds", DEFAULT_TIMEOUT_SECONDS), DEFAULT_TIMEOUT_SECONDS)
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


func generate_async(prompt: String, context: Dictionary = {}) -> String:
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "OpenAIProvider: provider is not ready."
		return ""
	_last_error = ""
	var messages := _build_messages(prompt, context)
	var body := _build_request_body(messages)
	var headers := _build_headers(false)
	var response := await _send_request(body, headers)
	return _parse_response(response)


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
	var headers := _build_headers(true)
	await _send_streaming_request(body, headers, chunk_callback)


func _build_messages(prompt: String, context: Dictionary) -> Array:
	var messages: Array = []
	var system: String = str(context.get("system_prompt", _system_prompt)).strip_edges()
	if not system.is_empty():
		messages.append({"role": "system", "content": system})
	var history_value: Variant = context.get("history", [])
	if history_value is Array:
		for item_value in history_value:
			if item_value is Dictionary:
				messages.append((item_value as Dictionary).duplicate(true))
	messages.append({"role": "user", "content": prompt})
	return messages


func _build_request_body(messages: Array) -> String:
	return JSON.stringify({
		"model": _model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"stream": false,
	})


func _build_streaming_request_body(messages: Array) -> String:
	return JSON.stringify({
		"model": _model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"temperature": _temperature,
		"stream": true,
	})


func _build_headers(streaming: bool = false) -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	if streaming:
		headers.append("Accept: text/event-stream")
	else:
		headers.append("Accept: application/json")
	if not _api_key.is_empty():
		headers.append("Authorization: Bearer " + _api_key)
	return headers


func _send_request(body: String, headers: PackedStringArray) -> Array:
	var http := HTTPRequest.new()
	http.timeout = _timeout_seconds
	add_child(http)
	var request_error := http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		_last_error = "OpenAIProvider: request start failed (%s). endpoint=%s" % [error_string(request_error), _endpoint]
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
	var result_code: int = int(response[0])
	var response_code: int = int(response[1])
	var body: PackedByteArray = response[3]
	var body_text := body.get_string_from_utf8()
	if result_code != OK or response_code < 200 or response_code >= 300:
		_last_error = "OpenAIProvider: request failed (result=%s, http=%d, endpoint=%s). %s" % [
			error_string(result_code), response_code, _endpoint, _preview_error_body(body_text)
		]
		push_warning(_last_error)
		return ""
	var json := JSON.new()
	if json.parse(body_text) != OK:
		_last_error = "OpenAIProvider: invalid JSON response. %s" % json.get_error_message()
		return ""
	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		_last_error = "OpenAIProvider: response payload must be an object."
		return ""
	var data: Dictionary = parsed_data
	var choices_value: Variant = data.get("choices", [])
	if not choices_value is Array or (choices_value as Array).is_empty():
		_last_error = "OpenAIProvider: response choices were missing or empty."
		return ""
	var first_choice: Variant = (choices_value as Array)[0]
	if not first_choice is Dictionary:
		_last_error = "OpenAIProvider: first choice must be an object."
		return ""
	var message: Variant = (first_choice as Dictionary).get("message", {})
	if message is Dictionary:
		var content_value: Variant = (message as Dictionary).get("content", "")
		if content_value is Array:
			var parts: Array[String] = []
			for part_value in content_value:
				if part_value is Dictionary:
					var text := str((part_value as Dictionary).get("text", ""))
					if not text.is_empty():
						parts.append(text)
			if not parts.is_empty():
				return "\n".join(parts)
		var content := str(content_value)
		if not content.is_empty():
			return content
	var text := str((first_choice as Dictionary).get("text", ""))
	if not text.is_empty():
		return text
	_last_error = "OpenAIProvider: response content was empty."
	return ""


func _send_streaming_request(
		body: String,
		headers: PackedStringArray,
		chunk_callback: Callable) -> void:
	var parsed := _parse_http_url(_endpoint)
	if parsed.is_empty():
		_last_error = "OpenAIProvider: invalid endpoint URL: %s" % _endpoint
		return
	var use_ssl := bool(parsed.get("use_ssl", false))
	var host := str(parsed.get("host", ""))
	var port := int(parsed.get("port", 443 if use_ssl else 80))
	var path := str(parsed.get("path", "/"))

	var http := HTTPClient.new()
	var connect_err := http.connect_to_host(host, port, TLSOptions.client() if use_ssl else null)
	if connect_err != OK:
		_last_error = "OpenAIProvider: streaming connect failed (%s)." % error_string(connect_err)
		return

	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		_last_error = "OpenAIProvider: streaming connection failed (status=%d)." % http.get_status()
		return

	var header_list: PackedStringArray = headers.duplicate()
	header_list.append("Host: " + host)
	header_list.append("Content-Length: %d" % body.to_utf8_buffer().size())
	var request_err := http.request(HTTPClient.METHOD_POST, path, header_list, body)
	if request_err != OK:
		_last_error = "OpenAIProvider: streaming request failed (%s)." % error_string(request_err)
		return

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_BODY:
		_last_error = "OpenAIProvider: streaming response error (status=%d, http=%d)." % [http.get_status(), http.get_response_code()]
		return
	if http.get_response_code() < 200 or http.get_response_code() >= 300:
		_last_error = "OpenAIProvider: streaming HTTP error (%d)." % http.get_response_code()
		return

	var buffer := ""
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			buffer += chunk.get_string_from_utf8()
			buffer = _process_sse_buffer(buffer, chunk_callback)
		else:
			await get_tree().process_frame


func _process_sse_buffer(buffer: String, chunk_callback: Callable) -> String:
	while true:
		var newline_pos := buffer.find("\n")
		if newline_pos == -1:
			return buffer
		var line := buffer.left(newline_pos).strip_edges()
		buffer = buffer.substr(newline_pos + 1)
		if not line.begins_with("data:"):
			continue
		var data_str := line.substr(5).strip_edges()
		if data_str == "[DONE]":
			return ""
		var delta := _parse_sse_chunk(data_str)
		if not delta.is_empty() and chunk_callback.is_valid():
			chunk_callback.call(delta)
	return buffer


func _parse_sse_chunk(data_str: String) -> String:
	var json := JSON.new()
	if json.parse(data_str) != OK:
		return ""
	var parsed_value: Variant = json.data
	if not parsed_value is Dictionary:
		return ""
	var choices_value: Variant = (parsed_value as Dictionary).get("choices", [])
	if not choices_value is Array or (choices_value as Array).is_empty():
		return ""
	var choice_value: Variant = (choices_value as Array)[0]
	if not choice_value is Dictionary:
		return ""
	var choice: Dictionary = choice_value
	var delta_value: Variant = choice.get("delta", {})
	if delta_value is Dictionary:
		return str((delta_value as Dictionary).get("content", ""))
	return str(choice.get("text", ""))


func _refresh_readiness() -> void:
	_is_ready = false
	_last_error = ""
	if _endpoint.is_empty():
		_last_error = "OpenAIProvider: endpoint must not be empty."
		return
	if _parse_http_url(_endpoint).is_empty():
		_last_error = "OpenAIProvider: endpoint must be a valid http:// or https:// URL."
		return
	if _model.is_empty():
		_last_error = "OpenAIProvider: model must not be empty."
		return
	_is_ready = true


func _normalize_endpoint(raw_endpoint: String) -> String:
	var endpoint := raw_endpoint.strip_edges().replace("\\", "/")
	if endpoint.is_empty():
		endpoint = DEFAULT_ENDPOINT
	endpoint = endpoint.split("#", true, 1)[0].split("?", true, 1)[0].rstrip("/")
	if endpoint.ends_with(CHAT_COMPLETIONS_PATH):
		return endpoint
	if endpoint.ends_with("/v1"):
		return endpoint + CHAT_COMPLETIONS_PATH
	if endpoint.ends_with("/api"):
		return endpoint + V1_CHAT_COMPLETIONS_PATH
	if _host_looks_openai_compatible_base(endpoint):
		return endpoint + V1_CHAT_COMPLETIONS_PATH
	return endpoint + CHAT_COMPLETIONS_PATH


func _host_looks_openai_compatible_base(endpoint: String) -> bool:
	var parsed := _parse_http_url(endpoint)
	if parsed.is_empty():
		return false
	var path := str(parsed.get("path", "/")).rstrip("/")
	return path.is_empty() or path == "/"


func _parse_http_url(url: String) -> Dictionary:
	var trimmed := url.strip_edges()
	var use_ssl := false
	if trimmed.begins_with("https://"):
		use_ssl = true
		trimmed = trimmed.substr(8)
	elif trimmed.begins_with("http://"):
		trimmed = trimmed.substr(7)
	else:
		return {}
	var slash_pos := trimmed.find("/")
	var host_port := trimmed
	var path := "/"
	if slash_pos != -1:
		host_port = trimmed.left(slash_pos)
		path = trimmed.substr(slash_pos)
	if host_port.is_empty():
		return {}
	var host := host_port
	var port := 443 if use_ssl else 80
	var colon_pos := host_port.rfind(":")
	if colon_pos != -1:
		host = host_port.left(colon_pos)
		port = int(host_port.substr(colon_pos + 1))
	if host.is_empty() or port <= 0:
		return {}
	return {"use_ssl": use_ssl, "host": host, "port": port, "path": path}


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


func _preview_error_body(body_text: String, max_length: int = 500) -> String:
	var compact := body_text.strip_edges().replace("\n", " ")
	if compact.length() <= max_length:
		return compact
	return compact.left(max_length - 3) + "..."
