extends Control

const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_LOCATION_VIEW := "location_view"

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SubtitleLabel
@onready var _continue_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/ContinueButton
@onready var _new_game_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/NewGameButton
@onready var _load_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/LoadButton
@onready var _quit_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonColumn/QuitButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel


func initialize(_params: Dictionary = {}) -> void:
	_apply_menu_config()
	_refresh_buttons()


func _ready() -> void:
	_apply_menu_config()
	_refresh_buttons()


func _apply_menu_config() -> void:
	var menu_config_data: Variant = DataManager.get_config_value("ui.main_menu", {})
	if not menu_config_data is Dictionary:
		return
	var menu_config: Dictionary = menu_config_data
	_title_label.text = str(menu_config.get("title", "Omni-Framework"))
	_subtitle_label.text = str(menu_config.get("subtitle", "A data-driven sandbox waiting for content."))
	_new_game_button.text = str(menu_config.get("new_game_label", "New Game"))
	_continue_button.text = str(menu_config.get("continue_label", "Continue"))
	_load_button.text = str(menu_config.get("load_label", "Load Slot 1"))
	_quit_button.text = str(menu_config.get("quit_label", "Quit"))


func _refresh_buttons() -> void:
	var has_slot_one := SaveManager.slot_exists(1)
	_continue_button.disabled = not has_slot_one
	_load_button.disabled = not has_slot_one
	if has_slot_one:
		var slot_info := SaveManager.get_slot_info(1)
		if not slot_info.is_empty():
			_status_label.text = "Slot 1 ready: %s" % str(slot_info.get("display_name", "Save found"))
		else:
			_status_label.text = "Slot 1 ready."
	else:
		_status_label.text = "No save found in slot 1."


func _transition_to_gameplay() -> void:
	UIRouter.replace_all(SCREEN_LOCATION_VIEW, {
		"location_id": GameState.current_location_id
	})


func _on_new_game_button_pressed() -> void:
	GameState.new_game()
	if GameState.player == null:
		_status_label.text = "Unable to start a new game."
		return
	UIRouter.replace_all(SCREEN_ASSEMBLY_EDITOR, {
		"screen_title": "Character Creator",
		"screen_description": "Choose a starter core, extend into any open sockets you want, and spend from your starting credits before you enter the world.",
		"screen_summary": "Preview a part on the left, inspect its price and stats on the right, then apply it to your starting build. Any credits you do not spend carry into the game.",
		"target_entity_id": "player",
		"budget_currency_id": "credits",
		"option_tag": "character_creator_option",
		"confirm_label": "Begin",
		"cancel_label": "Back",
		"next_screen_id": SCREEN_LOCATION_VIEW,
		"cancel_screen_id": "main_menu",
		"reset_game_state_on_cancel": true
	})


func _on_continue_button_pressed() -> void:
	_attempt_load_slot(1)


func _on_load_button_pressed() -> void:
	_attempt_load_slot(1)


func _attempt_load_slot(slot: int) -> void:
	if not SaveManager.slot_exists(slot):
		_status_label.text = "No save found in slot %d." % slot
		return
	if not SaveManager.load_game(slot):
		_status_label.text = "Unable to load slot %d." % slot
		return
	_transition_to_gameplay()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
