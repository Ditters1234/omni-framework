extends Control

const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_SETTINGS := "settings"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"

@onready var _title_label: Label = $Overlay/MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _context_label: Label = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ContextLabel
@onready var _resume_button: Button = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/ResumeButton
@onready var _save_button: Button = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/SaveButton
@onready var _settings_button: Button = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/SettingsButton
@onready var _main_menu_button: Button = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/MainMenuButton
@onready var _quit_button: Button = $Overlay/MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/QuitButton
@onready var _status_label: Label = $Overlay/MarginContainer/PanelContainer/VBoxContainer/StatusLabel


func initialize(_params: Dictionary = {}) -> void:
	_refresh()


func _ready() -> void:
	_refresh()


func on_route_revealed() -> void:
	_refresh()


func _refresh() -> void:
	_title_label.text = "Paused"
	_resume_button.text = "Resume"
	_save_button.text = "Save Game"
	_settings_button.text = "Settings"
	_main_menu_button.text = "Return to Main Menu"
	_quit_button.text = "Quit Desktop"
	if GameState.player == null:
		_context_label.text = "No active session."
		_status_label.text = "The game is paused."
		return
	_context_label.text = "Location: %s\n%s" % [
		GameState.current_location_id,
		TimeKeeper.get_time_string(),
	]
	_status_label.text = "Gameplay timers and music stay paused until you resume."


func _on_resume_button_pressed() -> void:
	UIRouter.pop()


func _on_save_button_pressed() -> void:
	UIRouter.push(SCREEN_SAVE_SLOT_LIST, {
		"mode": "save",
		"close_on_save": true,
	})


func _on_settings_button_pressed() -> void:
	UIRouter.push(SCREEN_SETTINGS)


func _on_main_menu_button_pressed() -> void:
	UIRouter.replace_all(SCREEN_MAIN_MENU)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
