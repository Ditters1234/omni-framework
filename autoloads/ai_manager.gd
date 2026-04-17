## AIManager — LLM abstraction layer.
## Reads config.json ai.provider and routes all generation calls
## to the correct backend provider.
## Modders access AI via: AIManager.generate_async(prompt, context)
## Always guard with: if not AIManager.is_available(): return
extends Node

class_name OmniAIManager

const PROVIDER_OPENAI_COMPATIBLE := "openai_compatible"
const PROVIDER_ANTHROPIC := "anthropic"
const PROVIDER_NOBODYWHO := "nobodywho"
const PROVIDER_DISABLED := "disabled"

var _provider: Node = null
var _provider_type: String = PROVIDER_DISABLED

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	return


## Called after DataManager is loaded so we can read config.
## Instantiates and configures the appropriate provider.
func initialize() -> void:
	var ai_config_value: Variant = DataManager.config.get("ai", {})
	var ai_config: Dictionary = {}
	if ai_config_value is Dictionary:
		ai_config = ai_config_value
	_provider_type = str(ai_config.get("provider", PROVIDER_DISABLED))

	if _provider:
		remove_child(_provider)
		_provider.queue_free()
		_provider = null

	if _provider_type == PROVIDER_DISABLED:
		return

	_provider = _load_provider(_provider_type)
	if _provider == null:
		_provider_type = PROVIDER_DISABLED
		return

	add_child(_provider)
	if _provider.has_method("initialize"):
		var provider_config := _build_provider_config(ai_config, _provider_type)
		_provider.initialize(provider_config)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if a working AI provider is configured and ready.
func is_available() -> bool:
	if _provider == null or _provider_type == PROVIDER_DISABLED:
		return false
	if _provider.has_method("is_ready"):
		return bool(_provider.call("is_ready"))
	return true


## Returns the active provider type string.
func get_provider_type() -> String:
	return _provider_type


## Generates a response asynchronously. Returns the response string.
## On failure returns an empty string and emits GameEvents.ai_error.
## Always await this call:
##   var response = await AIManager.generate_async(prompt)
func generate_async(prompt: String, context: Dictionary = {}) -> String:
	if not is_available():
		return ""
	return await _provider.generate_async(prompt, context)


## Generates a streaming response. Calls chunk_callback with each text chunk.
## chunk_callback signature: func(chunk: String) -> void
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	if not is_available():
		return
	await _provider.generate_streaming_async(prompt, chunk_callback, context)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Loads and returns the provider script for the given type.
func _load_provider(provider_type: String) -> Node:
	var script_path := ""
	match provider_type:
		PROVIDER_OPENAI_COMPATIBLE:
			script_path = "res://systems/ai/providers/openai_provider.gd"
		PROVIDER_ANTHROPIC:
			script_path = "res://systems/ai/providers/anthropic_provider.gd"
		PROVIDER_NOBODYWHO:
			script_path = "res://systems/ai/providers/nobodywho_provider.gd"
		_:
			return null

	var script: GDScript = load(script_path)
	if script == null:
		return null
	return script.new()


func _build_provider_config(ai_config: Dictionary, provider_type: String) -> Dictionary:
	var result: Dictionary = {}
	for key_value in ai_config.keys():
		var key := str(key_value)
		if key == "provider":
			continue
		var value: Variant = ai_config.get(key_value, null)
		if value is Dictionary and (
				key == PROVIDER_OPENAI_COMPATIBLE
				or key == PROVIDER_ANTHROPIC
				or key == PROVIDER_NOBODYWHO):
			continue
		result[key] = value

	var nested_config_value: Variant = ai_config.get(provider_type, {})
	if nested_config_value is Dictionary:
		var nested_config: Dictionary = nested_config_value
		for key_value in nested_config.keys():
			result[str(key_value)] = nested_config.get(key_value, null)
	return result
