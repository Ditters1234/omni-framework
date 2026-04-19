extends Control

const SCREEN_ENTITY_SHEET := "entity_sheet"
const SCREEN_PAUSE_MENU := "pause_menu"
const GAMEPLAY_SHELL_PRESENTER := preload("res://ui/screens/gameplay_shell/gameplay_shell_presenter.gd")
const GAMEPLAY_LOCATION_SURFACE_SCENE := preload("res://ui/screens/gameplay_shell/gameplay_location_surface.tscn")
const DEFAULT_SURFACE_ID := "location_surface"

@onready var _title_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/VBoxContainer/SubtitleLabel
@onready var _character_menu_button: Button = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/CharacterMenuButton
@onready var _quick_autosave_button: Button = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/QuickAutosaveButton
@onready var _pause_menu_button: Button = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/PauseMenuButton
@onready var _location_title_label: Label = $MarginContainer/VBoxContainer/OverviewRow/LocationPanel/MarginContainer/VBoxContainer/LocationTitleLabel
@onready var _location_description_label: Label = $MarginContainer/VBoxContainer/OverviewRow/LocationPanel/MarginContainer/VBoxContainer/LocationDescriptionLabel
@onready var _location_meta_label: Label = $MarginContainer/VBoxContainer/OverviewRow/LocationPanel/MarginContainer/VBoxContainer/LocationMetaLabel
@onready var _session_time_label: Label = $MarginContainer/VBoxContainer/OverviewRow/SessionPanel/MarginContainer/VBoxContainer/SessionTimeLabel
@onready var _session_day_label: Label = $MarginContainer/VBoxContainer/OverviewRow/SessionPanel/MarginContainer/VBoxContainer/SessionDayLabel
@onready var _advance_tick_button: Button = $MarginContainer/VBoxContainer/OverviewRow/SessionPanel/MarginContainer/VBoxContainer/AdvanceTickButton
@onready var _time_buttons_container: HFlowContainer = $MarginContainer/VBoxContainer/OverviewRow/SessionPanel/MarginContainer/VBoxContainer/TimeAdvanceButtons
@onready var _surface_panel: PanelContainer = $MarginContainer/VBoxContainer/SurfacePanel
@onready var _surface_title_label: Label = $MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHeader/SurfaceTitleLabel
@onready var _surface_close_button: Button = $MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHeader/SurfaceCloseButton
@onready var _surface_host: Control = $MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHost
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _status_message: String = "Ready."
var _last_view_model: Dictionary = {}
var _presenter: RefCounted = GAMEPLAY_SHELL_PRESENTER.new()
var _runtime_signals_connected: bool = false
var _active_surface: Control = null
var _active_surface_screen_id: String = ""


func initialize(_params: Dictionary = {}) -> void:
	_rebuild_time_buttons()
	_refresh()
	_show_default_surface_if_needed()


func _ready() -> void:
	_connect_runtime_signals()
	_surface_host.clip_contents = true
	_rebuild_time_buttons()
	_refresh()
	_show_default_surface_if_needed()
	call_deferred("_grab_default_focus")


func on_route_revealed() -> void:
	_refresh()
	_show_default_surface_if_needed()
	call_deferred("_grab_default_focus")


func open_surface_screen(screen_id: String, params: Dictionary = {}) -> void:
	var surface := UIRouter.instantiate_registered_screen(screen_id)
	if surface == null:
		return
	_close_active_surface_internal(false)
	_mount_surface(surface, screen_id, params)
	_surface_title_label.text = _build_surface_title(screen_id)
	_refresh_surface_chrome()


func show_location_surface(params: Dictionary = {}) -> void:
	var location_surface_value: Variant = GAMEPLAY_LOCATION_SURFACE_SCENE.instantiate()
	var location_surface := location_surface_value as Control
	if location_surface == null:
		return
	_close_active_surface_internal(false)
	_mount_surface(location_surface, DEFAULT_SURFACE_ID, params)
	_surface_title_label.text = "Location Actions"
	_refresh_surface_chrome()


func close_active_surface() -> void:
	_close_active_surface_internal(true)


func get_debug_snapshot() -> Dictionary:
	var snapshot := _last_view_model.duplicate(true)
	snapshot["active_surface_screen_id"] = _active_surface_screen_id
	snapshot["surface_visible"] = _surface_panel.visible
	return snapshot


func _mount_surface(surface: Control, screen_id: String, params: Dictionary) -> void:
	_active_surface_screen_id = screen_id
	_active_surface = surface
	_surface_host.add_child(surface)
	_prepare_surface_for_hosting(surface)
	if surface.has_method("initialize"):
		surface.call("initialize", params.duplicate(true))
	_surface_panel.visible = true


func _prepare_surface_for_hosting(surface: Control) -> void:
	surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	surface.offset_left = 0.0
	surface.offset_top = 0.0
	surface.offset_right = 0.0
	surface.offset_bottom = 0.0
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.position = Vector2.ZERO
	surface.custom_minimum_size = Vector2.ZERO


func _show_default_surface_if_needed() -> void:
	if _active_surface != null and is_instance_valid(_active_surface):
		return
	show_location_surface({
		"location_id": GameState.current_location_id,
	})


func _close_active_surface_internal(show_default_after_close: bool) -> void:
	if _active_surface != null and is_instance_valid(_active_surface):
		_surface_host.remove_child(_active_surface)
		_active_surface.queue_free()
	_active_surface = null
	_active_surface_screen_id = ""
	_surface_panel.visible = false
	_surface_title_label.text = "Surface"
	if show_default_after_close:
		_show_default_surface_if_needed()
	else:
		_refresh_surface_chrome()


