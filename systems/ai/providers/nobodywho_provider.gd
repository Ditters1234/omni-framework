## NobodyWhoProvider — Embedded local LLM via the NobodyWho GDExtension.
## No server required. The model runs in-process.
## Model file must be a .gguf placed at the configured path (gitignored).
##
## Config block (config.json):
## "ai": {
##   "provider": "nobodywho",
##   "nobodywho": {
##     "model_path": "res://models/my_model.gguf",
##     "system_prompt": "You are a helpful game character.",
##     "n_ctx": 2048,
##     "max_tokens": 256,
##     "temperature": 0.7
##   }
## }
##
## NOTE: NobodyWho API may evolve — check addons/nobodywho/ for latest usage.
extends Node

class_name NobodyWhoProvider

const DEFAULT_CTX := 2048
const DEFAULT_MAX_TOKENS := 256
const DEFAULT_TEMPERATURE := 0.7

var _model_path: String = ""
var _system_prompt: String = ""
var _n_ctx: int = DEFAULT_CTX
var _max_tokens: int = DEFAULT_MAX_TOKENS
var _temperature: float = DEFAULT_TEMPERATURE

## NobodyWho model node — type depends on the installed extension version.
var _model_node: Node = null
var _is_ready: bool = false
var _last_error: String = ""

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass


## Configures and loads the model from the config.json ai.nobodywho block.
func initialize(provider_config: Dictionary) -> void:
	_model_path    = str(provider_config.get("model_path", ""))
	_system_prompt = str(provider_config.get("system_prompt", ""))
	_n_ctx         = int(provider_config.get("n_ctx",         DEFAULT_CTX))
	_max_tokens    = int(provider_config.get("max_tokens",    DEFAULT_MAX_TOKENS))
	_temperature   = float(provider_config.get("temperature", DEFAULT_TEMPERATURE))
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
	}


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

## Generates a response using the embedded model.
func generate_async(prompt: String, context: Dictionary = {}) -> String:
	if not _is_ready:
		if _last_error.is_empty():
			_last_error = "NobodyWhoProvider: model not ready."
		push_warning(_last_error)
		return ""
	_last_error = ""
	return await _run_inference(prompt, context)


## Streaming generation — calls chunk_callback with each text token.
func generate_streaming_async(
		prompt: String,
		chunk_callback: Callable,
		context: Dictionary = {}) -> void:
	# TODO: hook into NobodyWho's token streaming callback when available.
	var result := await generate_async(prompt, context)
	if not result.is_empty():
		chunk_callback.call(result)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_model() -> void:
	# TODO: implement using the NobodyWho GDExtension API.
	# Check addons/nobodywho/ for node types and method names.
	_is_ready = false
	_last_error = "NobodyWhoProvider: _load_model() is not implemented yet."
	push_warning(_last_error)


func _run_inference(prompt: String, context: Dictionary) -> String:
	# TODO: implement using the NobodyWho GDExtension API.
	_last_error = "NobodyWhoProvider: _run_inference() is not implemented yet."
	push_warning(_last_error)
	return ""
