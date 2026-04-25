extends Control

const APP_SETTINGS := preload("res://core/app_settings.gd")
const SCREEN_MAIN_MENU := "main_menu"
const WINDOW_MODE_ORDER := [
	APP_SETTINGS.WINDOW_MODE_WINDOWED,
	APP_SETTINGS.WINDOW_MODE_FULLSCREEN,
	APP_SETTINGS.WINDOW_MODE_MAXIMIZED,
]
const AI_PROVIDER_ORDER := [
	APP_SETTINGS.AI_PROVIDER_DISABLED,
	APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE,
	APP_SETTINGS.AI_PROVIDER_ANTHROPIC,
	APP_SETTINGS.AI_PROVIDER_NOBODYWHO,
]
const WINDOW_MODE_LABELS := {
	APP_SETTINGS.WINDOW_MODE_WINDOWED: "Windowed",
	APP_SETTINGS.WINDOW_MODE_FULLSCREEN: "Fullscreen",
	APP_SETTINGS.WINDOW_MODE_MAXIMIZED: "Maximized",
}
const AI_PROVIDER_LABELS := {
	APP_SETTINGS.AI_PROVIDER_DISABLED: "Disabled",
	APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE: "Server (OpenAI-Compatible)",
	APP_SETTINGS.AI_PROVIDER_ANTHROPIC: "Server (Anthropic)",
	APP_SETTINGS.AI_PROVIDER_NOBODYWHO: "On-Disk Model",
}
const AI_BUTTON_CONNECT := "Connect AI"
const AI_BUTTON_UPDATE := "Update AI"
const AI_BUTTON_DISCONNECT := "Disconnect AI"
const RESOLUTION_PRESETS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var _title_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/SubtitleLabel
@onready var _master_slider: HSlider = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/MasterSlider
@onready var _master_value_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/MasterValueLabel
@onready var _music_slider: HSlider = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/MusicSlider
@onready var _music_value_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/MusicValueLabel
@onready var _sfx_slider: HSlider = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/SfxSlider
@onready var _sfx_value_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/SfxValueLabel
@onready var _window_mode_button: OptionButton = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/DisplayGrid/WindowModeButton
@onready var _resolution_button: OptionButton = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/DisplayGrid/ResolutionButton
@onready var _ai_provider_button: OptionButton = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiProviderButton
@onready var _ai_endpoint_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiEndpointLabel
@onready var _ai_endpoint_edit: LineEdit = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiEndpointEdit
@onready var _ai_api_key_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiApiKeyLabel
@onready var _ai_api_key_edit: LineEdit = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiApiKeyEdit
@onready var _ai_model_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiModelLabel
@onready var _ai_model_edit: LineEdit = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiModelEdit
@onready var _ai_model_path_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiModelPathLabel
@onready var _ai_model_path_edit: LineEdit = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiModelPathEdit
@onready var _ai_system_prompt_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiSystemPromptLabel
@onready var _ai_system_prompt_edit: LineEdit = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiSystemPromptEdit
@onready var _ai_max_tokens_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiMaxTokensLabel
@onready var _ai_max_tokens_spinbox: SpinBox = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiMaxTokensSpinBox
@onready var _ai_temperature_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiTemperatureLabel
@onready var _ai_temperature_spinbox: SpinBox = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiTemperatureSpinBox
@onready var _ai_context_window_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiContextWindowLabel
@onready var _ai_context_window_spinbox: SpinBox = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiContextWindowSpinBox
@onready var _ai_chat_history_window_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiChatHistoryWindowLabel
@onready var _ai_chat_history_window_spinbox: SpinBox = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiChatHistoryWindowSpinBox
@onready var _ai_streaming_speed_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiStreamingSpeedLabel
@onready var _ai_streaming_speed_spinbox: SpinBox = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiStreamingSpeedSpinBox
@onready var _ai_world_gen_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiWorldGenLabel
@onready var _ai_world_gen_toggle: CheckButton = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiWorldGenToggle
@onready var _ai_hint_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiHintLabel
@onready var _ai_info_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiInfoLabel
@onready var _connect_ai_button: Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiButtonRow/ConnectAiButton
@onready var _save_button: Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/ButtonRow/SaveButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/StatusLabel

