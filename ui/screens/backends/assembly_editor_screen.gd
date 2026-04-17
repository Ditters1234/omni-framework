extends Control

const SCREEN_MAIN_MENU := "main_menu"
const DEFAULT_OPTION_TAG := "character_creator_option"
const EMPTY_LABEL := "<empty>"

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _cancel_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BeginButton
var _currency_summary_panel: CurrencySummaryPanel = null
var _part_detail_panel: PartDetailPanel = null
var _stat_delta_sheet: StatDeltaSheet = null

var _params: Dictionary = {}
var _session: AssemblySession = null
var _slot_states: Dictionary = {}
var _selected_slot_id: String = ""
var _initialized: bool = false
var _target_entity_lookup_id: String = "player"
var _target_runtime_entity_id: String = ""
var _budget_entity_lookup_id: String = ""
var _budget_currency_id: String = "credits"
var _payment_recipient_lookup_id: String = ""
var _option_source_entity_lookup_id: String = ""
var _option_tags: Array[String] = []
var _option_template_ids: Array[String] = []
var _next_screen_id: String = ""
var _cancel_screen_id: String = SCREEN_MAIN_MENU
var _reset_game_state_on_cancel: bool = false
var _pop_on_confirm: bool = false
var _confirm_screen_params: Dictionary = {}
var _cancel_screen_params: Dictionary = {}


func initialize(params: Dictionary = {}) -> void:
	var copied_params: Dictionary = params.duplicate(true)
	_params = copied_params
	if _initialized:
		_apply_screen_params()
		_refresh_editor_state()
		return
	_initialize_editor()


func _ready() -> void:
	call_deferred("_initialize_editor")


func _initialize_editor() -> void:
	if _initialized:
		return
	_initialized = true
	_apply_screen_params()
	var target_entity := _resolve_target_entity()
	if target_entity == null:
		_status_label.text = "No target entity is available for editing."
		_confirm_button.disabled = true
		return
	_session = AssemblySession.new()
	var payer_entity := _resolve_budget_entity(target_entity)
	_session.initialize_from_entity(target_entity, _budget_currency_id, payer_entity)
	_refresh_editor_state()


func _apply_screen_params() -> void:
	_target_entity_lookup_id = str(_params.get("target_entity_id", "player"))
	_budget_entity_lookup_id = str(_params.get("budget_entity_id", ""))
	_budget_currency_id = str(_params.get("budget_currency_id", "credits"))
	_payment_recipient_lookup_id = str(_params.get("payment_recipient_id", ""))
	_option_source_entity_lookup_id = str(_params.get("option_source_entity_id", ""))
	_next_screen_id = str(_params.get("next_screen_id", ""))
	_cancel_screen_id = str(_params.get("cancel_screen_id", SCREEN_MAIN_MENU))
	_reset_game_state_on_cancel = bool(_params.get("reset_game_state_on_cancel", false))
	_pop_on_confirm = bool(_params.get("pop_on_confirm", false))

	var confirm_params_data: Variant = _params.get("next_screen_params", {})
	if confirm_params_data is Dictionary:
		var confirm_params: Dictionary = confirm_params_data
		_confirm_screen_params = confirm_params.duplicate(true)
	var cancel_params_data: Variant = _params.get("cancel_screen_params", {})
	if cancel_params_data is Dictionary:
		var cancel_params: Dictionary = cancel_params_data
		_cancel_screen_params = cancel_params.duplicate(true)

	_option_tags = _to_string_array(_params.get("option_tags", []))
	if _option_tags.is_empty():
		var option_tag := str(_params.get("option_tag", DEFAULT_OPTION_TAG))
		if not option_tag.is_empty():
			_option_tags.append(option_tag)
	_option_template_ids = _to_string_array(_params.get("option_template_ids", []))

	_title_label.text = str(_params.get("screen_title", "Assembly Editor"))
	_description_label.text = str(_params.get("screen_description", "Choose parts for the selected entity from a configured catalog."))
	_summary_label.text = str(_params.get("screen_summary", "Preview parts on the left, inspect the current selection on the right, and confirm when the build looks right."))
	_cancel_button.text = str(_params.get("cancel_label", "Cancel"))
	_confirm_button.text = str(_params.get("confirm_label", "Confirm"))


