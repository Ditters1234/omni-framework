extends Control

const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_PAUSE_MENU := "pause_menu"
const CURRENCY_DISPLAY_SCENE := preload("res://ui/components/currency_display.tscn")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")
const GAMEPLAY_SHELL_PRESENTER := preload("res://ui/screens/gameplay_shell/gameplay_shell_presenter.gd")

@onready var _title_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/VBoxContainer/SubtitleLabel
@onready var _location_title_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationTitleLabel
@onready var _location_description_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationDescriptionLabel
@onready var _location_meta_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationMetaLabel
@onready var _player_portrait: Control = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/PlayerPortrait
@onready var _currency_list: HFlowContainer = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/CurrencyList
@onready var _player_stat_sheet: Control = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/PlayerStatSheet
@onready var _inventory_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/InventoryLabel
@onready var _time_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/TimeLabel
@onready var _autosave_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/AutosaveLabel
@onready var _time_buttons_container: HFlowContainer = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/TimeAdvanceButtons
@onready var _equipped_cards: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/EquipmentPanel/MarginContainer/VBoxContainer/EquipmentScroll/EquippedCards
@onready var _explore_location_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/ExploreLocationButton
@onready var _loadout_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/OpenLoadoutButton
@onready var _quick_autosave_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/QuickAutosaveButton
@onready var _advance_tick_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/AdvanceTickButton
@onready var _pause_menu_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/PauseMenuButton
@onready var _status_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/StatusLabel
@onready var _shell_panel: PanelContainer = $MarginContainer/ScrollContainer/VBoxContainer/ShellSurfacePanel
@onready var _shell_surface_title_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ShellSurfacePanel/MarginContainer/VBoxContainer/HeaderRow/SurfaceTitleLabel
@onready var _shell_surface_close_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ShellSurfacePanel/MarginContainer/VBoxContainer/HeaderRow/CloseSurfaceButton
@onready var _shell_surface_host: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer/ShellSurfacePanel/MarginContainer/VBoxContainer/SurfaceHost

var _auto_open_location_view: bool = false
var _opened_initial_location_view: bool = false
var _status_message: String = "Ready."
var _last_view_model: Dictionary = {}
var _presenter: RefCounted = GAMEPLAY_SHELL_PRESENTER.new()
var _runtime_signals_connected: bool = false
var _shell_screen: Control = null
var _shell_screen_id: String = ""

func initialize(params: Dictionary = {}) -> void:
	var auto_open_data: Variant = params.get("auto_open_location_view", false)
	_auto_open_location_view = bool(auto_open_data)
	_rebuild_time_buttons()
	_set_shell_surface_visible(false)
	_refresh()
	_maybe_open_initial_location_view()


func _ready() -> void:
	_connect_runtime_signals()
	_rebuild_time_buttons()
	_set_shell_surface_visible(false)
	_refresh()
	_maybe_open_initial_location_view()
	call_deferred("_grab_default_focus")


func on_route_revealed() -> void:
	_refresh()
	call_deferred("_grab_default_focus")


func open_shell_screen(screen_id: String, params: Dictionary = {}) -> bool:
	if screen_id.is_empty() or not UIRouter.is_registered(screen_id):
		return false
	close_shell_screen()
	var shell_params := params.duplicate(true)
	shell_params["opened_from_gameplay_shell"] = true
	var screen := UIRouter.instantiate_registered_screen(screen_id, shell_params)
	if screen == null:
		return false
	_shell_screen = screen
	_shell_screen_id = screen_id
	_shell_surface_host.add_child(screen)
	_shell_surface_title_label.text = _humanize_screen_id(screen_id)
	_set_shell_surface_visible(true)
	_status_message = "Opened %s in the shell." % _humanize_screen_id(screen_id)
	_refresh()
	return true


func close_shell_screen() -> void:
	if _shell_screen != null and is_instance_valid(_shell_screen):
		_shell_surface_host.remove_child(_shell_screen)
		_shell_screen.queue_free()
	_shell_screen = null
	_shell_screen_id = ""
	_set_shell_surface_visible(false)
	_status_message = "Returned to the shell."
	_refresh()


func has_shell_screen() -> bool:
	return _shell_screen != null and is_instance_valid(_shell_screen)


func _set_shell_surface_visible(is_visible: bool) -> void:
	_shell_panel.visible = is_visible
	_shell_surface_close_button.visible = is_visible


func _connect_runtime_signals() -> void:
	if _runtime_signals_connected:
		return
	GameEvents.tick_advanced.connect(_on_tick_advanced)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.location_changed.connect(_on_location_changed)
	GameEvents.entity_stat_changed.connect(_on_entity_stat_changed)
	GameEvents.entity_currency_changed.connect(_on_entity_currency_changed)
	GameEvents.part_equipped.connect(_on_part_equipped)
	GameEvents.part_unequipped.connect(_on_part_unequipped)
	_runtime_signals_connected = true


func _refresh() -> void:
	var view_model_value: Variant = _presenter.call("build_view_model", _status_message)
	var view_model := _read_dictionary(view_model_value)
	_last_view_model = view_model.duplicate(true)
	_last_view_model["auto_open_location_view"] = _auto_open_location_view
	_last_view_model["opened_initial_location_view"] = _opened_initial_location_view
	_last_view_model["shell_screen_id"] = _shell_screen_id
	_rebuild_time_buttons(_read_dictionary_array(view_model.get("time_button_specs", [])))
	_apply_view_model(view_model)


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)