func _refresh_surface_chrome() -> void:
	var has_surface := _active_surface != null and is_instance_valid(_active_surface)
	var is_default_surface := _active_surface_screen_id == DEFAULT_SURFACE_ID
	_surface_panel.visible = has_surface
	_surface_close_button.visible = has_surface and not is_default_surface
	_surface_close_button.disabled = not has_surface or is_default_surface
	if is_default_surface:
		_surface_close_button.text = "Back"
	else:
		_surface_close_button.text = "Close"


func _build_surface_title(screen_id: String) -> String:
	match screen_id:
		"assembly_editor":
			return "Loadout"
		"exchange":
			return "Exchange"
		"list_view":
			return "List"
		"challenge":
			return "Challenge"
		"task_provider":
			return "Tasks"
		"catalog_list":
			return "Catalog"
		"dialogue":
			return "Dialogue"
		"entity_sheet":
			return "Character Menu"
		"quest_log":
			return "Quest Log"
		"faction_rep":
			return "Faction Reputation"
		"achievement_list":
			return "Achievements"
		"event_log":
			return "Event Log"
		_:
			return screen_id.capitalize()


func _connect_runtime_signals() -> void:
	if _runtime_signals_connected:
		return
	GameEvents.tick_advanced.connect(_on_tick_advanced)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.location_changed.connect(_on_location_changed)
	_runtime_signals_connected = true


func _refresh() -> void:
	var view_model_value: Variant = _presenter.call("build_view_model", _status_message)
	var view_model := _read_dictionary(view_model_value)
	_last_view_model = view_model.duplicate(true)
	_rebuild_time_buttons(_read_dictionary_array(view_model.get("time_button_specs", [])))
	_apply_view_model(view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("title", "Gameplay"))
	_subtitle_label.text = str(view_model.get("subtitle", ""))
	var location_value: Variant = view_model.get("location", {})
	var location_view_model := _read_dictionary(location_value)
	_location_title_label.text = str(location_view_model.get("title_text", ""))
	_location_description_label.text = str(location_view_model.get("description_text", ""))
	_location_meta_label.text = str(location_view_model.get("meta_text", ""))
	var session_value: Variant = view_model.get("session", {})
	var session_view_model := _read_dictionary(session_value)
	_session_time_label.text = str(session_view_model.get("time_text", ""))
	_session_day_label.text = str(session_view_model.get("day_text", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_set_buttons_enabled(bool(view_model.get("buttons_enabled", false)))


func _set_buttons_enabled(enabled: bool) -> void:
	_character_menu_button.disabled = not enabled
	_quick_autosave_button.disabled = not enabled
	_advance_tick_button.disabled = not enabled
	_pause_menu_button.disabled = not enabled
	if _surface_close_button.visible:
		_surface_close_button.disabled = not enabled
	for child in _time_buttons_container.get_children():
		var button := child as Button
		if button != null:
			button.disabled = not enabled


func _rebuild_time_buttons(specs: Array[Dictionary] = []) -> void:
	for child in _time_buttons_container.get_children():
		_time_buttons_container.remove_child(child)
		child.queue_free()
	var button_specs := specs
	if button_specs.is_empty():
		var button_specs_value: Variant = _presenter.call("get_time_button_specs")
		button_specs = _read_dictionary_array(button_specs_value)
	for spec in button_specs:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.text = str(spec.get("label", "Advance"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tick_count := int(spec.get("ticks", 1))
		button.pressed.connect(func() -> void:
			_advance_time_by_ticks(tick_count, str(spec.get("label", "Advance")))
		)
		_time_buttons_container.add_child(button)


func _advance_time_by_ticks(tick_count: int, label: String) -> void:
	if tick_count <= 0:
		return
	TimeKeeper.advance_ticks(tick_count)
	_status_message = "Advanced %s." % label
	_refresh()


func _on_advance_tick_button_pressed() -> void:
	TimeKeeper.advance_tick()
	_status_message = "Advanced one tick."
	_refresh()


func _on_character_menu_button_pressed() -> void:
	open_surface_screen(SCREEN_ENTITY_SHEET, {
		"target_entity_id": "player",
		"opened_from_gameplay_shell": true,
	})


func _on_quick_autosave_button_pressed() -> void:
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT)
	var summary := SaveManager.last_operation_summary
	if str(summary.get("status", "")) != "ok":
		_status_message = str(summary.get("reason", "Unable to write autosave."))
		_refresh()
		return
	_status_message = "Autosave updated."
	_refresh()


func _on_pause_menu_button_pressed() -> void:
	UIRouter.push(SCREEN_PAUSE_MENU)


func _on_surface_close_button_pressed() -> void:
	close_active_surface()


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_day_advanced(_day: int) -> void:
	_refresh()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh()
	show_location_surface({
		"location_id": GameState.current_location_id,
	})


func _grab_default_focus() -> void:
	if not is_node_ready():
		return
	if not _character_menu_button.disabled:
		_character_menu_button.grab_focus()
		return
	if not _advance_tick_button.disabled:
		_advance_tick_button.grab_focus()


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _read_dictionary_array(value: Variant) -> Array[Dictionary]:
	var dictionaries: Array[Dictionary] = []
	if not value is Array:
		return dictionaries
	var values: Array = value
	for item in values:
		if item is Dictionary:
			dictionaries.append(item)
	return dictionaries
