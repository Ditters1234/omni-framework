extends RefCounted

class_name OmniAppSettings

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_DISPLAY := "display"
const AUDIO_MASTER_VOLUME := "master_volume"
const AUDIO_MUSIC_VOLUME := "music_volume"
const AUDIO_SFX_VOLUME := "sfx_volume"
const DISPLAY_WINDOW_MODE := "window_mode"
const DISPLAY_WINDOW_WIDTH := "window_width"
const DISPLAY_WINDOW_HEIGHT := "window_height"
const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_MODE_MAXIMIZED := "maximized"
const DEFAULT_WINDOW_WIDTH := 1280
const DEFAULT_WINDOW_HEIGHT := 720


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
	})


static func save_settings(settings: Dictionary) -> int:
	var normalized := normalize_settings(settings)
	var config := ConfigFile.new()
	var audio := _get_section_dict(normalized, SECTION_AUDIO)
	var display := _get_section_dict(normalized, SECTION_DISPLAY)
	config.set_value(SECTION_AUDIO, AUDIO_MASTER_VOLUME, float(audio.get(AUDIO_MASTER_VOLUME, 1.0)))
	config.set_value(SECTION_AUDIO, AUDIO_MUSIC_VOLUME, float(audio.get(AUDIO_MUSIC_VOLUME, 1.0)))
	config.set_value(SECTION_AUDIO, AUDIO_SFX_VOLUME, float(audio.get(AUDIO_SFX_VOLUME, 1.0)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_MODE, str(display.get(DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_WIDTH, int(display.get(DISPLAY_WINDOW_WIDTH, DEFAULT_WINDOW_WIDTH)))
	config.set_value(SECTION_DISPLAY, DISPLAY_WINDOW_HEIGHT, int(display.get(DISPLAY_WINDOW_HEIGHT, DEFAULT_WINDOW_HEIGHT)))
	return config.save(SETTINGS_PATH)


static func normalize_settings(settings: Dictionary) -> Dictionary:
	var defaults := get_default_settings()
	var audio_defaults := _get_section_dict(defaults, SECTION_AUDIO)
	var display_defaults := _get_section_dict(defaults, SECTION_DISPLAY)
	var audio_input := _get_section_dict(settings, SECTION_AUDIO)
	var display_input := _get_section_dict(settings, SECTION_DISPLAY)
	var normalized_window_mode := _normalize_window_mode(
		display_input.get(DISPLAY_WINDOW_MODE, display_defaults.get(DISPLAY_WINDOW_MODE, WINDOW_MODE_WINDOWED))
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
