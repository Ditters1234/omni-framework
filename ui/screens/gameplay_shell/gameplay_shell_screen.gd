extends Control

const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_PAUSE_MENU := "pause_menu"

@onready var _title_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var _location_title_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationTitleLabel
@onready var _location_description_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationDescriptionLabel
@onready var _location_meta_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/LocationPanel/MarginContainer/VBoxContainer/LocationMetaLabel
@onready var _player_name_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/PlayerNameLabel
@onready var _currency_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/CurrencyLabel
@onready var _stats_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/StatsLabel
@onready var _inventory_label: Label = $MarginContainer/VBoxContainer/ContentColumns/LeftColumn/PlayerPanel/MarginContainer/VBoxContainer/InventoryLabel
@onready var _time_label: Label = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/TimeLabel
@onready var _autosave_label: Label = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/AutosaveLabel
@onready var _time_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/TimeAdvanceButtons
@onready var _equipped_label: Label = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/EquipmentPanel/MarginContainer/VBoxContainer/EquippedLabel
@onready var _explore_location_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/ExploreLocationButton
@onready var _loadout_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/OpenLoadoutButton
@onready var _save_browser_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/SaveBrowserButton
@onready var _quick_autosave_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/QuickAutosaveButton
@onready var _advance_tick_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/AdvanceTickButton
@onready var _pause_menu_button: Button = $MarginContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/PauseMenuButton
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _auto_open_location_view: bool = false
var _opened_initial_location_view: bool = false
var _status_message: String = "Ready."


func initialize(params: Dictionary = {}) -> void:
	var auto_open_data: Variant = params.get("auto_open_location_view", false)
	_auto_open_location_view = bool(auto_open_data)
	_rebuild_time_buttons()
	_refresh()
	_maybe_open_initial_location_view()


func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick_advanced)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.location_changed.connect(_on_location_changed)
	GameEvents.entity_stat_changed.connect(_on_entity_stat_changed)
	GameEvents.entity_currency_changed.connect(_on_entity_currency_changed)
	GameEvents.part_equipped.connect(_on_part_equipped)
	GameEvents.part_unequipped.connect(_on_part_unequipped)
	_rebuild_time_buttons()
	_refresh()
	_maybe_open_initial_location_view()


func on_route_revealed() -> void:
	_refresh()


func _refresh() -> void:
	_title_label.text = "Gameplay Shell"
	_subtitle_label.text = "Engine-owned hub for exploration, saves, and session-level actions."
	if GameState.player == null:
		_location_title_label.text = "No Active Session"
		_location_description_label.text = "Start or load a game to enter the shell."
		_location_meta_label.text = ""
		_player_name_label.text = "No player entity is loaded."
		_currency_label.text = ""
		_stats_label.text = ""
		_inventory_label.text = ""
		_time_label.text = ""
		_autosave_label.text = ""
		_equipped_label.text = ""
		_status_label.text = "The gameplay shell becomes available once a runtime session exists."
		_set_buttons_enabled(false)
		return

	var player := GameState.player as EntityInstance
	if player == null:
		_status_label.text = "The gameplay shell could not resolve the active player entity."
		_set_buttons_enabled(false)
		return
	var player_template := player.get_template()
	var player_name := str(player_template.get("display_name", player.entity_id))
	var location_template := DataManager.get_location(GameState.current_location_id)
	var location_name := str(location_template.get("display_name", GameState.current_location_id))
	var location_description := str(location_template.get("description", ""))
	_location_title_label.text = location_name
	_location_description_label.text = location_description if not location_description.is_empty() else "No location description is available yet."
	_location_meta_label.text = _build_location_meta(player)
	_player_name_label.text = "%s\nEntity: %s" % [player_name, player.entity_id]
	_currency_label.text = _build_currency_summary(player)
	_stats_label.text = _build_stat_summary(player)
	_inventory_label.text = _build_inventory_summary(player)
	_time_label.text = "Time: %s" % TimeKeeper.get_time_string()
	_autosave_label.text = _build_autosave_summary()
	_equipped_label.text = _build_equipped_summary(player)
	_status_label.text = _status_message
	_set_buttons_enabled(true)

func _build_currency_summary(player: EntityInstance) -> String:
	if player.currencies.is_empty():
		return "Currencies\nNone"
	var lines: Array[String] = ["Currencies"]
	var keys := player.currencies.keys()
	keys.sort()
	var currency_symbol := str(DataManager.get_config_value("ui.currency_symbol", "$"))
	for key_value in keys:
		var currency_key := str(key_value)
		lines.append("%s %s: %s" % [currency_symbol, currency_key.capitalize(), str(player.currencies[key_value])])
	return "\n".join(lines)


func _build_stat_summary(player: EntityInstance) -> String:
	if player.stats.is_empty():
		return "Stats\nNone"
	var lines: Array[String] = ["Stats"]
	var keys := player.stats.keys()
	keys.sort()
	for key_value in keys:
		var stat_key := str(key_value)
		lines.append("%s: %s" % [stat_key.capitalize(), str(player.stats[key_value])])
	return "\n".join(lines)


func _build_inventory_summary(player: EntityInstance) -> String:
	return "Inventory\nItems: %d\nDiscovered Locations: %d" % [
		player.inventory.size(),
		player.discovered_locations.size(),
	]