var _settings: Dictionary = {}
var _persisted_settings: Dictionary = {}
var _is_initializing: bool = false
var _is_dirty: bool = false
var _last_debug_snapshot: Dictionary = {}
var _last_connected_ai_settings: Dictionary = {}


func initialize(_params: Dictionary = {}) -> void:
	_ensure_option_items()
	_load_settings_from_disk()


func _ready() -> void:
	_ensure_option_items()
	_load_settings_from_disk()
	call_deferred("_grab_default_focus")


func on_route_revealed() -> void:
	_update_ai_info()
	call_deferred("_grab_default_focus")


func _ensure_option_items() -> void:
	if _window_mode_button.item_count == 0:
		for window_mode_value in WINDOW_MODE_ORDER:
			var window_mode := str(window_mode_value)
			_window_mode_button.add_item(str(WINDOW_MODE_LABELS.get(window_mode, window_mode)))
	if _resolution_button.item_count == 0:
		for preset_value in RESOLUTION_PRESETS:
			var preset: Vector2i = preset_value
			_resolution_button.add_item("%d x %d" % [preset.x, preset.y])
	if _ai_provider_button.item_count == 0:
		for provider_value in AI_PROVIDER_ORDER:
			var provider := str(provider_value)
			_ai_provider_button.add_item(str(AI_PROVIDER_LABELS.get(provider, provider)))


func _load_settings_from_disk() -> void:
	_settings = APP_SETTINGS.load_settings()
	_persisted_settings = _settings.duplicate(true)
	_is_initializing = true
	_apply_settings_to_controls()
	_is_initializing = false
	_is_dirty = false
	_update_connected_ai_settings_from_manager()
	_update_dirty_state()
	_update_ai_info()
	_status_label.text = "Settings loaded from user://settings.cfg."
	_capture_debug_snapshot()


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
	var ai := APP_SETTINGS.get_ai_settings(_settings)
	var ai_provider := str(ai.get(APP_SETTINGS.AI_PROVIDER, APP_SETTINGS.AI_PROVIDER_DISABLED))
	_select_option_by_value(_ai_provider_button, AI_PROVIDER_ORDER, ai_provider)
	_ai_endpoint_edit.text = str(ai.get(APP_SETTINGS.AI_ENDPOINT, APP_SETTINGS.DEFAULT_AI_ENDPOINT))
	_ai_api_key_edit.text = str(ai.get(APP_SETTINGS.AI_API_KEY, ""))
	_ai_model_edit.text = str(ai.get(APP_SETTINGS.AI_MODEL, APP_SETTINGS.DEFAULT_AI_MODEL))
	_ai_model_path_edit.text = str(ai.get(APP_SETTINGS.AI_MODEL_PATH, ""))
	_ai_system_prompt_edit.text = str(ai.get(APP_SETTINGS.AI_SYSTEM_PROMPT, ""))
	_ai_max_tokens_spinbox.value = float(int(ai.get(APP_SETTINGS.AI_MAX_TOKENS, APP_SETTINGS.DEFAULT_AI_MAX_TOKENS)))
	_ai_temperature_spinbox.value = float(ai.get(APP_SETTINGS.AI_TEMPERATURE, APP_SETTINGS.DEFAULT_AI_TEMPERATURE))
	_ai_context_window_spinbox.value = float(int(ai.get(APP_SETTINGS.AI_CONTEXT_WINDOW, APP_SETTINGS.DEFAULT_AI_CONTEXT_WINDOW)))
	_ai_chat_history_window_spinbox.value = float(int(ai.get(APP_SETTINGS.AI_CHAT_HISTORY_WINDOW, APP_SETTINGS.DEFAULT_AI_CHAT_HISTORY_WINDOW)))
	_ai_streaming_speed_spinbox.value = float(ai.get(APP_SETTINGS.AI_STREAMING_SPEED, APP_SETTINGS.DEFAULT_AI_STREAMING_SPEED))
	_ai_world_gen_toggle.button_pressed = bool(ai.get(APP_SETTINGS.AI_ENABLE_WORLD_GEN, false))
	_title_label.text = "Settings"
	_subtitle_label.text = "Engine-owned application settings stored outside the mod data pipeline."
	_update_ai_controls_state()
	_update_ai_connection_button_state()


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
	var ai_provider := _get_selected_order_value(
		_ai_provider_button,
		AI_PROVIDER_ORDER,
		APP_SETTINGS.AI_PROVIDER_DISABLED
	)
	var ai_is_enabled := ai_provider != APP_SETTINGS.AI_PROVIDER_DISABLED

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
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: ai_is_enabled,
			APP_SETTINGS.AI_PROVIDER: ai_provider,
			APP_SETTINGS.AI_ENDPOINT: _ai_endpoint_edit.text,
			APP_SETTINGS.AI_API_KEY: _ai_api_key_edit.text,
			APP_SETTINGS.AI_MODEL: _ai_model_edit.text,
			APP_SETTINGS.AI_MODEL_PATH: _ai_model_path_edit.text,
			APP_SETTINGS.AI_SYSTEM_PROMPT: _ai_system_prompt_edit.text,
			APP_SETTINGS.AI_MAX_TOKENS: int(_ai_max_tokens_spinbox.value),
			APP_SETTINGS.AI_TEMPERATURE: _ai_temperature_spinbox.value,
			APP_SETTINGS.AI_CONTEXT_WINDOW: int(_ai_context_window_spinbox.value),
			APP_SETTINGS.AI_CHAT_HISTORY_WINDOW: int(_ai_chat_history_window_spinbox.value),
			APP_SETTINGS.AI_STREAMING_SPEED: _ai_streaming_speed_spinbox.value,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: _ai_world_gen_toggle.button_pressed,
		},
	})


