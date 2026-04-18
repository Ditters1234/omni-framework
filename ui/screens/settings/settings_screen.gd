extends Control

const APP_SETTINGS := preload("res://core/app_settings.gd")
const SCREEN_MAIN_MENU := "main_menu"
const WINDOW_MODE_ORDER := [
	APP_SETTINGS.WINDOW_MODE_WINDOWED,
	APP_SETTINGS.WINDOW_MODE_FULLSCREEN,
	APP_SETTINGS.WINDOW_MODE_MAXIMIZED,
]
const WINDOW_MODE_LABELS := {
	APP_SETTINGS.WINDOW_MODE_WINDOWED: "Windowed",
	APP_SETTINGS.WINDOW_MODE_FULLSCREEN: "Fullscreen",
	APP_SETTINGS.WINDOW_MODE_MAXIMIZED: "Maximized",
}
const RESOLUTION_PRESETS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SubtitleLabel
@onready var _master_slider: HSlider = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/MasterSlider
@onready var _master_value_label: Label = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/MasterValueLabel
@onready var _music_slider: HSlider = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/MusicSlider
@onready var _music_value_label: Label = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/MusicValueLabel
@onready var _sfx_slider: HSlider = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/SfxSlider
@onready var _sfx_value_label: Label = $MarginContainer/PanelContainer/VBoxContainer/AudioGrid/SfxValueLabel
@onready var _window_mode_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/DisplayGrid/WindowModeButton
@onready var _resolution_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/DisplayGrid/ResolutionButton
@onready var _ai_info_label: Label = $MarginContainer/PanelContainer/VBoxContainer/AiInfoLabel
@onready var _save_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/SaveButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel

var _settings: Dictionary = {}
var _is_initializing: bool = false
var _is_dirty: bool = false


func initialize(_params: Dictionary = {}) -> void:
	_ensure_option_items()
	_load_settings_from_disk()


func _ready() -> void:
	_ensure_option_items()
	_load_settings_from_disk()


func on_route_revealed() -> void:
	_update_ai_info()


func _ensure_option_items() -> void:
	if _window_mode_button.item_count == 0:
		for window_mode_value in WINDOW_MODE_ORDER:
			var window_mode := str(window_mode_value)
			_window_mode_button.add_item(str(WINDOW_MODE_LABELS.get(window_mode, window_mode)))
	if _resolution_button.item_count == 0:
		for preset_value in RESOLUTION_PRESETS:
			var preset: Vector2i = preset_value
			_resolution_button.add_item("%d x %d" % [preset.x, preset.y])


func _load_settings_from_disk() -> void:
	_settings = APP_SETTINGS.load_settings()
	_is_initializing = true
	_apply_settings_to_controls()
	_is_initializing = false
	_is_dirty = false
	_update_dirty_state()
	_update_ai_info()
	_status_label.text = "Settings loaded from user://settings.cfg."


func _apply_settings_to_controls() -> void:
	var audio := _get_section_dict(_settings, APP_SETTINGS.SECTION_AUDIO)
	var display := _get_section_dict(_settings, APP_SETTINGS.SECTION_DISPLAY)
	_master_slider.value = float(audio.get(APP_SETTINGS.AUDIO_MASTER_VOLUME, 1.0))
	_music_slider.value = float(audio.get(APP_SETTINGS.AUDIO_MUSIC_VOLUME, 1.0))
	_sfx_slider.value = float(audio.get(APP_SETTINGS.AUDIO_SFX_VOLUME, 1.0))
	_master_value_label.text = _format_percentage(_master_slider.value)
	_music_value_label.text = _format_percentage(_music_slider.value)
	_sfx_value_label.text = _format_percentage(_sfx_slider.value)

	var window_mode := str(display.get(APP_SETTINGS.DISPLAY_WINDOW_MODE, APP_SETTINGS.WINDOW_MODE_WINDOWED))
	var window_mode_index := WINDOW_MODE_ORDER.find(window_mode)
	_window_mode_button.select(maxi(window_mode_index, 0))

	var resolution := Vector2i(
		int(display.get(APP_SETTINGS.DISPLAY_WINDOW_WIDTH, APP_SETTINGS.DEFAULT_WINDOW_WIDTH)),
		int(display.get(APP_SETTINGS.DISPLAY_WINDOW_HEIGHT, APP_SETTINGS.DEFAULT_WINDOW_HEIGHT))
	)
	var resolution_index := _find_resolution_index(resolution)
	if resolution_index < 0:
		resolution_index = 0
	_resolution_button.select(resolution_index)
	_title_label.text = "Settings"
	_subtitle_label.text = "Engine-owned application settings stored outside the mod data pipeline."


