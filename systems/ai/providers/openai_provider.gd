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


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

## Sends a chat completion request and returns the response string.
func generate_async(prompt: String, context: Dictionary = {}) -> String:
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
	var history: Array = context.get("history", [])
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
	_http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	var response: Array = await _http.request_completed
	return response


func _parse_response(response: Array) -> String:
	if response.is_empty():
		return ""
	var result_code: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]
	if result_code != OK or response_code != 200:
		push_warning("OpenAIProvider: request failed (result=%d, http=%d)" % [result_code, response_code])
		return ""
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return ""
	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		return ""
	var data: Dictionary = parsed_data
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		return ""
	var first_choice: Variant = choices[0]
	if not first_choice is Dictionary:
		return ""
	var message: Variant = first_choice.get("message", {})
	if not message is Dictionary:
		return ""
	return str(message.get("content", ""))