func _preview_current_settings() -> void:
	_settings = _collect_settings_from_controls()
	_master_value_label.text = _format_percentage(_master_slider.value)
	_music_value_label.text = _format_percentage(_music_slider.value)
	_sfx_value_label.text = _format_percentage(_sfx_slider.value)
	APP_SETTINGS.apply_settings(get_window(), _settings)
	_update_ai_controls_state()
	_is_dirty = true
	_update_dirty_state()
	_status_label.text = "Previewing changes. Save to persist them, or Back to save and exit."
	_capture_debug_snapshot()


func _persist_settings() -> bool:
	_settings = _collect_settings_from_controls()
	var save_error := APP_SETTINGS.save_settings(_settings)
	if save_error != OK:
		_status_label.text = "Unable to save settings: %s" % error_string(save_error)
		return false
	APP_SETTINGS.apply_settings(get_window(), _settings)
	AIManager.initialize(_settings)
	ScriptHookService.invalidate_world_gen_settings_cache()
	_update_connected_ai_settings_from_manager()
	_persisted_settings = _settings.duplicate(true)
	_is_dirty = false
	_update_dirty_state()
	_update_ai_info()
	_status_label.text = "Settings saved."
	_capture_debug_snapshot()
	return true


func _revert_unsaved_changes() -> void:
	_settings = _persisted_settings.duplicate(true)
	_is_initializing = true
	_apply_settings_to_controls()
	_is_initializing = false
	APP_SETTINGS.apply_settings(get_window(), _persisted_settings)
	AIManager.initialize(_persisted_settings)
	ScriptHookService.invalidate_world_gen_settings_cache()
	_update_connected_ai_settings_from_manager()
	_is_dirty = false
	_update_dirty_state()
	_update_ai_info()
	_status_label.text = "Unsaved changes discarded."
	_capture_debug_snapshot()


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
	_ai_info_label.text = "AI Provider: %s\nStatus: %s\nConnection Owner: Engine Settings" % [provider_name, status_text]
	_ai_hint_label.text = _build_ai_hint_text(_get_selected_order_value(
		_ai_provider_button,
		AI_PROVIDER_ORDER,
		APP_SETTINGS.AI_PROVIDER_DISABLED
	))
	_update_ai_connection_button_state()
	_capture_debug_snapshot()