func _collect_settings_from_controls() -> Dictionary:
	var selected_mode := APP_SETTINGS.WINDOW_MODE_WINDOWED
	var selected_mode_index := _window_mode_button.get_selected_id()
	if selected_mode_index >= 0 and selected_mode_index < WINDOW_MODE_ORDER.size():
		selected_mode = str(WINDOW_MODE_ORDER[selected_mode_index])

	var resolution := RESOLUTION_PRESETS[0]
	var resolution_index := _resolution_button.get_selected_id()
	if resolution_index >= 0 and resolution_index < RESOLUTION_PRESETS.size():
		var resolution_value: Variant = RESOLUTION_PRESETS[resolution_index]
		if resolution_value is Vector2i:
			resolution = resolution_value

	return APP_SETTINGS.normalize_settings({
		APP_SETTINGS.SECTION_AUDIO: {
			APP_SETTINGS.AUDIO_MASTER_VOLUME: _master_slider.value,
			APP_SETTINGS.AUDIO_MUSIC_VOLUME: _music_slider.value,
			APP_SETTINGS.AUDIO_SFX_VOLUME: _sfx_slider.value,
		},
		APP_SETTINGS.SECTION_DISPLAY: {
			APP_SETTINGS.DISPLAY_WINDOW_MODE: selected_mode,
			APP_SETTINGS.DISPLAY_WINDOW_WIDTH: resolution.x,
			APP_SETTINGS.DISPLAY_WINDOW_HEIGHT: resolution.y,
		},
	})


func _preview_current_settings() -> void:
	_settings = _collect_settings_from_controls()
	_master_value_label.text = _format_percentage(_master_slider.value)
	_music_value_label.text = _format_percentage(_music_slider.value)
	_sfx_value_label.text = _format_percentage(_sfx_slider.value)
	APP_SETTINGS.apply_settings(get_window(), _settings)
	_is_dirty = true
	_update_dirty_state()
	_status_label.text = "Previewing changes. Save to persist them."


func _persist_settings() -> bool:
	_settings = _collect_settings_from_controls()
	var save_error := APP_SETTINGS.save_settings(_settings)
	if save_error != OK:
		_status_label.text = "Unable to save settings: %s" % error_string(save_error)
		return false
	APP_SETTINGS.apply_settings(get_window(), _settings)
	_is_dirty = false
	_update_dirty_state()
	_status_label.text = "Settings saved."
	return true


func _update_dirty_state() -> void:
	_save_button.text = "Save*" if _is_dirty else "Save"


func _update_ai_info() -> void:
	var snapshot := AIManager.get_debug_snapshot()
	var provider_name := str(snapshot.get("provider_name", AIManager.PROVIDER_DISABLED))
	var available := bool(snapshot.get("available", false))
	var last_error := str(snapshot.get("last_error", ""))
	var status_text := "Available" if available else "Unavailable"
	if not last_error.is_empty():
		status_text += " (%s)" % last_error
	_ai_info_label.text = "AI Provider: %s\nStatus: %s" % [provider_name, status_text]


func _get_section_dict(source: Dictionary, section_name: String) -> Dictionary:
	var section_value: Variant = source.get(section_name, {})
	if section_value is Dictionary:
		var section_dict: Dictionary = section_value
		return section_dict.duplicate(true)
	return {}


func _format_percentage(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func _find_resolution_index(target_resolution: Vector2i) -> int:
	for index in range(RESOLUTION_PRESETS.size()):
		var preset_value: Variant = RESOLUTION_PRESETS[index]
		if not preset_value is Vector2i:
			continue
		var preset: Vector2i = preset_value
		if preset == target_resolution:
			return index
	return -1


func _on_master_slider_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_music_slider_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_sfx_slider_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_window_mode_button_item_selected(_index: int) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_resolution_button_item_selected(_index: int) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_save_button_pressed() -> void:
	_persist_settings()


func _on_back_button_pressed() -> void:
	if _is_dirty and not _persist_settings():
		return
	if UIRouter.stack_depth() > 1:
		UIRouter.pop()
		return
	UIRouter.replace_all(SCREEN_MAIN_MENU)
