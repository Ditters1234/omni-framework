extends "res://ui/screens/backends/backend_base.gd"

class_name OmniAssemblyEditorBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const ASSEMBLY_SESSION := preload("res://core/assembly_session.gd")
const ASSEMBLY_COMMIT_SERVICE := preload("res://systems/assembly_commit_service.gd")
const TRANSACTION_SERVICE := preload("res://systems/transaction_service.gd")
const SCREEN_MAIN_MENU := "main_menu"
const DEFAULT_OPTION_TAG := "character_creator_option"
const EMPTY_LABEL := "<empty>"

var _params: Dictionary = {}
var _session: AssemblySession = null
var _slot_states: Dictionary = {}
var _selected_slot_id: String = ""
var _target_entity_lookup_id: String = "player"
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
var _status_override: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("AssemblyEditorBackend", {
		"required": [],
		"optional": [
			"target_entity_id",
			"budget_entity_id",
			"budget_currency_id",
			"payment_recipient_id",
			"option_source_entity_id",
			"option_tags",
			"option_tag",
			"option_template_ids",
			"screen_title",
			"screen_description",
			"screen_summary",
			"cancel_label",
			"confirm_label",
			"next_screen_id",
			"next_screen_params",
			"cancel_screen_id",
			"cancel_screen_params",
			"reset_game_state_on_cancel",
			"pop_on_confirm",
		],
		"field_types": {
			"target_entity_id": TYPE_STRING,
			"budget_entity_id": TYPE_STRING,
			"budget_currency_id": TYPE_STRING,
			"payment_recipient_id": TYPE_STRING,
			"option_source_entity_id": TYPE_STRING,
			"option_tags": TYPE_ARRAY,
			"option_tag": TYPE_STRING,
			"option_template_ids": TYPE_ARRAY,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"next_screen_id": TYPE_STRING,
			"next_screen_params": TYPE_DICTIONARY,
			"cancel_screen_id": TYPE_STRING,
			"cancel_screen_params": TYPE_DICTIONARY,
			"reset_game_state_on_cancel": TYPE_BOOL,
			"pop_on_confirm": TYPE_BOOL,
		},
		"array_element_types": {
			"option_tags": TYPE_STRING,
			"option_template_ids": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_apply_screen_params()
	_initialize_session()


func build_view_model() -> Dictionary:
	var header := _build_header_view_model()
	if _session == null or _session.draft_entity == null:
		return {
			"title": str(header.get("title", "Assembly Editor")),
			"description": str(header.get("description", "Choose parts for the selected entity from a configured catalog.")),
			"summary": str(header.get("summary", "")),
			"cancel_label": str(header.get("cancel_label", "Cancel")),
			"confirm_label": str(header.get("confirm_label", "Confirm")),
			"rows": [],
			"currency_summary": {},
			"part_detail": _build_empty_part_detail_view_model(),
			"stat_delta": {
				"title": "Build Stats",
				"current_stats": {},
				"projected_stats": {},
			},
			"status_text": "No target entity is available for editing.",
			"confirm_enabled": false,
		}

	var rows := _build_row_view_models()
	return {
		"title": str(header.get("title", "Assembly Editor")),
		"description": str(header.get("description", "Choose parts for the selected entity from a configured catalog.")),
		"summary": str(header.get("summary", "")),
		"cancel_label": str(header.get("cancel_label", "Cancel")),
		"confirm_label": str(header.get("confirm_label", "Confirm")),
		"rows": rows,
		"currency_summary": _build_currency_summary_view_model(),
		"part_detail": _build_part_detail_view_model(),
		"stat_delta": _build_stat_delta_view_model(),
		"status_text": _build_status_text(),
		"confirm_enabled": true,
	}


func select_slot(slot_id: String) -> void:
	if not _slot_states.has(slot_id):
		return
	_selected_slot_id = slot_id
	_status_override = ""


func cycle_slot(slot_id: String, direction: int) -> void:
	if _session == null or not _slot_states.has(slot_id):
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var options: Array[Dictionary] = _state_options(state)
	if options.is_empty():
		_status_override = ""
		return
	var preview_index := int(state.get("preview_index", -1))
	if preview_index < 0:
		preview_index = 0 if direction > 0 else options.size() - 1
	else:
		preview_index = wrapi(preview_index + direction, 0, options.size())
	state["preview_index"] = preview_index
	_slot_states[slot_id] = state
	_status_override = ""


func apply_slot(slot_id: String) -> void:
	if _session == null or not _slot_states.has(slot_id):
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
	var label := _get_socket_display_label(socket_def, slot_id)
	var preview_template_id: String = _get_preview_template_id(slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	if preview_template_id.is_empty() or preview_template_id == current_template_id:
		_status_override = "There is no pending change to apply in %s." % label
		return
	if not _session.apply_template(slot_id, preview_template_id):
		_status_override = "That change cannot be applied right now."
		return
	_status_override = "Applied %s to %s." % [_get_template_display_name(preview_template_id), label]


func clear_slot(slot_id: String) -> void:
	if _session == null or not _slot_states.has(slot_id):
		return
	_selected_slot_id = slot_id
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
	var label := _get_socket_display_label(socket_def, slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	if current_template_id.is_empty():
		_status_override = "%s is already empty." % label
		return
	if not _session.clear_slot(slot_id):
		_status_override = "That slot could not be cleared."
		return
	_status_override = "Cleared %s." % label


func build_cancel_action() -> Dictionary:
	if _reset_game_state_on_cancel:
		GameState.reset()
	if _cancel_screen_id.is_empty():
		return {"type": "pop"}
	return {
		"type": "replace_all",
		"screen_id": _cancel_screen_id,
		"params": _cancel_screen_params.duplicate(true),
	}


func confirm() -> Dictionary:
	if _session == null:
		_status_override = "No target entity is available for editing."
		return {}
	var committed := _session.get_committed_entity()
	if committed == null:
		_status_override = "The edited build could not be finalized."
		return {}
	var committed_payer := _session.get_committed_payer()
	if not _apply_confirm_transaction_effects(committed, committed_payer):
		_status_override = "The transaction could not be completed."
		return {}
	_commit_target_entity_to_game_state(committed)
	if committed_payer != null:
		_commit_entity_to_game_state(committed_payer, _budget_entity_lookup_id)
	_deduct_from_source_inventory()
	_status_override = "Build confirmed."
	if _pop_on_confirm:
		return {"type": "pop"}
	if _next_screen_id.is_empty():
		return {}
	return {
		"type": "replace_all",
		"screen_id": _next_screen_id,
		"params": _confirm_screen_params.duplicate(true),
	}


func get_required_params() -> Array[String]:
	return []


func _initialize_session() -> void:
	var target_entity := _resolve_target_entity()
	if target_entity == null:
		_session = null
		_slot_states.clear()
		_selected_slot_id = ""
		return
	_session = ASSEMBLY_SESSION.new()
	var payer_entity := _resolve_budget_entity(target_entity)
	_session.initialize_from_entity(target_entity, _budget_currency_id, payer_entity)


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
	_confirm_screen_params = {}
	if confirm_params_data is Dictionary:
		var confirm_params: Dictionary = confirm_params_data
		_confirm_screen_params = confirm_params.duplicate(true)

	var cancel_params_data: Variant = _params.get("cancel_screen_params", {})
	_cancel_screen_params = {}
	if cancel_params_data is Dictionary:
		var cancel_params: Dictionary = cancel_params_data
		_cancel_screen_params = cancel_params.duplicate(true)

	_option_tags = _to_string_array(_params.get("option_tags", []))
	if _option_tags.is_empty():
		var option_tag := str(_params.get("option_tag", DEFAULT_OPTION_TAG))
		if not option_tag.is_empty():
			_option_tags.append(option_tag)
	_option_template_ids = _to_string_array(_params.get("option_template_ids", []))


func _build_header_view_model() -> Dictionary:
	return {
		"title": str(_params.get("screen_title", "Assembly Editor")),
		"description": str(_params.get("screen_description", "Choose parts for the selected entity from a configured catalog.")),
		"summary": str(_params.get("screen_summary", "Preview parts on the left, inspect the current selection on the right, and confirm when the build looks right.")),
		"cancel_label": str(_params.get("cancel_label", "Cancel")),
		"confirm_label": str(_params.get("confirm_label", "Confirm")),
	}


func _build_row_view_models() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _session == null:
		return rows
	var socket_defs: Array[Dictionary] = _session.get_available_socket_definitions()
	var active_slots: Dictionary = {}
	var first_slot_id: String = ""
	for socket_def in socket_defs:
		var slot_id := str(socket_def.get("id", ""))
		if slot_id.is_empty():
			continue
		if first_slot_id.is_empty():
			first_slot_id = slot_id
		active_slots[slot_id] = true
		var options: Array[Dictionary] = _get_options_for_slot(slot_id)
		var current_template_id: String = _session.get_equipped_template_id(slot_id)
		var preview_index: int = _resolve_preview_index(slot_id, options, current_template_id)
		_slot_states[slot_id] = {
			"definition": socket_def,
			"options": options,
			"preview_index": preview_index,
		}
	_remove_stale_slots(active_slots)
	if _selected_slot_id.is_empty() or not active_slots.has(_selected_slot_id):
		_selected_slot_id = first_slot_id
	for socket_def in socket_defs:
		var slot_id := str(socket_def.get("id", ""))
		if slot_id.is_empty():
			continue
		rows.append(_build_row_view_model(slot_id))
	return rows


func _build_row_view_model(slot_id: String) -> Dictionary:
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
	var options: Array[Dictionary] = _state_options(state)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_template_id: String = _preview_template_id_from_state(state)
	var current_name := EMPTY_LABEL if current_template_id.is_empty() else _get_template_display_name(current_template_id)
	var preview_name := current_name if preview_template_id.is_empty() else _get_template_display_name(preview_template_id)
	var can_apply := false
	if not preview_template_id.is_empty() and preview_template_id != current_template_id:
		can_apply = _session.can_afford_template(slot_id, preview_template_id)
	return {
		"slot_id": slot_id,
		"slot_label": _get_socket_display_label(socket_def, slot_id),
		"current_name": current_name,
		"preview_name": preview_name,
		"has_options": not options.is_empty(),
		"can_apply": can_apply,
		"can_clear": not current_template_id.is_empty(),
		"selected": slot_id == _selected_slot_id,
	}


func _build_currency_summary_view_model() -> Dictionary:
	if _session == null:
		return {}
	return {
		"currency_id": _session.get_budget_currency_id(),
		"currency_symbol": _get_currency_symbol(),
		"budget": _session.starting_budget,
		"spent": _session.get_total_cost(),
		"remaining": _session.get_remaining_budget(),
	}


func _build_part_detail_view_model() -> Dictionary:
	if _session == null:
		return _build_empty_part_detail_view_model()
	var slot_id := _get_active_selected_slot_id()
	if slot_id.is_empty():
		return _build_empty_part_detail_view_model()
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
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
	return {
		"slot_label": _get_socket_display_label(socket_def, slot_id),
		"current_name": current_name,
		"preview_name": preview_name,
		"description": description,
		"price_text": price_text,
		"stats_lines": stats_lines,
		"affordable": affordable,
		"part_template": template,
		"default_sprite_paths": _get_part_default_sprite_paths(),
	}


func _build_empty_part_detail_view_model() -> Dictionary:
	return {
		"slot_label": "Selection",
		"current_name": EMPTY_LABEL,
		"preview_name": "Nothing Selected",
		"description": "Pick a visible socket to browse the parts that fit there.",
		"price_text": "Price: 0",
		"stats_lines": ["No stat changes."],
		"affordable": true,
		"part_template": {},
		"default_sprite_paths": _get_part_default_sprite_paths(),
	}


func _build_stat_delta_view_model() -> Dictionary:
	if _session == null:
		return {
			"title": "Build Stats",
			"current_stats": {},
			"projected_stats": {},
		}
	var current_stats := _session.get_projected_effective_stats()
	var projected_stats := current_stats
	var slot_id := _get_active_selected_slot_id()
	if not slot_id.is_empty():
		var preview_template_id: String = _get_preview_template_id(slot_id)
		var current_template_id: String = _session.get_equipped_template_id(slot_id)
		if not preview_template_id.is_empty() and preview_template_id != current_template_id:
			projected_stats = _session.get_preview_effective_stats(slot_id, preview_template_id)
	return {
		"title": "Build Stats",
		"current_stats": current_stats,
		"projected_stats": projected_stats,
	}


func _build_status_text() -> String:
	if not _status_override.is_empty():
		return _status_override
	if _session == null:
		return "No target entity is available for editing."
	var socket_defs: Array[Dictionary] = _session.get_available_socket_definitions()
	if socket_defs.is_empty():
		return "This entity has no visible assembly sockets."
	var slot_id := _get_active_selected_slot_id()
	if slot_id.is_empty():
		return "Pick a socket to preview the parts that fit there."
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
	var label := _get_socket_display_label(socket_def, slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_template_id: String = _get_preview_template_id(slot_id)
	if preview_template_id.is_empty():
		if current_template_id.is_empty():
			return "%s is open. Cycle through the configured options to preview a change." % label
		return "%s currently uses %s. You can preview another part or clear the slot." % [label, _get_template_display_name(current_template_id)]
	if preview_template_id == current_template_id:
		return "%s currently uses %s." % [label, _get_template_display_name(current_template_id)]
	var currency_id := _session.get_budget_currency_id()
	var remaining_after := _session.get_remaining_budget_after_preview(slot_id, preview_template_id)
	if _session.can_afford_template(slot_id, preview_template_id):
		return "Previewing %s for %s. Applying it will leave %.0f %s." % [_get_template_display_name(preview_template_id), label, remaining_after, currency_id]
	return "%s would fit in %s, but it would push the build past your %.0f %s budget." % [_get_template_display_name(preview_template_id), label, _session.starting_budget, currency_id]


func _resolve_target_entity() -> EntityInstance:
	var entity: EntityInstance = GameState.get_entity_instance(_target_entity_lookup_id)
	if entity == null and _target_entity_lookup_id == "player":
		entity = GameState.player as EntityInstance
	return entity


func _resolve_source_entity() -> EntityInstance:
	if _option_source_entity_lookup_id.is_empty():
		return null
	var source: EntityInstance = GameState.get_entity_instance(_option_source_entity_lookup_id)
	if source == null and _option_source_entity_lookup_id == "player":
		source = GameState.player as EntityInstance
	return source


func _resolve_payment_recipient_entity() -> EntityInstance:
	if _payment_recipient_lookup_id.is_empty():
		return null
	var recipient: EntityInstance = GameState.get_entity_instance(_payment_recipient_lookup_id)
	if recipient == null and _payment_recipient_lookup_id == "player":
		recipient = GameState.player as EntityInstance
	return recipient


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


func _deduct_from_source_inventory() -> void:
	if _option_source_entity_lookup_id.is_empty() or _session == null:
		return
	var source := _resolve_source_entity()
	if source == null:
		return
	var committed_source := source.duplicate_instance()
	var template_ids: Array[String] = _session.get_newly_equipped_template_ids()
	for template_id in template_ids:
		TRANSACTION_SERVICE.remove_one_inventory_template(committed_source, template_id)
	GameState.commit_entity_instance(committed_source, _option_source_entity_lookup_id)


func _get_options_for_slot(slot_id: String) -> Array[Dictionary]:
	if _session == null:
		return []
	if not _option_source_entity_lookup_id.is_empty():
		return _get_inventory_options_for_slot(slot_id)
	return _get_catalog_options_for_slot(slot_id)


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
		var template := _get_part_template(template_id)
		if template.is_empty():
			continue
		results.append(template)
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
	for index in range(options.size()):
		if str(options[index].get("id", "")) == template_id:
			return index
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


func _read_definition(state: Dictionary) -> Dictionary:
	var definition_data: Variant = state.get("definition", {})
	if definition_data is Dictionary:
		return definition_data
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


func _remove_stale_slots(active_slots: Dictionary) -> void:
	var stale_slots: Array[String] = []
	for slot_value in _slot_states.keys():
		var slot_id := str(slot_value)
		if active_slots.has(slot_id):
			continue
		stale_slots.append(slot_id)
	for slot_id in stale_slots:
		_slot_states.erase(slot_id)
		if _selected_slot_id == slot_id:
			_selected_slot_id = ""


func _commit_target_entity_to_game_state(entity: EntityInstance) -> void:
	if entity == null or _session == null:
		return
	ASSEMBLY_COMMIT_SERVICE.commit_entity(_session.original_entity, entity, _target_entity_lookup_id)


func _commit_entity_to_game_state(entity: EntityInstance, lookup_id: String = "") -> void:
	if entity == null:
		return
	GameState.commit_entity_instance(entity, lookup_id)


func _apply_confirm_transaction_effects(committed_target: EntityInstance, committed_payer: EntityInstance) -> bool:
	if _session == null:
		return false
	var total_cost := _session.get_total_cost()
	var buyer := committed_target if committed_payer == null else committed_payer
	if buyer == null:
		return false
	return _commit_payment_recipient(buyer, total_cost)


func _commit_payment_recipient(buyer: EntityInstance, amount: float) -> bool:
	if amount <= 0.0 or _budget_currency_id.is_empty():
		return true
	var recipient := _resolve_payment_recipient_entity()
	if recipient == null:
		return TRANSACTION_SERVICE.spend_currency(buyer, _budget_currency_id, amount)
	var committed_recipient := recipient.duplicate_instance()
	if not TRANSACTION_SERVICE.transfer_currency(buyer, committed_recipient, _budget_currency_id, amount):
		return false
	_commit_entity_to_game_state(committed_recipient, _payment_recipient_lookup_id)
	return true


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(str(value))
	return result