func _resolve_target_entity() -> EntityInstance:
	var entity: EntityInstance = GameState.get_entity_instance(_target_entity_lookup_id)
	if entity == null and _target_entity_lookup_id == "player":
		entity = GameState.player as EntityInstance
	if entity != null:
		_target_runtime_entity_id = entity.entity_id
	return entity


## Returns the entity whose inventory supplies the parts, or null in catalog mode.
func _resolve_source_entity() -> EntityInstance:
	if _option_source_entity_lookup_id.is_empty():
		return null
	var source: EntityInstance = GameState.get_entity_instance(_option_source_entity_lookup_id)
	if source == null and _option_source_entity_lookup_id == "player":
		source = GameState.player as EntityInstance
	return source


## In inventory mode, removes one instance of each newly equipped template
## from the source entity's inventory and commits the source back to GameState.
func _deduct_from_source_inventory() -> void:
	if _option_source_entity_lookup_id.is_empty() or _session == null:
		return
	var source := _resolve_source_entity()
	if source == null:
		return
	var original := _session.original_entity
	var draft := _session.draft_entity
	if draft == null:
		return
	for slot_value in draft.equipped.keys():
		var slot := str(slot_value)
		var new_template_id := draft.get_equipped_template_id(slot)
		var old_template_id := "" if original == null else original.get_equipped_template_id(slot)
		if new_template_id.is_empty() or new_template_id == old_template_id:
			continue
		_remove_one_from_source_inventory(source, new_template_id)
	GameState.entity_instances[source.entity_id] = source
	var current_player := GameState.player as EntityInstance
	if current_player != null and current_player.entity_id == source.entity_id:
		GameState.player = source


## Removes the first unequipped PartInstance with the given template_id from
## source.inventory. Does nothing if no matching unequipped part is found.
func _remove_one_from_source_inventory(source: EntityInstance, template_id: String) -> void:
	for i in source.inventory.size():
		var part: PartInstance = source.inventory[i]
		if part is PartInstance and part.template_id == template_id and not part.is_equipped:
			source.inventory.remove_at(i)
			return


## Returns the entity that pays the build cost, or null if the target pays itself.
## budget_entity_id can be set to "player" or any entity id to redirect charges.
func _resolve_budget_entity(target_entity: EntityInstance) -> EntityInstance:
	if _budget_entity_lookup_id.is_empty():
		return null
	if _budget_entity_lookup_id == _target_entity_lookup_id:
		return null
	var payer: EntityInstance = GameState.get_entity_instance(_budget_entity_lookup_id)
	if payer == null and _budget_entity_lookup_id == "player":
		payer = GameState.player as EntityInstance
	if payer != null and target_entity != null and payer.entity_id == target_entity.entity_id:
		return null
	return payer


func _refresh_editor_state() -> void:
	if _session == null or _session.draft_entity == null:
		_status_label.text = "No target entity is available for editing."
		return
	_refresh_editor_rows()
	_refresh_sidebar()
	_refresh_status()


func _refresh_editor_rows() -> void:
	var socket_defs: Array[Dictionary] = _session.get_available_socket_definitions()
	var active_slots: Dictionary = {}
	var display_index := 0
	var first_slot_id: String = ""

	for socket_def in socket_defs:
		var slot_id := str(socket_def.get("id", ""))
		if slot_id.is_empty():
			continue
		if first_slot_id.is_empty():
			first_slot_id = slot_id
		active_slots[slot_id] = true
		var state: Dictionary = _ensure_row_state(slot_id, socket_def)
		var row_data: Variant = state.get("row", null)
		var row := row_data as HBoxContainer
		if row:
			_rows_container.move_child(row, display_index)
		display_index += 1

		var options: Array[Dictionary] = _get_options_for_slot(slot_id)
		var current_template_id: String = _session.get_equipped_template_id(slot_id)
		var preview_index: int = _resolve_preview_index(slot_id, options, current_template_id)

		state["definition"] = socket_def
		state["options"] = options
		state["preview_index"] = preview_index
		_slot_states[slot_id] = state
		_render_slot_state(slot_id)

	_remove_stale_rows(active_slots)
	if _selected_slot_id.is_empty() or not active_slots.has(_selected_slot_id):
		_selected_slot_id = first_slot_id


