extends Control

const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_SAVE_SLOT_LIST := "save_slot_list"
const SCREEN_PAUSE_MENU := "pause_menu"
const CURRENCY_DISPLAY_SCENE := preload("res://ui/components/currency_display.tscn")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")

@onready var _title_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/SubtitleLabel
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
@onready var _save_browser_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/SaveBrowserButton
@onready var _quick_autosave_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/QuickAutosaveButton
@onready var _advance_tick_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/TimePanel/MarginContainer/VBoxContainer/AdvanceTickButton
@onready var _pause_menu_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/ContentColumns/RightColumn/ActionsPanel/MarginContainer/VBoxContainer/PauseMenuButton
@onready var _status_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/StatusLabel

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
		_player_portrait.call("render", {
			"display_name": "No Active Session",
			"description": "Start or load a game to render the current runtime profile.",
			"stat_preview": [],
		})
		_render_currency_displays([])
		_player_stat_sheet.call("render", {
			"title": "Player Stats",
			"groups": {},
		})
		_inventory_label.text = ""
		_time_label.text = ""
		_autosave_label.text = ""
		_render_equipped_cards(null)
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
	_player_portrait.call("render", _build_player_portrait_view_model(player, player_template, player_name))
	_render_currency_displays(_build_currency_view_models(player))
	_player_stat_sheet.call("render", _build_stat_sheet_view_model(player))
	_inventory_label.text = _build_inventory_summary(player)
	_time_label.text = "Time: %s" % TimeKeeper.get_time_string()
	_autosave_label.text = _build_autosave_summary()
	_render_equipped_cards(player)
	_status_label.text = _status_message
	_set_buttons_enabled(true)

func _build_player_portrait_view_model(player: EntityInstance, player_template: Dictionary, player_name: String) -> Dictionary:
	return {
		"display_name": player_name,
		"description": str(player_template.get("description", "No player description is available.")),
		"emblem_path": _resolve_entity_emblem_path(player_template),
		"faction_badge": {"label": "Runtime Profile"},
		"stat_preview": _build_priority_stat_preview(player),
	}


func _build_currency_view_models(player: EntityInstance) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if player.currencies.is_empty():
		return results
	var currency_symbol := str(DataManager.get_config_value("ui.currency_symbol", "$"))
	var keys: Array = player.currencies.keys()
	keys.sort()
	for key_value in keys:
		var currency_key := str(key_value)
		results.append({
			"currency_id": currency_key,
			"label": _humanize_id(currency_key),
			"amount": float(player.currencies.get(currency_key, 0.0)),
			"symbol": currency_symbol,
			"color_token": "primary",
		})
	return results


func _render_currency_displays(view_models: Array[Dictionary]) -> void:
	_clear_container_children(_currency_list)
	if view_models.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No currencies available."
		_currency_list.add_child(empty_label)
		return
	for view_model in view_models:
		var display_value: Variant = CURRENCY_DISPLAY_SCENE.instantiate()
		if not display_value is Control:
			continue
		var display: Control = display_value
		_currency_list.add_child(display)
		display.call("render", view_model)


func _render_equipped_cards(player: EntityInstance) -> void:
	_clear_container_children(_equipped_cards)
	if player == null or player.equipped.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No equipped parts are active in this loadout yet."
		_equipped_cards.add_child(empty_label)
		return
	var default_sprite_paths := _get_part_default_sprite_paths()
	for view_model in _build_equipped_part_view_models(player, default_sprite_paths):
		var part_card_value: Variant = PART_CARD_SCENE.instantiate()
		if not part_card_value is Control:
			continue
		var part_card: Control = part_card_value
		_equipped_cards.add_child(part_card)
		part_card.call("render", view_model)


func _build_stat_sheet_view_model(player: EntityInstance) -> Dictionary:
	var groups: Dictionary = {}
	var added_stat_ids: Dictionary = {}
	var stat_definitions: Array = DataManager.get_definitions("stats")
	for stat_definition_value in stat_definitions:
		if not stat_definition_value is Dictionary:
			continue
		var stat_definition: Dictionary = stat_definition_value
		var stat_id := str(stat_definition.get("id", ""))
		if stat_id.is_empty():
			continue
		var kind := str(stat_definition.get("kind", "flat"))
		if kind == "capacity":
			continue
		var line := _build_stat_line(player, stat_definition)
		if line.is_empty():
			continue
		var group_name := str(stat_definition.get("ui_group", "other"))
		if not groups.has(group_name):
			groups[group_name] = []
		var group_lines_value: Variant = groups.get(group_name, [])
		if group_lines_value is Array:
			var group_lines: Array = group_lines_value
			group_lines.append(line)
			groups[group_name] = group_lines
		added_stat_ids[stat_id] = true

	var extra_keys: Array = player.stats.keys()
	extra_keys.sort()
	for stat_key_value in extra_keys:
		var stat_key := str(stat_key_value)
		if stat_key.ends_with("_max") or added_stat_ids.has(stat_key):
			continue
		if not groups.has("other"):
			groups["other"] = []
		var extra_line := {
			"stat_id": stat_key,
			"label": _humanize_id(stat_key),
			"value": float(player.stats.get(stat_key, 0.0)),
			"color_token": "info",
		}
		var other_group_value: Variant = groups.get("other", [])
		if other_group_value is Array:
			var other_group: Array = other_group_value
			other_group.append(extra_line)
			groups["other"] = other_group

	return {
		"title": "Player Stats",
		"groups": groups,
	}


