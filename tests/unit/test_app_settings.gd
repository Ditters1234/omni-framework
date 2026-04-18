extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")

var _original_master_volume: float = 1.0
var _original_music_volume: float = 1.0
var _original_sfx_volume: float = 1.0
var _original_window_mode: int = Window.MODE_WINDOWED
var _original_window_size: Vector2i = Vector2i(1280, 720)


func before_each() -> void:
	_delete_settings_file()
	_original_master_volume = AudioManager.get_master_volume()
	_original_music_volume = AudioManager.get_music_volume()
	_original_sfx_volume = AudioManager.get_sfx_volume()
	var window: Window = get_tree().root
	_original_window_mode = window.mode
	_original_window_size = window.size


func after_each() -> void:
	AudioManager.set_master_volume(_original_master_volume)
	AudioManager.set_music_volume(_original_music_volume)
	AudioManager.set_sfx_volume(_original_sfx_volume)
	var window: Window = get_tree().root
	window.mode = _original_window_mode
	window.size = _original_window_size
	_delete_settings_file()


func test_load_settings_returns_defaults_when_file_is_missing() -> void:
	var settings := APP_SETTINGS.load_settings()

	assert_eq_deep(settings, APP_SETTINGS.get_default_settings())


func test_save_and_load_settings_round_trip_normalizes_values() -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AUDIO: {
			APP_SETTINGS.AUDIO_MASTER_VOLUME: 1.5,
			APP_SETTINGS.AUDIO_MUSIC_VOLUME: 0.25,
			APP_SETTINGS.AUDIO_SFX_VOLUME: -2.0,
		},
		APP_SETTINGS.SECTION_DISPLAY: {
			APP_SETTINGS.DISPLAY_WINDOW_MODE: APP_SETTINGS.WINDOW_MODE_WINDOWED,
			APP_SETTINGS.DISPLAY_WINDOW_WIDTH: 1600,
			APP_SETTINGS.DISPLAY_WINDOW_HEIGHT: 900,
		},
	})

	assert_eq(save_error, OK)

	var loaded_settings := APP_SETTINGS.load_settings()
	var audio := _get_section_dict(loaded_settings, APP_SETTINGS.SECTION_AUDIO)
	var display := _get_section_dict(loaded_settings, APP_SETTINGS.SECTION_DISPLAY)

	assert_almost_eq(float(audio.get(APP_SETTINGS.AUDIO_MASTER_VOLUME, 0.0)), 1.0, 0.001)
	assert_almost_eq(float(audio.get(APP_SETTINGS.AUDIO_MUSIC_VOLUME, 0.0)), 0.25, 0.001)
	assert_almost_eq(float(audio.get(APP_SETTINGS.AUDIO_SFX_VOLUME, 1.0)), 0.0, 0.001)
	assert_eq(str(display.get(APP_SETTINGS.DISPLAY_WINDOW_MODE, "")), APP_SETTINGS.WINDOW_MODE_WINDOWED)
	assert_eq(int(display.get(APP_SETTINGS.DISPLAY_WINDOW_WIDTH, 0)), 1600)
	assert_eq(int(display.get(APP_SETTINGS.DISPLAY_WINDOW_HEIGHT, 0)), 900)


func test_apply_settings_updates_audio_manager_and_window_mode() -> void:
	var window: Window = get_tree().root
	var settings := {
		APP_SETTINGS.SECTION_AUDIO: {
			APP_SETTINGS.AUDIO_MASTER_VOLUME: 0.4,
			APP_SETTINGS.AUDIO_MUSIC_VOLUME: 0.5,
			APP_SETTINGS.AUDIO_SFX_VOLUME: 0.6,
		},
		APP_SETTINGS.SECTION_DISPLAY: {
			APP_SETTINGS.DISPLAY_WINDOW_MODE: APP_SETTINGS.WINDOW_MODE_WINDOWED,
			APP_SETTINGS.DISPLAY_WINDOW_WIDTH: 1600,
			APP_SETTINGS.DISPLAY_WINDOW_HEIGHT: 900,
		},
	}

	APP_SETTINGS.apply_settings(window, settings)

	assert_almost_eq(AudioManager.get_master_volume(), 0.4, 0.001)
	assert_almost_eq(AudioManager.get_music_volume(), 0.5, 0.001)
	assert_almost_eq(AudioManager.get_sfx_volume(), 0.6, 0.001)
	if DisplayServer.get_name() != "headless":
		assert_eq(window.mode, Window.MODE_WINDOWED)
	assert_eq(window.size, Vector2i(1600, 900))


func test_ai_settings_round_trip_normalizes_engine_owned_connection_fields() -> void:
	var save_error := APP_SETTINGS.save_settings({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: true,
			APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE,
			APP_SETTINGS.AI_ENDPOINT: "  http://127.0.0.1:11434/v1/chat/completions  ",
			APP_SETTINGS.AI_API_KEY: "secret",
			APP_SETTINGS.AI_MODEL: "omni-local",
			APP_SETTINGS.AI_SYSTEM_PROMPT: "  Keep it terse.  ",
			APP_SETTINGS.AI_MAX_TOKENS: 0,
			APP_SETTINGS.AI_TEMPERATURE: 1.4,
			APP_SETTINGS.AI_MODEL_PATH: " user://models/test.gguf ",
			APP_SETTINGS.AI_CONTEXT_WINDOW: -5,
		},
	})

	assert_eq(save_error, OK)

	var ai_settings := APP_SETTINGS.get_ai_settings(APP_SETTINGS.load_settings())
	assert_eq(bool(ai_settings.get(APP_SETTINGS.AI_ENABLED, false)), true)
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_PROVIDER, "")), APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE)
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_ENDPOINT, "")), "http://127.0.0.1:11434/v1/chat/completions")
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_API_KEY, "")), "secret")
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_MODEL, "")), "omni-local")
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_SYSTEM_PROMPT, "")), "Keep it terse.")
	assert_eq(int(ai_settings.get(APP_SETTINGS.AI_MAX_TOKENS, 0)), APP_SETTINGS.DEFAULT_AI_MAX_TOKENS)
	assert_almost_eq(float(ai_settings.get(APP_SETTINGS.AI_TEMPERATURE, 0.0)), 1.0, 0.001)
	assert_eq(str(ai_settings.get(APP_SETTINGS.AI_MODEL_PATH, "")), "user://models/test.gguf")
	assert_eq(int(ai_settings.get(APP_SETTINGS.AI_CONTEXT_WINDOW, 0)), APP_SETTINGS.DEFAULT_AI_CONTEXT_WINDOW)


func _delete_settings_file() -> void:
	if not FileAccess.file_exists(APP_SETTINGS.SETTINGS_PATH):
		return
	var absolute_path := ProjectSettings.globalize_path(APP_SETTINGS.SETTINGS_PATH)
	DirAccess.remove_absolute(absolute_path)


func _get_section_dict(source: Dictionary, section_name: String) -> Dictionary:
	var section_value: Variant = source.get(section_name, {})
	if section_value is Dictionary:
		var section: Dictionary = section_value
		return section.duplicate(true)
	return {}