func _update_ai_controls_state() -> void:
	var provider := _get_selected_order_value(
		_ai_provider_button,
		AI_PROVIDER_ORDER,
		APP_SETTINGS.AI_PROVIDER_DISABLED
	)
	var uses_server_fields := provider == APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE
	var uses_anthropic_fields := provider == APP_SETTINGS.AI_PROVIDER_ANTHROPIC
	var uses_disk_fields := provider == APP_SETTINGS.AI_PROVIDER_NOBODYWHO
	var uses_any_model := provider != APP_SETTINGS.AI_PROVIDER_DISABLED
	_ai_endpoint_label.visible = uses_server_fields
	_ai_endpoint_edit.visible = uses_server_fields
	_ai_api_key_label.visible = uses_server_fields or uses_anthropic_fields
	_ai_api_key_edit.visible = uses_server_fields or uses_anthropic_fields
	_ai_model_label.visible = uses_any_model
	_ai_model_edit.visible = uses_any_model
	_ai_model_path_label.visible = uses_disk_fields
	_ai_model_path_edit.visible = uses_disk_fields
	_ai_system_prompt_label.visible = uses_any_model
	_ai_system_prompt_edit.visible = uses_any_model
	_ai_max_tokens_label.visible = uses_any_model
	_ai_max_tokens_spinbox.visible = uses_any_model
	_ai_chat_history_window_label.visible = uses_any_model
	_ai_chat_history_window_spinbox.visible = uses_any_model
	_ai_streaming_speed_label.visible = uses_any_model
	_ai_streaming_speed_spinbox.visible = uses_any_model
	_ai_world_gen_label.visible = uses_any_model
	_ai_world_gen_toggle.visible = uses_any_model
	_ai_temperature_label.visible = uses_server_fields or uses_disk_fields
	_ai_temperature_spinbox.visible = uses_server_fields or uses_disk_fields
	_ai_context_window_label.visible = uses_disk_fields
	_ai_context_window_spinbox.visible = uses_disk_fields
	_update_ai_connection_button_state()


func _update_ai_connection_button_state() -> void:
	if not is_node_ready():
		return
	var selected_provider := _get_selected_ai_provider()
	var manager_snapshot := AIManager.get_debug_snapshot()
	var active_provider := str(manager_snapshot.get("provider_name", AIManager.PROVIDER_DISABLED))
	var manager_available := bool(manager_snapshot.get("available", false))
	var has_active_connection := manager_available and active_provider != AIManager.PROVIDER_DISABLED
	if has_active_connection:
		_connect_ai_button.disabled = false
		if selected_provider == APP_SETTINGS.AI_PROVIDER_DISABLED or _ai_controls_match_connected_settings():
			_connect_ai_button.text = AI_BUTTON_DISCONNECT
			return
		_connect_ai_button.text = AI_BUTTON_UPDATE
		return
	_connect_ai_button.text = AI_BUTTON_CONNECT
	_connect_ai_button.disabled = selected_provider == APP_SETTINGS.AI_PROVIDER_DISABLED


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


func _select_option_by_value(button: OptionButton, order: Array, selected_value: String) -> void:
	var selected_index := order.find(selected_value)
	button.select(maxi(selected_index, 0))


func _get_selected_order_value(button: OptionButton, order: Array, fallback: String) -> String:
	var selected_index := button.get_selected_id()
	if selected_index >= 0 and selected_index < order.size():
		return str(order[selected_index])
	return fallback


func _get_selected_ai_provider() -> String:
	return _get_selected_order_value(
		_ai_provider_button,
		AI_PROVIDER_ORDER,
		APP_SETTINGS.AI_PROVIDER_DISABLED
	)


func _get_current_ai_settings() -> Dictionary:
	var settings := _collect_settings_from_controls()
	return APP_SETTINGS.get_ai_settings(settings)


func _ai_controls_match_connected_settings() -> bool:
	if _last_connected_ai_settings.is_empty():
		return false
	var current_ai_settings := _get_current_ai_settings()
	if current_ai_settings.size() != _last_connected_ai_settings.size():
		return false
	for key_value in current_ai_settings.keys():
		var key := str(key_value)
		if not _last_connected_ai_settings.has(key):
			return false
		if current_ai_settings.get(key) != _last_connected_ai_settings.get(key):
			return false
	return true


func _update_connected_ai_settings_from_manager() -> void:
	if not AIManager.is_available():
		_last_connected_ai_settings.clear()
		return
	var manager_snapshot := AIManager.get_debug_snapshot()
	var active_provider := str(manager_snapshot.get("provider_name", AIManager.PROVIDER_DISABLED))
	if active_provider == AIManager.PROVIDER_DISABLED:
		_last_connected_ai_settings.clear()
		return
	_last_connected_ai_settings = APP_SETTINGS.get_ai_settings(_settings)