func _build_stat_line(player: EntityInstance, stat_definition: Dictionary) -> Dictionary:
	var stat_id := str(stat_definition.get("id", ""))
	if stat_id.is_empty() or not player.stats.has(stat_id):
		return {}
	var kind := str(stat_definition.get("kind", "flat"))
	var color_token := _color_token_for_group(str(stat_definition.get("ui_group", "other")))
	if kind == "resource":
		var capacity_id := str(stat_definition.get("paired_capacity_id", ""))
		return {
			"stat_id": stat_id,
			"label": _humanize_id(stat_id),
			"value": float(player.stats.get(stat_id, 0.0)),
			"max_value": float(player.stats.get(capacity_id, 0.0)),
			"color_token": color_token,
		}
	return {
		"stat_id": stat_id,
		"label": _humanize_id(stat_id),
		"value": float(player.stats.get(stat_id, 0.0)),
		"color_token": color_token,
	}


func _build_priority_stat_preview(player: EntityInstance) -> Array[Dictionary]:
	var preview_lines: Array[Dictionary] = []
	var stat_definitions: Array = DataManager.get_definitions("stats")
	for stat_definition_value in stat_definitions:
		if not stat_definition_value is Dictionary:
			continue
		var stat_definition: Dictionary = stat_definition_value
		if str(stat_definition.get("kind", "flat")) != "resource":
			continue
		var line := _build_stat_line(player, stat_definition)
		if line.is_empty():
			continue
		preview_lines.append(line)
		if preview_lines.size() >= 2:
			return preview_lines
	if preview_lines.is_empty():
		var stat_keys: Array = player.stats.keys()
		stat_keys.sort()
		for stat_key_value in stat_keys:
			var stat_key := str(stat_key_value)
			if stat_key.ends_with("_max"):
				continue
			preview_lines.append({
				"stat_id": stat_key,
				"label": _humanize_id(stat_key),
				"value": float(player.stats.get(stat_key, 0.0)),
				"color_token": "info",
			})
			break
	return preview_lines


func _resolve_entity_emblem_path(player_template: Dictionary) -> String:
	var emblem_keys := ["emblem_path", "portrait", "sprite"]
	for emblem_key_value in emblem_keys:
		var emblem_key := str(emblem_key_value)
		var resource_path := str(player_template.get(emblem_key, ""))
		if resource_path.is_empty():
			continue
		if ResourceLoader.exists(resource_path):
			return resource_path
	return ""


func _color_token_for_group(group_name: String) -> String:
	match group_name:
		"combat":
			return "warning"
		"survival":
			return "positive"
		"economy":
			return "primary"
		_:
			return "info"


func _humanize_id(value: String) -> String:
	if value.is_empty():
		return ""
	var words := value.split("_", false)
	var formatted_words: Array[String] = []
	for word_value in words:
		var word := str(word_value)
		if word.is_empty():
			continue
		formatted_words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(formatted_words)


func _build_inventory_summary(player: EntityInstance) -> String:
	return "Inventory\nItems: %d\nDiscovered Locations: %d" % [
		player.inventory.size(),
		player.discovered_locations.size(),
	]


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


func _build_equipped_part_view_models(player: EntityInstance, default_sprite_paths: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var slots: Array = player.equipped.keys()
	slots.sort()
	for slot_value in slots:
		var slot_id := str(slot_value)
		var equipped_value: Variant = player.equipped.get(slot_id, null)
		var part := equipped_value as PartInstance
		if part == null:
			continue
		var template_value: Variant = part.get_template()
		if not template_value is Dictionary:
			continue
		var template_copy_value: Variant = template_value.duplicate(true)
		if not template_copy_value is Dictionary:
			continue
		var template: Dictionary = template_copy_value
		if template.is_empty():
			continue
		results.append({
			"template": template,
			"default_sprite_paths": default_sprite_paths,
			"price_text": "",
			"badges": [
				{"label": _humanize_id(slot_id), "color_token": "primary"},
				{"label": "Equipped", "color_token": "positive"},
			],
			"affordable": true,
		})
	return results


func _get_part_default_sprite_paths() -> Dictionary:
	var sprite_paths_data: Variant = DataManager.get_config_value("ui.default_sprites.parts", {})
	if sprite_paths_data is Dictionary:
		var sprite_paths: Dictionary = sprite_paths_data
		return sprite_paths.duplicate(true)
	return {}


func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


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
