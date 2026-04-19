extends Control

const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_CHARACTER_CREATOR := "character_creator"
const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"
const SCREEN_SETTINGS := "settings"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_CREDITS := "credits"

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SubtitleLabel
@onready var _continue_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/ContinueButton
@onready var _new_game_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/NewGameButton
@onready var _load_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/LoadButton
@onready var _settings_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/SettingsButton
@onready var _credits_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/CreditsButton
@onready var _quit_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/QuitButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel

var _last_view_model: Dictionary = {}


func initialize(_params: Dictionary = {}) -> void:
	_apply_menu_config()
	_refresh_buttons()


func _ready() -> void:
	_apply_menu_config()
	_refresh_buttons()
	call_deferred("_grab_default_focus")


func on_route_revealed() -> void:
	_refresh_buttons()
	call_deferred("_grab_default_focus")


func _apply_menu_config() -> void:
	var menu_config_data: Variant = DataManager.get_config_value("ui.main_menu", {})
	if not menu_config_data is Dictionary:
		return
	var menu_config: Dictionary = menu_config_data
	_title_label.text = str(menu_config.get("title", "Omni-Framework"))
	_subtitle_label.text = str(menu_config.get("subtitle", "A data-driven sandbox waiting for content."))
	_new_game_button.text = str(menu_config.get("new_game_label", "New Game"))
	_continue_button.text = str(menu_config.get("continue_label", "Continue"))
	_load_button.text = str(menu_config.get("load_label", "Load Game"))
	_settings_button.text = str(menu_config.get("settings_label", "Settings"))
	_credits_button.text = str(menu_config.get("credits_label", "Credits"))
	_quit_button.text = str(menu_config.get("quit_label", "Quit"))


func _refresh_buttons() -> void:
	var preferred_slot := SaveManager.get_most_recent_loadable_slot()
	var has_save := preferred_slot >= SaveManager.AUTOSAVE_SLOT
	_continue_button.disabled = not has_save
	_load_button.disabled = not has_save
	if has_save:
		var slot_info := SaveManager.get_slot_info(preferred_slot)
		var slot_label := str(slot_info.get("slot_label", SaveManager.get_slot_label(preferred_slot)))
		if not slot_info.is_empty():
			_status_label.text = "Continue from %s: %s" % [
				slot_label,
				str(slot_info.get("display_name", "Save found"))
			]
		else:
			_status_label.text = "Continue from %s." % slot_label
	else:
		_status_label.text = "No saves or autosaves found."
	_last_view_model = {
		"screen_id": "main_menu",
		"title": _title_label.text,
		"subtitle": _subtitle_label.text,
		"has_save": has_save,
		"preferred_slot": preferred_slot,
		"status_text": _status_label.text,
	}


func _grab_default_focus() -> void:
	if not is_node_ready():
		return
	if not _continue_button.disabled:
		_continue_button.grab_focus()
		return
	if not _new_game_button.disabled:
		_new_game_button.grab_focus()
		return
	if not _settings_button.disabled:
		_settings_button.grab_focus()


func _transition_to_gameplay() -> void:
	UIRouter.replace_all(SCREEN_GAMEPLAY_SHELL)


func _on_new_game_button_pressed() -> void:
	GameState.new_game()
	if GameState.player == null:
		_status_label.text = "Unable to start a new game."
		return

	var flow_data: Variant = DataManager.get_config_value("game.new_game_flow", {})
	var flow: Dictionary = {}
	if flow_data is Dictionary:
		flow = flow_data

	var screen_id := str(flow.get("screen_id", SCREEN_GAMEPLAY_SHELL))
	var params: Dictionary = {}
	var params_data: Variant = flow.get("params", {})
	if params_data is Dictionary:
		var flow_params: Dictionary = params_data
		params = flow_params.duplicate(true)

	if screen_id.is_empty():
		screen_id = SCREEN_GAMEPLAY_SHELL

	if screen_id == SCREEN_ASSEMBLY_EDITOR and not params.has("next_screen_id"):
		params["next_screen_id"] = SCREEN_GAMEPLAY_SHELL
	elif screen_id == SCREEN_CHARACTER_CREATOR and not params.has("next_screen_id"):
		params["next_screen_id"] = SCREEN_GAMEPLAY_SHELL

	UIRouter.replace_all(screen_id, params)


func _on_continue_button_pressed() -> void:
	var preferred_slot := SaveManager.get_most_recent_loadable_slot()
	if preferred_slot < SaveManager.AUTOSAVE_SLOT:
		_status_label.text = "No saves or autosaves are available."
		return
	_attempt_load_slot(preferred_slot)


func _on_load_button_pressed() -> void:
	UIRouter.push(SCREEN_SAVE_SLOT_LIST, {
		"mode": "load",
	})


func _on_settings_button_pressed() -> void:
	UIRouter.push(SCREEN_SETTINGS)


func _on_credits_button_pressed() -> void:
	UIRouter.push(SCREEN_CREDITS)


func _attempt_load_slot(slot: int) -> void:
	if not SaveManager.slot_exists(slot):
		_status_label.text = "No save found in %s." % SaveManager.get_slot_label(slot)
		return
	if not SaveManager.load_game(slot):
		_status_label.text = "Unable to load %s." % SaveManager.get_slot_label(slot)
		return
	_transition_to_gameplay()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)
