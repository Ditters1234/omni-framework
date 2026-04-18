## OpenAIProvider — OpenAI-compatible HTTP provider.
## Covers: OpenAI, Ollama (http://localhost:11434/v1), LM Studio, and any
## service that implements the OpenAI Chat Completions API.
##
## Config block (config.json):
## "ai": {
##   "provider": "openai_compatible",
##   "openai_compatible": {
##     "endpoint": "http://localhost:11434/v1/chat/completions",
##     "api_key": "",
##     "model": "llama3",
##     "max_tokens": 256,
##     "temperature": 0.7,
##     "system_prompt": "You are a helpful game character."
##   }
## }
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

var _http: HTTPRequest = null

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


## Configures the provider from the config.json ai.openai_compatible block.
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


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

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


## Streaming generation — calls chunk_callback with each streamed text chunk.
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	# SSE streaming requires manual HTTPClient — implement in full version.
	var result := await generate_async(prompt, context)
	if not result.is_empty():
		chunk_callback.call(result)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _build_messages(prompt: String, context: Dictionary) -> Array:
	var messages: Array = []
	var system: String = str(context.get("system_prompt", _system_prompt))
	if not system.is_empty():
		messages.append({"role": "system", "content": system})
	var history_value: Variant = context.get("history", [])
	var history: Array = []
	if history_value is Array:
		history = history_value
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


func _build_headers() -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	if not _api_key.is_empty():
		headers.append("Authorization: Bearer " + _api_key)
	return headers


func _send_request(body: String, headers: PackedStringArray) -> Array:
	if _http == null:
		_last_error = "OpenAIProvider: HTTPRequest is not ready."
		return []
	var request_error := _http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		_last_error = "OpenAIProvider: request start failed (%d)." % request_error
		return []
	var response: Array = await _http.request_completed
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