func _build_ai_hint_text(provider: String) -> String:
	match provider:
		APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE:
			return "Server connection for Ollama, LM Studio, OpenAI, or any compatible endpoint. Chat history and streaming speed tune dialogue-side UX."
		APP_SETTINGS.AI_PROVIDER_ANTHROPIC:
			return "Hosted server connection using Anthropic's Messages API. Chat history and streaming speed tune dialogue-side UX."
		APP_SETTINGS.AI_PROVIDER_NOBODYWHO:
			return "On-disk model connection. Provide a local .gguf path and connect from engine settings. Chat history, streaming speed, and world generation tune dialogue-side UX."
		_:
			return "Choose a server or on-disk provider here. Mods can use AIManager, but they do not configure the engine connection."


func _grab_default_focus() -> void:
	if not is_node_ready():
		return
	_window_mode_button.grab_focus()


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


func _on_ai_provider_button_item_selected(_index: int) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_endpoint_edit_text_changed(_new_text: String) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_api_key_edit_text_changed(_new_text: String) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_model_edit_text_changed(_new_text: String) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_model_path_edit_text_changed(_new_text: String) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_system_prompt_edit_text_changed(_new_text: String) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_max_tokens_spinbox_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_temperature_spinbox_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_context_window_spinbox_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_chat_history_window_spinbox_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_streaming_speed_spinbox_value_changed(_value: float) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_ai_world_gen_toggle_toggled(_toggled_on: bool) -> void:
	if _is_initializing:
		return
	_preview_current_settings()


func _on_connect_ai_button_pressed() -> void:
	if _connect_ai_button.text == AI_BUTTON_DISCONNECT:
		_select_option_by_value(_ai_provider_button, AI_PROVIDER_ORDER, APP_SETTINGS.AI_PROVIDER_DISABLED)
		_settings = _collect_settings_from_controls()
		AIManager.initialize(_settings)
		_last_connected_ai_settings.clear()
		_update_ai_controls_state()
		_update_ai_info()
		_is_dirty = true
		_update_dirty_state()
		_status_label.text = "AI disconnected. Save to persist this setting."
		_capture_debug_snapshot()
		return
	_settings = _collect_settings_from_controls()
	AIManager.initialize(_settings)
	_update_ai_info()
	_is_dirty = true
	_update_dirty_state()
	var snapshot := AIManager.get_debug_snapshot()
	var available := bool(snapshot.get("available", false))
	var last_error := str(snapshot.get("last_error", ""))
	if available:
		_last_connected_ai_settings = APP_SETTINGS.get_ai_settings(_settings)
		_update_ai_connection_button_state()
		_status_label.text = "AI connection updated from engine settings."
		_capture_debug_snapshot()
		return
	_last_connected_ai_settings.clear()
	_update_ai_connection_button_state()
	if last_error.is_empty():
		_status_label.text = "AI connection is configured but unavailable."
		_capture_debug_snapshot()
		return
	_status_label.text = "AI connection failed: %s" % last_error
	_capture_debug_snapshot()


func _on_save_button_pressed() -> void:
	_persist_settings()


func _on_back_button_pressed() -> void:
	if _is_dirty and not _persist_settings():
		return
	if UIRouter.stack_depth() > 1:
		UIRouter.pop()
		return
	UIRouter.replace_all(SCREEN_MAIN_MENU)


func get_debug_snapshot() -> Dictionary:
	return _last_debug_snapshot.duplicate(true)


func _capture_debug_snapshot() -> void:
	var current_settings := _collect_settings_from_controls() if is_node_ready() else _settings
	var ai_snapshot := AIManager.get_debug_snapshot()
	_last_debug_snapshot = {
		"screen_id": "settings",
		"is_dirty": _is_dirty,
		"status_text": _status_label.text if is_node_ready() else "",
		"settings": current_settings.duplicate(true),
		"ai": {
			"provider_name": str(ai_snapshot.get("provider_name", AIManager.PROVIDER_DISABLED)),
			"available": bool(ai_snapshot.get("available", false)),
			"last_error": str(ai_snapshot.get("last_error", "")),
			"button_text": _connect_ai_button.text if is_node_ready() else "",
			"button_disabled": _connect_ai_button.disabled if is_node_ready() else true,
		},
	}
