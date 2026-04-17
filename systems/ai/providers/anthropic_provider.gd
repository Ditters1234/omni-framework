## AnthropicProvider — Anthropic Messages API provider.
## Calls api.anthropic.com/v1/messages directly via HTTPRequest.
##
## Config block (config.json):
## "ai": {
##   "provider": "anthropic",
##   "anthropic": {
##     "api_key": "sk-ant-...",
##     "model": "claude-haiku-4-5-20251001",
##     "max_tokens": 256,
##     "system_prompt": "You are a helpful game character."
##   }
## }
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

var _http: HTTPRequest = null

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


## Configures the provider from the config.json ai.anthropic block.
func initialize(provider_config: Dictionary) -> void:
	_api_key       = str(provider_config.get("api_key", ""))
	_model         = str(provider_config.get("model", DEFAULT_MODEL))
	_max_tokens    = int(provider_config.get("max_tokens", DEFAULT_MAX_TOKENS))
	_system_prompt = str(provider_config.get("system_prompt", ""))


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

## Sends a Messages API request and returns the response text.
func generate_async(prompt: String, context: Dictionary = {}) -> String:
	var body := _build_request_body(prompt, context)
	var headers := _build_headers()
	var response := await _send_request(body, headers)
	return _parse_response(response)


## Streaming is not yet implemented — falls back to blocking call.
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	var result := await generate_async(prompt, context)
	if not result.is_empty():
		chunk_callback.call(result)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _build_request_body(prompt: String, context: Dictionary) -> String:
	var messages: Array = []
	var history: Array = context.get("history", [])
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
	_http.request(API_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	var response: Array = await _http.request_completed
	return response


func _parse_response(response: Array) -> String:
	if response.is_empty():
		return ""
	var result_code: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]
	if result_code != OK or response_code != 200:
		push_warning("AnthropicProvider: request failed (result=%d, http=%d)" % [result_code, response_code])
		return ""
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return ""
	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		return ""
	var data: Dictionary = parsed_data
	var content: Array = data.get("content", [])
	if content.is_empty():
		return ""
	var first_content: Variant = content[0]
	if not first_content is Dictionary:
		return ""
	return str(first_content.get("text", ""))
