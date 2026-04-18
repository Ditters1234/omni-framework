extends RefCounted

class_name OmniAppSettings

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_DISPLAY := "display"
const SECTION_AI := "ai"
const AUDIO_MASTER_VOLUME := "master_volume"
const AUDIO_MUSIC_VOLUME := "music_volume"
const AUDIO_SFX_VOLUME := "sfx_volume"
const DISPLAY_WINDOW_MODE := "window_mode"
const DISPLAY_WINDOW_WIDTH := "window_width"
const DISPLAY_WINDOW_HEIGHT := "window_height"
const AI_ENABLED := "enabled"
const AI_PROVIDER := "provider"
const AI_ENDPOINT := "endpoint"
const AI_API_KEY := "api_key"
const AI_MODEL := "model"
const AI_SYSTEM_PROMPT := "system_prompt"
const AI_MAX_TOKENS := "max_tokens"
const AI_TEMPERATURE := "temperature"
const AI_MODEL_PATH := "model_path"
const AI_CONTEXT_WINDOW := "n_ctx"
const AI_PROVIDER_DISABLED := "disabled"
const AI_PROVIDER_OPENAI_COMPATIBLE := "openai_compatible"
const AI_PROVIDER_ANTHROPIC := "anthropic"
const AI_PROVIDER_NOBODYWHO := "nobodywho"
const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_MODE_MAXIMIZED := "maximized"
const DEFAULT_WINDOW_WIDTH := 1280
const DEFAULT_WINDOW_HEIGHT := 720
const DEFAULT_AI_ENDPOINT := "http://localhost:11434/v1/chat/completions"
const DEFAULT_AI_MODEL := "llama3"
const DEFAULT_AI_MAX_TOKENS := 256
const DEFAULT_AI_TEMPERATURE := 0.7
const DEFAULT_AI_CONTEXT_WINDOW := 2048


static func get_default_settings() -> Dictionary:
	return {
		SECTION_AUDIO: {
			AUDIO_MASTER_VOLUME: 1.0,
			AUDIO_MUSIC_VOLUME: 1.0,
			AUDIO_SFX_VOLUME: 1.0,
		},
		SECTION_DISPLAY: {
			DISPLAY_WINDOW_MODE: WINDOW_MODE_WINDOWED,
			DISPLAY_WINDOW_WIDTH: DEFAULT_WINDOW_WIDTH,
			DISPLAY_WINDOW_HEIGHT: DEFAULT_WINDOW_HEIGHT,
		},
		SECTION_AI: {
			AI_ENABLED: false,
			AI_PROVIDER: AI_PROVIDER_DISABLED,
			AI_ENDPOINT: DEFAULT_AI_ENDPOINT,
			AI_API_KEY: "",
			AI_MODEL: DEFAULT_AI_MODEL,
			AI_SYSTEM_PROMPT: "",
			AI_MAX_TOKENS: DEFAULT_AI_MAX_TOKENS,
			AI_TEMPERATURE: DEFAULT_AI_TEMPERATURE,
			AI_MODEL_PATH: "",
			AI_CONTEXT_WINDOW: DEFAULT_AI_CONTEXT_WINDOW,
		},
	}


static func load_settings() -> Dictionary:
	var normalized_defaults := normalize_settings(get_default_settings())
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error != OK:
		return normalized_defaults
	return normalize_settings({
		SECTION_AUDIO: {
			AUDIO_MASTER_VOLUME: config.get_value(SECTION_AUDIO, AUDIO_MASTER_VOLUME, 1.0),
			AUDIO_MUSIC_VOLUME: config.get_value(SECTION_AUDIO, AUDIO_MUSIC_VOLUME, 1.0),
			AUDIO_SFX_VOLUME: config.get_value(SECTION_AUDIO, AUDIO_SFX_VOLUME, 1.0),
		},
		SECTION_DISPLAY: {
			DISPLAY_WINDOW_MODE: config.get_value(SECTION_DISPLAY, DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED),
			DISPLAY_WINDOW_WIDTH: config.get_value(SECTION_DISPLAY, DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH),
			DISPLAY_WINDOW_HEIGHT: config.get_value(SECTION_DISPLAY, DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT),
		},
		SECTION_AI: {
			AI_ENABLED: config.get_value(SECTION_AI, AI_ENABLED, false),
			AI_PROVIDER: config.get_value(SECTION_AI, AI_PROVIDER, AI_PROVIDER_DISABLED),
			AI_ENDPOINT: config.get_value(SECTION_AI, AI_ENDPOINT, DEFAULT_AI_ENDPOINT),
			AI_API_KEY: config.get_value(SECTION_AI, AI_API_KEY, ""),
			AI_MODEL: config.get_value(SECTION_AI, AI_MODEL, DEFAULT_AI_MODEL),
			AI_SYSTEM_PROMPT: config.get_value(SECTION_AI, AI_SYSTEM_PROMPT, ""),
			AI_MAX_TOKENS: config.get_value(SECTION_AI, AI_MAX_TOKENS, DEFAULT_AI_MAX_TOKENS),
			AI_TEMPERATURE: config.get_value(SECTION_AI, AI_TEMPERATURE, DEFAULT_AI_TEMPERATURE),
			AI_MODEL_PATH: config.get_value(SECTION_AI, AI_MODEL_PATH, ""),
			AI_CONTEXT_WINDOW: config.get_value(SECTION_AI, AI_CONTEXT_WINDOW, DEFAULT_AI_CONTEXT_WINDOW),
		},
	})