func _apply_view_model(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("title", "Gameplay Shell"))
	_subtitle_label.text = str(view_model.get("subtitle", ""))
	var location_value: Variant = view_model.get("location", {})
	var location_view_model := _read_dictionary(location_value)
	_location_title_label.text = str(location_view_model.get("title_text", ""))
	_location_description_label.text = str(location_view_model.get("description_text", ""))
	_location_meta_label.text = str(location_view_model.get("meta_text", ""))
	var player_value: Variant = view_model.get("player", {})
	var player_view_model := _read_dictionary(player_value)
	_player_portrait.call("render", _read_dictionary(player_view_model.get("portrait", {})))
	_render_currency_displays(_read_dictionary_array(player_view_model.get("currencies", [])))
	_player_stat_sheet.call("render", _read_dictionary(player_view_model.get("stat_sheet", {})))
	_inventory_label.text = str(player_view_model.get("inventory_summary", ""))
	_time_label.text = str(view_model.get("time_text", ""))
	_autosave_label.text = str(view_model.get("autosave_summary", ""))
	_render_equipped_cards(_read_dictionary_array(player_view_model.get("equipped_parts", [])))
	_status_label.text = str(view_model.get("status_text", ""))
	_set_buttons_enabled(bool(view_model.get("buttons_enabled", false)))


func _render_currency_displays(view_models: Array[Dictionary]) -> void:
	_clear_container_children(_currency_list)
	if view_models.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No currencies available."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_currency_list.add_child(empty_label)
		return
	for view_model in view_models:
		var display_value: Variant = CURRENCY_DISPLAY_SCENE.instantiate()
		if not display_value is Control:
			continue
		var display: Control = display_value
		_currency_list.add_child(display)
		display.call("render", view_model)


func _render_equipped_cards(view_models: Array[Dictionary]) -> void:
	_clear_container_children(_equipped_cards)
	if view_models.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No equipped parts are active in this loadout yet."
		_equipped_cards.add_child(empty_label)
		return
	for view_model in view_models:
		var part_card_value: Variant = PART_CARD_SCENE.instantiate()
		if not part_card_value is Control:
			continue
		var part_card: Control = part_card_value
		_equipped_cards.add_child(part_card)
		part_card.call("render", view_model)


func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _set_buttons_enabled(enabled: bool) -> void:
	_explore_location_button.disabled = not enabled
	_loadout_button.disabled = not enabled
	_quick_autosave_button.disabled = not enabled
	_advance_tick_button.disabled = not enabled
	_pause_menu_button.disabled = not enabled
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


func _on_explore_location_button_pressed() -> void:
	UIRouter.push(SCREEN_LOCATION_VIEW)


func _on_open_loadout_button_pressed() -> void:
	open_shell_screen(SCREEN_ASSEMBLY_EDITOR, {
		"screen_title": "Character Loadout",
		"screen_description": "Review your current build, inspect sockets, and return to the shell when you are done.",
		"screen_summary": "This shell shortcut opens your live player assembly directly.",
		"target_entity_id": "player",
		"confirm_label": "Done",
		"cancel_label": "Back",
		"pop_on_confirm": true,
		"cancel_screen_id": "",
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


func _on_close_surface_button_pressed() -> void:
	close_shell_screen()


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_day_advanced(_day: int) -> void:
	_refresh()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh()


func _on_entity_stat_changed(entity_id: String, _stat_key: String, _old_value: float, _new_value: float) -> void:
	var player := GameState.player as EntityInstance
	if player != null and entity_id == player.entity_id:
		_refresh()


func _on_entity_currency_changed(entity_id: String, _currency_key: String, _old_amount: float, _new_amount: float) -> void:
	var player := GameState.player as EntityInstance
	if player != null and entity_id == player.entity_id:
		_refresh()


func _on_part_equipped(entity_id: String, _part_id: String, _slot: String) -> void:
	var player := GameState.player as EntityInstance
	if player != null and entity_id == player.entity_id:
		_refresh()


func _on_part_unequipped(entity_id: String, _part_id: String, _slot: String) -> void:
	var player := GameState.player as EntityInstance
	if player != null and entity_id == player.entity_id:
		_refresh()


func _maybe_open_initial_location_view() -> void:
	if not _auto_open_location_view or _opened_initial_location_view:
		return
	if GameState.current_location_id.is_empty():
		return
	_opened_initial_location_view = true
	call_deferred("_open_initial_location_view")


func _open_initial_location_view() -> void:
	UIRouter.push(SCREEN_LOCATION_VIEW, {
		"location_id": GameState.current_location_id
	})


func _grab_default_focus() -> void:
	if not is_node_ready():
		return
	if has_shell_screen() and _shell_surface_close_button.visible and not _shell_surface_close_button.disabled:
		_shell_surface_close_button.grab_focus()
		return
	if not _explore_location_button.disabled:
		_explore_location_button.grab_focus()
		return
	if not _advance_tick_button.disabled:
		_advance_tick_button.grab_focus()


func _humanize_screen_id(screen_id: String) -> String:
	if screen_id.is_empty():
		return "Shell Surface"
	return screen_id.replace("_", " ").capitalize()


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