func _format_dictionary(values: Dictionary) -> String:
	if values.is_empty():
		return "{}"
	var keys := values.keys()
	keys.sort()
	var items: Array[String] = []
	for key in keys:
		items.append("%s=%s" % [str(key), str(values[key])])
	return "{%s}" % ", ".join(items)


func _format_equipped(player: EntityInstance) -> String:
	if player.equipped.is_empty():
		return "{}"
	var slots := player.equipped.keys()
	slots.sort()
	var items: Array[String] = []
	for slot in slots:
		var part := player.equipped.get(slot, null) as PartInstance
		if part == null:
			continue
		var template := part.get_template()
		var display_name := str(template.get("display_name", part.template_id))
		items.append("%s=%s" % [str(slot), display_name])
	return "{%s}" % ", ".join(items)


func _build_equipped_summary(player: EntityInstance) -> String:
	return "Equipped\n%s" % _format_equipped(player)


func _build_location_meta(player: EntityInstance) -> String:
	var screens_count := 0
	var location_template := DataManager.get_location(GameState.current_location_id)
	var screens_value: Variant = location_template.get("screens", [])
	if screens_value is Array:
		var screens: Array = screens_value
		screens_count = screens.size()
	return "Interactions: %d\nKnown Locations: %d" % [screens_count, player.discovered_locations.size()]


func _build_autosave_summary() -> String:
	var autosave_info := SaveManager.get_slot_info(SaveManager.AUTOSAVE_SLOT)
	if autosave_info.is_empty():
		return "Autosave\nNo autosave has been written yet."
	var updated_at := str(autosave_info.get("updated_at", ""))
	var day := int(autosave_info.get("day", 0))
	var tick := int(autosave_info.get("tick", 0))
	var location_name := str(autosave_info.get("location_name", ""))
	var lines: Array[String] = [
		"Autosave",
		"Last Update: %s" % updated_at,
		"Day %d, Tick %d" % [day, tick],
	]
	if not location_name.is_empty():
		lines.append("Location: %s" % location_name)
	return "\n".join(lines)


func _set_buttons_enabled(enabled: bool) -> void:
	_explore_location_button.disabled = not enabled
	_loadout_button.disabled = not enabled
	_save_browser_button.disabled = not enabled
	_quick_autosave_button.disabled = not enabled
	_advance_tick_button.disabled = not enabled
	_pause_menu_button.disabled = not enabled
	for child in _time_buttons_container.get_children():
		var button := child as Button
		if button != null:
			button.disabled = not enabled


func _rebuild_time_buttons() -> void:
	for child in _time_buttons_container.get_children():
		_time_buttons_container.remove_child(child)
		child.queue_free()
	for spec in _get_time_button_specs():
		var button := Button.new()
		button.text = str(spec.get("label", "Advance"))
		var tick_count := int(spec.get("ticks", 1))
		button.pressed.connect(func() -> void:
			_advance_time_by_ticks(tick_count, str(spec.get("label", "Advance")))
		)
		_time_buttons_container.add_child(button)


func _get_time_button_specs() -> Array[Dictionary]:
	var configured_value: Variant = DataManager.get_config_value("ui.time_advance_buttons", ["1 hour", "1 day"])
	var specs: Array[Dictionary] = []
	if configured_value is Array:
		var configured_buttons: Array = configured_value
		for button_value in configured_buttons:
			var spec := _parse_time_advance_spec(str(button_value))
			if spec.is_empty():
				continue
			specs.append(spec)
	if specs.is_empty():
		specs.append({"label": "1 Hour", "ticks": _get_ticks_per_hour()})
		specs.append({"label": "1 Day", "ticks": TimeKeeper.get_ticks_per_day()})
	return specs


func _parse_time_advance_spec(label: String) -> Dictionary:
	var normalized := label.strip_edges()
	if normalized.is_empty():
		return {}
	var parts := normalized.to_lower().split(" ", false)
	if parts.is_empty():
		return {}
	var quantity := 1
	if parts[0].is_valid_int():
		quantity = maxi(int(parts[0]), 1)
	var unit := parts[parts.size() - 1]
	match unit:
		"tick", "ticks":
			return {"label": normalized.capitalize(), "ticks": quantity}
		"hour", "hours":
			return {"label": normalized.capitalize(), "ticks": quantity * _get_ticks_per_hour()}
		"day", "days":
			return {"label": normalized.capitalize(), "ticks": quantity * TimeKeeper.get_ticks_per_day()}
		_:
			return {}


func _get_ticks_per_hour() -> int:
	var configured_value: Variant = DataManager.get_config_value("game.ticks_per_hour", 0)
	var configured_ticks := int(configured_value)
	if configured_ticks > 0:
		return configured_ticks
	var ticks_per_day := maxi(TimeKeeper.get_ticks_per_day(), 1)
	return maxi(int(round(float(ticks_per_day) / 24.0)), 1)


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


func _on_save_browser_button_pressed() -> void:
	UIRouter.push(SCREEN_SAVE_SLOT_LIST, {
		"mode": "save",
		"close_on_save": true,
	})


func _on_explore_location_button_pressed() -> void:
	UIRouter.push(SCREEN_LOCATION_VIEW)


func _on_open_loadout_button_pressed() -> void:
	UIRouter.push(SCREEN_ASSEMBLY_EDITOR, {
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