static func save_settings(settings: Dictionary) -> int:
	var normalized := normalize_settings(settings)
	var config := ConfigFile.new()
	var audio := _get_section_dict(normalized, SECTION_AUDIO)
	var display := _get_section_dict(normalized, SECTION_DISPLAY)
	var ai := _get_section_dict(normalized, SECTION_AI)
	config.set_value(SECTION_AUDIO, AUDIO_MASTER_VOLUME, float(audio.get(AUDIO_MASTER_VOLUME, 1.0)))
	config.set_value(SECTION_AUDIO, AUDIO_MUSIC_VOLUME, float(audio.get(AUDIO_MUSIC_VOLUME, 1.0)))
	config.set_value(SECTION_AUDIO, AUDIO_SFX_VOLUME, float(audio.get(AUDIO_SFX_VOLUME, 1.0)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_MODE, str(display.get(DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_WIDTH, int(display.get(DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_HEIGHT, int(display.get(DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT)))
	config.set_value(SECTION_AI, AI_ENABLED, bool(ai.get(AI_ENABLED, false)))
	config.set_value(SECTION_AI, AI_PROVIDER, str(ai.get(AI_PROVIDER, AI_PROVIDER_DISABLED)))
	config.set_value(SECTION_AI, AI_ENDPOINT, str(ai.get(AI_ENDPOINT, DEFAULT_AI_ENDPOINT)))
	config.set_value(SECTION_AI, AI_API_KEY, str(ai.get(AI_API_KEY, "")))
	config.set_value(SECTION_AI, AI_MODEL, str(ai.get(AI_MODEL, DEFAULT_AI_MODEL)))
	config.set_value(SECTION_AI, AI_SYSTEM_PROMPT, str(ai.get(AI_SYSTEM_PROMPT, "")))
	config.set_value(SECTION_AI, AI_MAX_TOKENS, int(ai.get(AI_MAX_TOKENS, DEFAULT_AI_MAX_TOKENS)))
	config.set_value(SECTION_AI, AI_TEMPERATURE, float(ai.get(AI_TEMPERATURE, DEFAULT_AI_TEMPERATURE)))
	config.set_value(SECTION_AI, AI_MODEL_PATH, str(ai.get(AI_MODEL_PATH, "")))
	config.set_value(SECTION_AI, AI_CONTEXT_WINDOW, int(ai.get(AI_CONTEXT_WINDOW, DEFAULT_AI_CONTEXT_WINDOW)))
	return config.save(SETTINGS_PATH)


static func normalize_settings(settings: Dictionary) -> Dictionary:
	var defaults := get_default_settings()
	var audio_defaults := _get_section_dict(defaults, SECTION_AUDIO)
	var display_defaults := _get_section_dict(defaults, SECTION_DISPLAY)
	var ai_defaults := _get_section_dict(defaults, SECTION_AI)
	var audio_input := _get_section_dict(settings, SECTION_AUDIO)
	var display_input := _get_section_dict(settings, SECTION_DISPLAY)
	var ai_input := _get_section_dict(settings, SECTION_AI)
	var normalized_window_mode := _normalize_window_mode(
		display_input.get(DISPLAY_WINDOW_MODE, display_defaults.get(DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED))
	)
	var normalized_ai_provider := _normalize_ai_provider(
		ai_input.get(AI_PROVIDER, ai_defaults.get(AI_PROVIDER, AI_PROVIDER_DISABLED))
	)
	return {
		SECTION_AUDIO: {
			AUDIO_MASTER_VOLUME: _normalize_linear_float(
				audio_input.get(AUDIO_MASTER_VOLUME, audio_defaults.get(AUDIO_MASTER_VOLUME, 1.0)),
				float(audio_defaults.get(AUDIO_MASTER_VOLUME, 1.0))
			),
			AUDIO_MUSIC_VOLUME: _normalize_linear_float(
				audio_input.get(AUDIO_MUSIC_VOLUME, audio_defaults.get(AUDIO_MUSIC_VOLUME, 1.0)),
				float(audio_defaults.get(AUDIO_MUSIC_VOLUME, 1.0))
			),
			AUDIO_SFX_VOLUME: _normalize_linear_float(
				audio_input.get(AUDIO_SFX_VOLUME, audio_defaults.get(AUDIO_SFX_VOLUME, 1.0)),
				float(audio_defaults.get(AUDIO_SFX_VOLUME, 1.0))
			),
		},
		SECTION_DISPLAY: {
			DISPLAY_WINDOW_MODE: normalized_window_mode,
			DISPLAY_WINDOW_WIDTH: _normalize_window_dimension(
				display_input.get(DISPLAY_WINDOW_WIDTH, display_defaults.get(DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH)),
				int(display_defaults.get(DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH))
			),
			DISPLAY_WINDOW_HEIGHT: _normalize_window_dimension(
				display_input.get(DISPLAY_WINDOW_HEIGHT, display_defaults.get(DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT)),
				int(display_defaults.get(DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT))
			),
		},
		SECTION_AI: {
			AI_ENABLED: bool(ai_input.get(AI_ENABLED, ai_defaults.get(AI_ENABLED, false))) and normalized_ai_provider != AI_PROVIDER_DISABLED,
			AI_PROVIDER: normalized_ai_provider,
			AI_ENDPOINT: _normalize_text(
				ai_input.get(AI_ENDPOINT, ai_defaults.get(AI_ENDPOINT, DEFAULT_AI_ENDPOINT)),
				str(ai_defaults.get(AI_ENDPOINT, DEFAULT_AI_ENDPOINT))
			),
			AI_API_KEY: str(ai_input.get(AI_API_KEY, ai_defaults.get(AI_API_KEY, ""))),
			AI_MODEL: _normalize_text(
				ai_input.get(AI_MODEL, ai_defaults.get(AI_MODEL, DEFAULT_AI_MODEL)),
				str(ai_defaults.get(AI_MODEL, DEFAULT_AI_MODEL))
			),
			AI_SYSTEM_PROMPT: str(ai_input.get(AI_SYSTEM_PROMPT, ai_defaults.get(AI_SYSTEM_PROMPT, ""))).strip_edges(),
			AI_MAX_TOKENS: _normalize_positive_int(
				ai_input.get(AI_MAX_TOKENS, ai_defaults.get(AI_MAX_TOKENS, DEFAULT_AI_MAX_TOKENS)),
				int(ai_defaults.get(AI_MAX_TOKENS, DEFAULT_AI_MAX_TOKENS))
			),
			AI_TEMPERATURE: _normalize_linear_float(
				ai_input.get(AI_TEMPERATURE, ai_defaults.get(AI_TEMPERATURE, DEFAULT_AI_TEMPERATURE)),
				float(ai_defaults.get(AI_TEMPERATURE, DEFAULT_AI_TEMPERATURE))
			),
			AI_MODEL_PATH: str(ai_input.get(AI_MODEL_PATH, ai_defaults.get(AI_MODEL_PATH, ""))).strip_edges(),
			AI_CONTEXT_WINDOW: _normalize_positive_int(
				ai_input.get(AI_CONTEXT_WINDOW, ai_defaults.get(AI_CONTEXT_WINDOW, DEFAULT_AI_CONTEXT_WINDOW)),
				int(ai_defaults.get(AI_CONTEXT_WINDOW, DEFAULT_AI_CONTEXT_WINDOW))
			),
		},
	}


static func apply_settings(window: Window, settings: Dictionary) -> void:
	var normalized := normalize_settings(settings)
	var audio := _get_section_dict(normalized, SECTION_AUDIO)
	if AudioManager != null:
		AudioManager.set_master_volume(float(audio.get(AUDIO_MASTER_VOLUME, 1.0)))
		AudioManager.set_music_volume(float(audio.get(AUDIO_MUSIC_VOLUME, 1.0)))
		AudioManager.set_sfx_volume(float(audio.get(AUDIO_SFX_VOLUME, 1.0)))

	if window == null:
		return

	var display := _get_section_dict(normalized, SECTION_DISPLAY)
	var window_mode := str(display.get(DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED))
	match window_mode:
		WINDOW_MODE_FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		WINDOW_MODE_MAXIMIZED:
			window.mode = Window.MODE_MAXIMIZED
		_:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(
				int(display.get(DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH)),
				int(display.get(DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT))
			)


static func get_ai_settings(settings: Dictionary = {}) -> Dictionary:
	var normalized := normalize_settings(settings if not settings.is_empty() else load_settings())
	return _get_section_dict(normalized, SECTION_AI)


static func _get_section_dict(settings: Dictionary, section_name: String) -> Dictionary:
	var section_value: Variant = settings.get(section_name, {})
	if section_value is Dictionary:
		var section_dict: Dictionary = section_value
		return section_dict.duplicate(true)
	return {}


static func _normalize_linear_float(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return clampf(fallback, 0.0, 1.0)


static func _normalize_window_dimension(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		var dimension := int(value)
		if dimension >= 640:
			return dimension
	return fallback


static func _normalize_window_mode(value: Variant) -> String:
	var mode := str(value)
	match mode:
		WINDOW_MODE_FULLSCREEN, WINDOW_MODE_MAXIMIZED:
			return mode
		_:
			return WINDOW_MODE_WINDOWED


static func _normalize_ai_provider(value: Variant) -> String:
	var provider := str(value)
	match provider:
		AI_PROVIDER_OPENAI_COMPATIBLE, AI_PROVIDER_ANTHROPIC, AI_PROVIDER_NOBODYWHO:
			return provider
		_:
			return AI_PROVIDER_DISABLED


static func _normalize_positive_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		var normalized := int(value)
		if normalized > 0:
			return normalized
	return maxi(fallback, 1)


static func _normalize_text(value: Variant, fallback: String) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return fallback
	return normalized
