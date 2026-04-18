extends Node

const APP_SETTINGS := preload("res://core/app_settings.gd")
const DEV_DEBUG_OVERLAY := preload("res://ui/debug/dev_debug_overlay.gd")
const THEME_APPLIER := preload("res://ui/theme/theme_applier.gd")
const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_CHARACTER_CREATOR := "character_creator"
const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"
const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_SETTINGS := "settings"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_PAUSE_MENU := "pause_menu"
const SCREEN_CREDITS := "credits"
const MAIN_MENU_SCENE := "res://ui/screens/main_menu/main_menu_screen.tscn"
const ASSEMBLY_EDITOR_SCENE := "res://ui/screens/backends/assembly_editor_screen.tscn"
const GAMEPLAY_SHELL_SCENE := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const LOCATION_VIEW_SCENE := "res://ui/screens/location_view/location_view_screen.tscn"
const SETTINGS_SCENE := "res://ui/screens/settings/settings_screen.tscn"
const SAVE_SLOT_LIST_SCENE := "res://ui/screens/save_slot_list/save_slot_list_screen.tscn"
const PAUSE_MENU_SCENE := "res://ui/screens/pause_menu/pause_menu_screen.tscn"
const CREDITS_SCENE := "res://ui/screens/credits/credits_screen.tscn"

@onready var _screen_layer: CanvasLayer = $ScreenLayer
@onready var _status_label: Label = $ScreenLayer/StatusLabel
@onready var _notification_popup: Control = $ScreenLayer/NotificationPopup

var _game_is_paused: bool = false
var _timekeeper_was_running_before_pause: bool = false


func _ready() -> void:
	if OS.is_debug_build():
		var debug_overlay := DEV_DEBUG_OVERLAY.new()
		debug_overlay.initialize_overlay()
		add_child(debug_overlay)

	UIRouter.initialize(_screen_layer)
	UIRouter.register_screen(SCREEN_MAIN_MENU, MAIN_MENU_SCENE)
	UIRouter.register_screen(SCREEN_ASSEMBLY_EDITOR, ASSEMBLY_EDITOR_SCENE)
	UIRouter.register_screen(SCREEN_CHARACTER_CREATOR, ASSEMBLY_EDITOR_SCENE)
	UIRouter.register_screen(SCREEN_GAMEPLAY_SHELL, GAMEPLAY_SHELL_SCENE)
	UIRouter.register_screen(SCREEN_LOCATION_VIEW, LOCATION_VIEW_SCENE)
	UIRouter.register_screen(SCREEN_SETTINGS, SETTINGS_SCENE)
	UIRouter.register_screen(SCREEN_SAVE_SLOT_LIST, SAVE_SLOT_LIST_SCENE)
	UIRouter.register_screen(SCREEN_PAUSE_MENU, PAUSE_MENU_SCENE)
	UIRouter.register_screen(SCREEN_CREDITS, CREDITS_SCENE)
	ModLoader.load_all_mods()
	var app_settings := APP_SETTINGS.load_settings()
	APP_SETTINGS.apply_settings(get_window(), app_settings)
	AIManager.initialize(app_settings)
	var ui_theme: Theme = THEME_APPLIER.build_theme()
	UIRouter.set_screen_theme(ui_theme)
	_status_label.theme = ui_theme
	_connect_runtime_signals()

	if ModLoader.is_loaded:
		_status_label.text = str(DataManager.get_config_value("ui.strings.boot_status", "Omni-Framework ready."))
		_status_label.visible = false
		UIRouter.replace_all(SCREEN_MAIN_MENU)
	else:
		_status_label.visible = true
		_status_label.text = "Omni-Framework failed to load mods."


func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed("ui_cancel"):
		return
	if _handle_cancel_navigation():
		get_viewport().set_input_as_handled()


func _connect_runtime_signals() -> void:
	var on_screen_pushed := Callable(self, "_on_ui_screen_stack_changed")
	if not GameEvents.is_connected("ui_screen_pushed", on_screen_pushed):
		GameEvents.ui_screen_pushed.connect(_on_ui_screen_stack_changed)
	var on_screen_popped := Callable(self, "_on_ui_screen_stack_changed")
	if not GameEvents.is_connected("ui_screen_popped", on_screen_popped):
		GameEvents.ui_screen_popped.connect(_on_ui_screen_stack_changed)
	var on_notification_requested := Callable(self, "_on_notification_requested")
	if not GameEvents.is_connected("ui_notification_requested", on_notification_requested):
		GameEvents.ui_notification_requested.connect(_on_notification_requested)
	var on_legacy_notification_requested := Callable(self, "_on_legacy_notification_requested")
	if not GameEvents.is_connected("notification_requested", on_legacy_notification_requested):
		GameEvents.notification_requested.connect(_on_legacy_notification_requested)


func _handle_cancel_navigation() -> bool:
	if not UIRouter.has_screen():
		return false

	if _route_stack_contains(SCREEN_PAUSE_MENU):
		UIRouter.pop()
		return true

	var current_screen_id := UIRouter.current_screen_id()
	if current_screen_id == SCREEN_SETTINGS or current_screen_id == SCREEN_SAVE_SLOT_LIST or current_screen_id == SCREEN_CREDITS:
		if UIRouter.stack_depth() > 1:
			UIRouter.pop()
			return true
		return false

	if _can_open_pause_menu(current_screen_id):
		UIRouter.push(SCREEN_PAUSE_MENU)
		return true

	return false


func _can_open_pause_menu(current_screen_id: String) -> bool:
	if current_screen_id == SCREEN_MAIN_MENU or current_screen_id == SCREEN_PAUSE_MENU:
		return false
	if GameState.player == null:
		return false
	return true


func _route_stack_contains(screen_id: String) -> bool:
	var stack_snapshot := UIRouter.get_stack_snapshot()
	for entry_value in stack_snapshot:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("screen_id", "")) == screen_id:
			return true
	return false


func _on_ui_screen_stack_changed(_screen_id: String) -> void:
	_sync_pause_state()


func _on_notification_requested(message: String, level: String) -> void:
	_notification_popup.call("render", {
		"message": message,
		"level": level,
	})


func _on_legacy_notification_requested(message: String, level: String) -> void:
	_on_notification_requested(message, level)


func _sync_pause_state() -> void:
	var should_pause := _route_stack_contains(SCREEN_PAUSE_MENU)
	if should_pause == _game_is_paused:
		return
	_game_is_paused = should_pause
	if _game_is_paused:
		_timekeeper_was_running_before_pause = TimeKeeper.is_running
		TimeKeeper.pause()
		GameEvents.game_paused.emit()
		return
	if _timekeeper_was_running_before_pause:
		TimeKeeper.resume()
	_timekeeper_was_running_before_pause = false
	GameEvents.game_resumed.emit()