func _ensure_row_state(slot_id: String, socket_def: Dictionary) -> Dictionary:
	if _slot_states.has(slot_id):
		return _slot_states[slot_id]

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_child(row)

	var name_label := Label.new()
	name_label.text = str(socket_def.get("display_label", socket_def.get("label", slot_id)))
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(name_label)

	var prev_button := Button.new()
	prev_button.text = "<"
	row.add_child(prev_button)

	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size = Vector2(260.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	var next_button := Button.new()
	next_button.text = ">"
	row.add_child(next_button)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	row.add_child(apply_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	row.add_child(clear_button)

	prev_button.pressed.connect(_on_cycle_pressed.bind(slot_id, -1))
	next_button.pressed.connect(_on_cycle_pressed.bind(slot_id, 1))
	apply_button.pressed.connect(_on_apply_pressed.bind(slot_id))
	clear_button.pressed.connect(_on_clear_pressed.bind(slot_id))
	row.gui_input.connect(_on_row_gui_input.bind(slot_id))

	return {
		"row": row,
		"name_label": name_label,
		"definition": socket_def,
		"options": [],
		"preview_index": -1,
		"value_label": value_label,
		"prev_button": prev_button,
		"next_button": next_button,
		"apply_button": apply_button,
		"clear_button": clear_button
	}


func _remove_stale_rows(active_slots: Dictionary) -> void:
	var stale_slots: Array[String] = []
	for slot_value in _slot_states.keys():
		var slot_id := str(slot_value)
		if active_slots.has(slot_id):
			continue
		stale_slots.append(slot_id)

	for slot_id in stale_slots:
		var state: Dictionary = _get_slot_state(slot_id)
		var row_data: Variant = state.get("row", null)
		var row := row_data as HBoxContainer
		if row:
			row.queue_free()
		_slot_states.erase(slot_id)
		if _selected_slot_id == slot_id:
			_selected_slot_id = ""


func _get_options_for_slot(slot_id: String) -> Array[Dictionary]:
	if _session == null:
		return []
	if not _option_source_entity_lookup_id.is_empty():
		return _get_inventory_options_for_slot(slot_id)
	return _get_catalog_options_for_slot(slot_id)


## Catalog mode: options come from PartsRegistry filtered by tags/template ids.
func _get_catalog_options_for_slot(slot_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_template_ids: Dictionary = {}
	for template_id in _option_template_ids:
		var template := _get_part_template(template_id)
		if template.is_empty():
			continue
		if not _session.can_equip_template_in_slot(slot_id, template_id):
			continue
		results.append(template)
		seen_template_ids[template_id] = true
	for tag in _option_tags:
		for part in PartsRegistry.get_by_category(tag):
			if not part is Dictionary:
				continue
			var template_id := str(part.get("id", ""))
			if template_id.is_empty() or seen_template_ids.has(template_id):
				continue
			if not _session.can_equip_template_in_slot(slot_id, template_id):
				continue
			results.append(part)
			seen_template_ids[template_id] = true
	results.sort_custom(_sort_options_by_display_name)
	return results


## Inventory mode: options come from the source entity's inventory.
## Only templates that exist in that inventory (and fit the slot) are shown.
## Respects option_tags and option_template_ids as additional filters if set.
func _get_inventory_options_for_slot(slot_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var source := _resolve_source_entity()
	if source == null:
		return results
	var seen_template_ids: Dictionary = {}
	for inventory_part in source.inventory:
		if not inventory_part is PartInstance:
			continue
		var part: PartInstance = inventory_part
		var template_id: String = part.template_id
		if template_id.is_empty() or seen_template_ids.has(template_id):
			continue
		if not _session.can_equip_template_in_slot(slot_id, template_id):
			continue
		if not _option_template_ids.is_empty() and not _option_template_ids.has(template_id):
			continue
		if not _option_tags.is_empty():
			var template := _get_part_template(template_id)
			var part_tags: Array = template.get("tags", [])
			var tag_match := false
			for tag in _option_tags:
				if part_tags.has(tag):
					tag_match = true
					break
			if not tag_match:
				continue
		var tmpl := _get_part_template(template_id)
		if not tmpl.is_empty():
			results.append(tmpl)
			seen_template_ids[template_id] = true
	results.sort_custom(_sort_options_by_display_name)
	return results


func _sort_options_by_display_name(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("display_name", a.get("id", "")))
	var b_name := str(b.get("display_name", b.get("id", "")))
	return a_name.naturalnocasecmp_to(b_name) < 0


func _find_initial_index(options: Array[Dictionary], template_id: String) -> int:
	if template_id.is_empty():
		return -1
	for i in range(options.size()):
		if str(options[i].get("id", "")) == template_id:
			return i
	return -1


func _resolve_preview_index(slot_id: String, options: Array[Dictionary], current_template_id: String) -> int:
	if options.is_empty():
		return -1
	var state: Dictionary = _get_slot_state(slot_id)
	var existing_preview_template_id: String = _preview_template_id_from_state(state)
	var existing_index := _find_initial_index(options, existing_preview_template_id)
	if existing_index >= 0:
		return existing_index
	var current_index := _find_initial_index(options, current_template_id)
	if current_index >= 0:
		return current_index
	return 0


func _on_cycle_pressed(slot_id: String, direction: int) -> void:
	if _session == null or not _slot_states.has(slot_id):
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var options: Array[Dictionary] = _state_options(state)
	if options.is_empty():
		_refresh_sidebar()
		_refresh_status()
		return
	var preview_index := int(state.get("preview_index", -1))
	if preview_index < 0:
		preview_index = 0 if direction > 0 else options.size() - 1
	else:
		preview_index = wrapi(preview_index + direction, 0, options.size())
	state["preview_index"] = preview_index
	_slot_states[slot_id] = state
	_render_slot_state(slot_id)
	_refresh_sidebar()
	_refresh_status()


func _render_slot_state(slot_id: String) -> void:
	if _session == null or not _slot_states.has(slot_id):
		return
	var state: Dictionary = _get_slot_state(slot_id)
	var definition_data: Variant = state.get("definition", {})
	var socket_def: Dictionary = {}
	if definition_data is Dictionary:
		socket_def = definition_data
	var name_label := state.get("name_label", null) as Label
	var options: Array[Dictionary] = _state_options(state)
	var value_label := state.get("value_label", null) as Label
	var prev_button := state.get("prev_button", null) as Button
	var next_button := state.get("next_button", null) as Button
	var apply_button := state.get("apply_button", null) as Button
	var clear_button := state.get("clear_button", null) as Button
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_template_id: String = _preview_template_id_from_state(state)
	if name_label:
		name_label.text = _get_socket_display_label(socket_def, slot_id)
	if options.is_empty():
		if value_label:
			value_label.text = EMPTY_LABEL if current_template_id.is_empty() else _get_template_display_name(current_template_id)
		if prev_button:
			prev_button.disabled = true
		if next_button:
			next_button.disabled = true
		if apply_button:
			apply_button.disabled = true
		if clear_button:
			clear_button.disabled = current_template_id.is_empty()
		return

	var preview_index := int(state.get("preview_index", _find_initial_index(options, current_template_id)))
	if preview_index >= 0:
		preview_index = clampi(preview_index, 0, options.size() - 1)
	state["preview_index"] = preview_index
	_slot_states[slot_id] = state
	var current_name := EMPTY_LABEL if current_template_id.is_empty() else _get_template_display_name(current_template_id)
	var preview_name := current_name if preview_template_id.is_empty() else _get_template_display_name(preview_template_id)
	if value_label:
		value_label.text = current_name if preview_template_id == current_template_id else "%s -> %s" % [current_name, preview_name]
	if prev_button:
		prev_button.disabled = false
	if next_button:
		next_button.disabled = false
	var can_apply := not preview_template_id.is_empty() and preview_template_id != current_template_id and _session.can_afford_template(slot_id, preview_template_id)
	if apply_button:
		apply_button.disabled = not can_apply
	if clear_button:
		clear_button.disabled = current_template_id.is_empty()


func _refresh_sidebar() -> void:
	_refresh_currency_panel()
	_refresh_part_detail_panel()
	_refresh_stat_sheet()


func _get_currency_symbol() -> String:
	var currency_symbol_data: Variant = DataManager.get_config_value("ui.currency_symbol", "")
	if currency_symbol_data is String:
		return str(currency_symbol_data)
	return ""


func _get_part_default_sprite_paths() -> Dictionary:
	var sprite_paths_data: Variant = DataManager.get_config_value("ui.default_sprites.parts", {})
	if sprite_paths_data is Dictionary:
		var sprite_paths: Dictionary = sprite_paths_data
		return sprite_paths.duplicate(true)
	return {}


func _get_currency_summary_panel() -> CurrencySummaryPanel:
	if _currency_summary_panel == null:
		_currency_summary_panel = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/CurrencySummaryPanel") as CurrencySummaryPanel
	return _currency_summary_panel


func _get_part_detail_panel() -> PartDetailPanel:
	if _part_detail_panel == null:
		_part_detail_panel = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/PartDetailPanel") as PartDetailPanel
	return _part_detail_panel


func _get_stat_delta_sheet() -> StatDeltaSheet:
	if _stat_delta_sheet == null:
		_stat_delta_sheet = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/StatDeltaSheet") as StatDeltaSheet
	return _stat_delta_sheet


func _refresh_currency_panel() -> void:
	if _session == null:
		return
	var panel := _get_currency_summary_panel()
	if panel == null:
		return
	panel.render({
		"currency_id": _session.get_budget_currency_id(),
		"currency_symbol": _get_currency_symbol(),
		"budget": _session.starting_budget,
		"spent": _session.get_total_cost(),
		"remaining": _session.get_remaining_budget()
	})


func _refresh_part_detail_panel() -> void:
	if _session == null:
		return
	var panel := _get_part_detail_panel()
	if panel == null:
		return
	var slot_id := _get_active_selected_slot_id()
	if slot_id.is_empty():
		panel.render({
			"slot_label": "Selection",
			"current_name": EMPTY_LABEL,
			"preview_name": "Nothing Selected",
			"description": "Pick a visible socket to browse the parts that fit there.",
			"price_text": "Price: 0",
			"stats_lines": ["No stat changes."],
			"affordable": true,
			"part_template": {},
			"default_sprite_paths": _get_part_default_sprite_paths()
		})
		return
	var state: Dictionary = _get_slot_state(slot_id)
	var definition_data: Variant = state.get("definition", {})
	var socket_def: Dictionary = {}
	if definition_data is Dictionary:
		socket_def = definition_data
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_template_id: String = _preview_template_id_from_state(state)
	var detail_template_id := current_template_id if preview_template_id.is_empty() else preview_template_id
	var template := _get_part_template(detail_template_id)
	var current_name := EMPTY_LABEL if current_template_id.is_empty() else _get_template_display_name(current_template_id)
	var preview_name := current_name if preview_template_id.is_empty() else _get_template_display_name(preview_template_id)
	var description := "This socket is open. Cycle through the available parts to preview what fits here."
	var price_text := "Price: 0"
	var affordable := true
	var stats_lines: Array[String] = ["No stat changes."]
	if not template.is_empty():
		description = str(template.get("description", description))
		price_text = _build_price_text(slot_id, template)
		affordable = preview_template_id.is_empty() or _session.can_afford_template(slot_id, preview_template_id)
		stats_lines = _build_template_stat_lines(template)
	panel.render({
		"slot_label": _get_socket_display_label(socket_def, slot_id),
		"current_name": current_name,
		"preview_name": preview_name,
		"description": description,
		"price_text": price_text,
		"stats_lines": stats_lines,
		"affordable": affordable,
		"part_template": template,
		"default_sprite_paths": _get_part_default_sprite_paths()
	})


func _refresh_stat_sheet() -> void:
	if _session == null:
		return
	var panel := _get_stat_delta_sheet()
	if panel == null:
		return
	var current_stats := _session.get_projected_effective_stats()
	var projected_stats := current_stats
	var slot_id := _get_active_selected_slot_id()
	if not slot_id.is_empty():
		var preview_template_id: String = _get_preview_template_id(slot_id)
		var current_template_id: String = _session.get_equipped_template_id(slot_id)
		if not preview_template_id.is_empty() and preview_template_id != current_template_id:
			projected_stats = _session.get_preview_effective_stats(slot_id, preview_template_id)
	panel.render({
		"title": "Build Stats",
		"current_stats": current_stats,
		"projected_stats": projected_stats
	})


func _refresh_status() -> void:
	if _session == null:
		_status_label.text = "No target entity is available for editing."
		return
	var socket_defs: Array[Dictionary] = _session.get_available_socket_definitions()
	if socket_defs.is_empty():
		_status_label.text = "This entity has no visible assembly sockets."
		return
	var slot_id := _get_active_selected_slot_id()
	if slot_id.is_empty():
		_status_label.text = "Pick a socket to preview the parts that fit there."
		return
	var state: Dictionary = _get_slot_state(slot_id)
	var definition_data: Variant = state.get("definition", {})
	var socket_def: Dictionary = {}
	if definition_data is Dictionary:
		socket_def = definition_data
	var label := _get_socket_display_label(socket_def, slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_template_id: String = _get_preview_template_id(slot_id)
	if preview_template_id.is_empty():
		if current_template_id.is_empty():
			_status_label.text = "%s is open. Cycle through the configured options to preview a change." % label
			return
		_status_label.text = "%s currently uses %s. You can preview another part or clear the slot." % [label, _get_template_display_name(current_template_id)]
		return
	if preview_template_id == current_template_id:
		_status_label.text = "%s currently uses %s." % [label, _get_template_display_name(current_template_id)]
		return
	var currency_id := _session.get_budget_currency_id()
	var remaining_after := _session.get_remaining_budget_after_preview(slot_id, preview_template_id)
	if _session.can_afford_template(slot_id, preview_template_id):
		_status_label.text = "Previewing %s for %s. Applying it will leave %.0f %s." % [_get_template_display_name(preview_template_id), label, remaining_after, currency_id]
	else:
		_status_label.text = "%s would fit in %s, but it would push the build past your %.0f %s budget." % [_get_template_display_name(preview_template_id), label, _session.starting_budget, currency_id]


func _get_template_display_name(template_id: String) -> String:
	var template := _get_part_template(template_id)
	return str(template.get("display_name", template_id))


func _get_part_template(template_id: String) -> Dictionary:
	if template_id.is_empty():
		return {}
	var template_data: Variant = DataManager.get_part(template_id)
	if template_data is Dictionary:
		return template_data
	return {}


func _build_price_text(slot_id: String, template: Dictionary) -> String:
	if _session == null or template.is_empty():
		return "Price: 0"
	var currency_id := _session.get_budget_currency_id()
	var price := _session.get_template_price(template)
	var template_id := str(template.get("id", ""))
	if currency_id.is_empty():
		return "Price: %.0f" % price
	var remaining_after := _session.get_remaining_budget_after_preview(slot_id, template_id)
	return "Price: %.0f %s | Remaining after apply: %.0f" % [price, currency_id, remaining_after]


func _build_template_stat_lines(template: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var stats_data: Variant = template.get("stats", {})
	if not stats_data is Dictionary:
		result.append("No stat changes.")
		return result
	var stats: Dictionary = stats_data
	var stat_keys: Array = stats.keys()
	stat_keys.sort()
	for stat_key in stat_keys:
		var stat_id := str(stat_key)
		var amount := float(stats.get(stat_id, 0.0))
		result.append("%s %+.0f" % [stat_id, amount])
	if result.is_empty():
		result.append("No stat changes.")
	return result


func _state_options(state: Dictionary) -> Array[Dictionary]:
	var options_data: Variant = state.get("options", [])
	var result: Array[Dictionary] = []
	if not options_data is Array:
		return result
	for option in options_data:
		if option is Dictionary:
			result.append(option)
	return result


func _get_slot_state(slot_id: String) -> Dictionary:
	var state_data: Variant = _slot_states.get(slot_id, {})
	if state_data is Dictionary:
		return state_data
	return {}


func _preview_template_id_from_state(state: Dictionary) -> String:
	var options: Array[Dictionary] = _state_options(state)
	if options.is_empty():
		return ""
	var preview_index := int(state.get("preview_index", -1))
	if preview_index < 0 or preview_index >= options.size():
		return ""
	return str(options[preview_index].get("id", ""))


func _get_preview_template_id(slot_id: String) -> String:
	var state: Dictionary = _get_slot_state(slot_id)
	return _preview_template_id_from_state(state)


func _get_active_selected_slot_id() -> String:
	if not _selected_slot_id.is_empty() and _slot_states.has(_selected_slot_id):
		return _selected_slot_id
	if _session == null:
		return ""
	var socket_defs: Array[Dictionary] = _session.get_available_socket_definitions()
	for socket_def in socket_defs:
		var slot_id := str(socket_def.get("id", ""))
		if slot_id.is_empty():
			continue
		_selected_slot_id = slot_id
		return slot_id
	return ""


func _get_socket_display_label(socket_def: Dictionary, slot_id: String) -> String:
	return str(socket_def.get("display_label", socket_def.get("label", slot_id)))


func _on_apply_pressed(slot_id: String) -> void:
	if _session == null:
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var definition_data: Variant = state.get("definition", {})
	var socket_def: Dictionary = {}
	if definition_data is Dictionary:
		socket_def = definition_data
	var label := _get_socket_display_label(socket_def, slot_id)
	var preview_template_id: String = _get_preview_template_id(slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	if preview_template_id.is_empty() or preview_template_id == current_template_id:
		_status_label.text = "There is no pending change to apply in %s." % label
		return
	if not _session.apply_template(slot_id, preview_template_id):
		_status_label.text = "That change cannot be applied right now."
		_refresh_sidebar()
		return
	_refresh_editor_state()
	_status_label.text = "Applied %s to %s." % [_get_template_display_name(preview_template_id), label]


func _on_clear_pressed(slot_id: String) -> void:
	if _session == null:
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var definition_data: Variant = state.get("definition", {})
	var socket_def: Dictionary = {}
	if definition_data is Dictionary:
		socket_def = definition_data
	var label := _get_socket_display_label(socket_def, slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	if current_template_id.is_empty():
		_status_label.text = "%s is already empty." % label
		return
	if not _session.clear_slot(slot_id):
		_status_label.text = "That slot could not be cleared."
		return
	_refresh_editor_state()
	_status_label.text = "Cleared %s." % label


func _on_row_gui_input(event: InputEvent, slot_id: String) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_selected_slot_id = slot_id
	_refresh_sidebar()
	_refresh_status()


func _on_back_button_pressed() -> void:
	if _reset_game_state_on_cancel:
		GameState.reset()
	if _cancel_screen_id.is_empty():
		UIRouter.pop()
		return
	UIRouter.replace_all(_cancel_screen_id, _cancel_screen_params)


func _on_begin_button_pressed() -> void:
	if _session == null:
		_status_label.text = "No target entity is available for editing."
		return
	var committed := _session.get_committed_entity()
	if committed == null:
		_status_label.text = "The edited build could not be finalized."
		return
	_commit_entity_to_game_state(committed)
	var committed_payer := _session.get_committed_payer()
	if committed_payer != null:
		_commit_payer_to_game_state(committed_payer)
	_pay_recipient(_session.get_total_cost())
	_deduct_from_source_inventory()
	if _pop_on_confirm:
		UIRouter.pop()
		return
	if _next_screen_id.is_empty():
		_status_label.text = "Build confirmed."
		return
	UIRouter.replace_all(_next_screen_id, _confirm_screen_params)


func _commit_entity_to_game_state(entity: EntityInstance) -> void:
	if entity == null:
		return
	GameState.entity_instances[entity.entity_id] = entity
	var current_player := GameState.player as EntityInstance
	if _target_entity_lookup_id == "player" or current_player == null or current_player.entity_id == _target_runtime_entity_id:
		GameState.player = entity


## Adds the paid amount to the payment recipient's currency and commits them.
## No-op if payment_recipient_id was not set or the entity cannot be found.
func _pay_recipient(amount: float) -> void:
	if _payment_recipient_lookup_id.is_empty() or amount <= 0.0:
		return
	var recipient: EntityInstance = GameState.get_entity_instance(_payment_recipient_lookup_id)
	if recipient == null:
		return
	recipient.add_currency(_budget_currency_id, amount)
	GameState.entity_instances[recipient.entity_id] = recipient
	var current_player := GameState.player as EntityInstance
	if current_player != null and current_player.entity_id == recipient.entity_id:
		GameState.player = recipient


## Commits the payer entity's updated currency balance back to GameState.
func _commit_payer_to_game_state(payer: EntityInstance) -> void:
	if payer == null:
		return
	GameState.entity_instances[payer.entity_id] = payer
	var current_player := GameState.player as EntityInstance
	if current_player != null and current_player.entity_id == payer.entity_id:
		GameState.player = payer


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(str(value))
	return result
