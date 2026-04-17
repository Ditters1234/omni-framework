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
	pass


## Called after DataManager is loaded so we can read config.
## Instantiates and configures the appropriate provider.
func initialize() -> void:
	var ai_config: Dictionary = DataManager.config.get("ai", {})
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
		_provider.initialize(ai_config)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if a working AI provider is configured and ready.
func is_available() -> bool:
	return _provider != null and _provider_type != PROVIDER_DISABLED


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
