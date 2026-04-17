extends Node

const DEV_DEBUG_OVERLAY := preload("res://ui/debug/dev_debug_overlay.gd")
const THEME_APPLIER := preload("res://ui/theme/theme_applier.gd")
const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_CHARACTER_CREATOR := "character_creator"
const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"
const SCREEN_LOCATION_VIEW := "location_view"
const MAIN_MENU_SCENE := "res://ui/screens/main_menu/main_menu_screen.tscn"
const ASSEMBLY_EDITOR_SCENE := "res://ui/screens/backends/assembly_editor_screen.tscn"
const GAMEPLAY_SHELL_SCENE := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const LOCATION_VIEW_SCENE := "res://ui/screens/location_view/location_view_screen.tscn"

@onready var _screen_layer: CanvasLayer = $ScreenLayer
@onready var _status_label: Label = $ScreenLayer/StatusLabel


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
	ModLoader.load_all_mods()
	AIManager.initialize()
	var ui_theme: Theme = THEME_APPLIER.build_theme()
	UIRouter.set_screen_theme(ui_theme)
	_status_label.theme = ui_theme

	if ModLoader.is_loaded:
		_status_label.text = str(DataManager.get_config_value("ui.strings.boot_status", "Omni-Framework ready."))
		_status_label.visible = false
		UIRouter.replace_all(SCREEN_MAIN_MENU)
	else:
		_status_label.visible = true
		_status_label.text = "Omni-Framework failed to load mods."
