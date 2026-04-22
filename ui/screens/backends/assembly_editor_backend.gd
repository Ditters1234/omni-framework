extends "res://ui/screens/backends/backend_base.gd"

class_name OmniAssemblyEditorBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const ASSEMBLY_SESSION := preload("res://core/assembly_session.gd")
const ASSEMBLY_COMMIT_SERVICE := preload("res://systems/assembly_commit_service.gd")
const TRANSACTION_SERVICE := preload("res://systems/transaction_service.gd")
const ASSEMBLY_EDITOR_CONFIG := preload("res://ui/screens/backends/assembly_editor_config.gd")
const ASSEMBLY_EDITOR_OPTION_PROVIDER := preload("res://ui/screens/backends/assembly_editor_option_provider.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const EMPTY_LABEL := "<empty>"

var _config = ASSEMBLY_EDITOR_CONFIG.new()
var _session: AssemblySession = null
var _option_provider = ASSEMBLY_EDITOR_OPTION_PROVIDER.new()
var _slot_states: Dictionary = {}
var _selected_slot_id: String = ""
var _status_override: String = ""
var _pending_part_removed_events: Array[Dictionary] = []
var _pending_transaction_events: Array[Dictionary] = []


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
			"allow_confirm_without_changes",
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
			"allow_confirm_without_changes": TYPE_BOOL,
		},
		"array_element_types": {
			"option_tags": TYPE_STRING,
			"option_template_ids": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_config = ASSEMBLY_EDITOR_CONFIG.new()
	_config.apply_params(params)
	_initialize_session()


func build_view_model() -> Dictionary:
	var header: Dictionary = _config.build_header_view_model()
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
				"baseline_stats": {},
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
		"confirm_enabled": _can_confirm(),
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
	var preview_option := _get_preview_option(slot_id)
	var preview_template_id := _get_option_template_id(preview_option)
	if preview_template_id.is_empty() or _option_matches_current(slot_id, preview_option):
		_status_override = "There is no pending change to apply in %s." % label
		return
	if not _can_apply_option(slot_id, preview_option):
		_status_override = "%s would exceed the current build budget." % _get_template_display_name(preview_template_id)
		return
	if not _apply_option(slot_id, preview_option):
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
	if _config.reset_game_state_on_cancel:
		GameState.reset()
	return _config.build_cancel_action()


func confirm() -> Dictionary:
	var config: OmniAssemblyEditorConfig = _config
	if config == null:
		return {}

	var session: AssemblySession = _session
	if session == null:
		return {}

	if not _can_confirm():
		_status_override = "This build is not ready to confirm yet."
		return {}

	var committed_entity: EntityInstance = session.get_committed_entity()
	var committed_payer: EntityInstance = session.get_committed_payer()
	var previous_entity: EntityInstance = session.original_entity

	if committed_entity == null:
		_status_override = "No target entity is available for confirmation."
		return {}

	var staged_entities: Dictionary = {}
	_pending_part_removed_events.clear()
	_pending_transaction_events.clear()
	_stage_entity(staged_entities, committed_entity, config.target_entity_lookup_id)
	if committed_payer != null:
		_stage_entity(staged_entities, committed_payer, config.budget_entity_lookup_id)

	if not _stage_source_inventory_changes(staged_entities):
		_pending_part_removed_events.clear()
		_pending_transaction_events.clear()
		_status_override = "Unable to consume the required source inventory for that build."
		return {}

	if not _apply_confirm_transaction_effects(staged_entities, committed_entity, committed_payer):
		_pending_part_removed_events.clear()
		_pending_transaction_events.clear()
		_status_override = "Unable to apply the currency changes for that build."
		return {}

	_commit_staged_entities(staged_entities, committed_entity.entity_id, previous_entity)
	_emit_pending_part_removed_events()
	_emit_pending_transaction_events()

	_status_override = ""
	return config.build_confirm_navigation_action()


func get_required_params() -> Array[String]:
	return []


func _initialize_session() -> void:
	var target_entity := _resolve_target_entity()
	if target_entity == null:
		_session = null
		_option_provider = ASSEMBLY_EDITOR_OPTION_PROVIDER.new()
		_slot_states.clear()
		_selected_slot_id = ""
		return
	_session = ASSEMBLY_SESSION.new()
	var payer_entity := _resolve_budget_entity(target_entity)
	_session.initialize_from_entity(target_entity, _config.budget_currency_id, payer_entity)
	_option_provider = ASSEMBLY_EDITOR_OPTION_PROVIDER.new()
	_option_provider.initialize(
		_session,
		_resolve_source_entity(),
		_config.option_tags,
		_config.option_template_ids
	)


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
	var preview_option := _preview_option_from_state(state)
	var preview_template_id := _get_option_template_id(preview_option)
	var current_name := EMPTY_LABEL if current_template_id.is_empty() else _get_template_display_name(current_template_id)
	var preview_name := current_name if preview_template_id.is_empty() else _get_template_display_name(preview_template_id)
	var can_apply := false
	if not preview_template_id.is_empty() and not _option_matches_current(slot_id, preview_option):
		can_apply = _can_apply_option(slot_id, preview_option)
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
		"spent": _get_confirm_total_cost(),
		"remaining": _session.starting_budget - _get_confirm_total_cost(),
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
	var preview_option := _preview_option_from_state(state)
	var preview_template_id := _get_option_template_id(preview_option)
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
		price_text = _build_price_text(slot_id, preview_option if not preview_option.is_empty() else template)
		affordable = preview_template_id.is_empty() or _can_apply_option(slot_id, preview_option)
		stats_lines = _build_template_stat_lines(template)
		var available_count := int(preview_option.get("_inventory_count", -1))
		if available_count >= 0:
			stats_lines.append("Available in source inventory: %s" % str(available_count))
		var custom_summary := _build_option_custom_summary(preview_option)
		if not custom_summary.is_empty():
			stats_lines.append(custom_summary)
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
			"baseline_stats": {},
			"current_stats": {},
			"projected_stats": {},
		}
	var baseline_stats := _session.get_current_effective_stats()
	var current_stats := _session.get_projected_effective_stats()
	var projected_stats := current_stats
	var slot_id := _get_active_selected_slot_id()
	if not slot_id.is_empty():
		var preview_option := _get_preview_option(slot_id)
		var preview_template_id := _get_option_template_id(preview_option)
		if not preview_template_id.is_empty() and not _option_matches_current(slot_id, preview_option):
			if _is_inventory_option(preview_option):
				var source_part := _get_source_inventory_part(_get_option_instance_id(preview_option))
				if source_part != null:
					projected_stats = _session.get_preview_effective_stats_for_part_instance(slot_id, source_part)
			else:
				projected_stats = _session.get_preview_effective_stats(slot_id, preview_template_id)
	return {
		"title": "Build Stats",
		"baseline_stats": baseline_stats,
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
	if not _has_sufficient_source_inventory():
		return "The current draft uses more parts than the source inventory can provide."
	var slot_id := _get_active_selected_slot_id()
	if slot_id.is_empty():
		return "Pick a socket to preview the parts that fit there."
	var state: Dictionary = _get_slot_state(slot_id)
	var socket_def := _read_definition(state)
	var label := _get_socket_display_label(socket_def, slot_id)
	var current_template_id: String = _session.get_equipped_template_id(slot_id)
	var preview_option := _get_preview_option(slot_id)
	var preview_template_id := _get_option_template_id(preview_option)
	if preview_template_id.is_empty():
		if current_template_id.is_empty():
			return "%s is open. Cycle through the configured options to preview a change." % label
		return "%s currently uses %s. You can preview another part or clear the slot." % [label, _get_template_display_name(current_template_id)]
	if _option_matches_current(slot_id, preview_option):
		return "%s currently uses %s." % [label, _get_template_display_name(current_template_id)]
	var currency_id := _session.get_budget_currency_id()
	var remaining_after := _get_remaining_budget_after_preview(slot_id, preview_option)
	if _is_free_inventory_option(preview_option):
		return "Previewing owned %s for %s. Applying it will move that part from inventory into the slot." % [_get_template_display_name(preview_template_id), label]
	if _can_apply_option(slot_id, preview_option):
		return "Previewing %s for %s. Applying it will leave %.0f %s." % [_get_template_display_name(preview_template_id), label, remaining_after, currency_id]
	return "%s would fit in %s, but it would push the build past your %.0f %s budget." % [_get_template_display_name(preview_template_id), label, _session.starting_budget, currency_id]


func _resolve_target_entity() -> EntityInstance:
	var entity: EntityInstance = GameState.get_entity_instance(_config.target_entity_lookup_id)
	if entity == null and _config.target_entity_lookup_id == "player":
		entity = GameState.player as EntityInstance
	return entity


func _resolve_source_entity() -> EntityInstance:
	if _config.option_source_entity_lookup_id.is_empty():
		return null
	var source: EntityInstance = GameState.get_entity_instance(_config.option_source_entity_lookup_id)
	if source == null and _config.option_source_entity_lookup_id == "player":
		source = GameState.player as EntityInstance
	return source


func _resolve_payment_recipient_entity() -> EntityInstance:
	if _config.payment_recipient_lookup_id.is_empty():
		return null
	var recipient: EntityInstance = GameState.get_entity_instance(_config.payment_recipient_lookup_id)
	if recipient == null and _config.payment_recipient_lookup_id == "player":
		recipient = GameState.player as EntityInstance
	return recipient


func _resolve_budget_entity(target_entity: EntityInstance) -> EntityInstance:
	if _config.budget_entity_lookup_id.is_empty():
		return null
	if _config.budget_entity_lookup_id == _config.target_entity_lookup_id:
		return null
	var payer: EntityInstance = GameState.get_entity_instance(_config.budget_entity_lookup_id)
	if payer == null and _config.budget_entity_lookup_id == "player":
		payer = GameState.player as EntityInstance
	if payer != null and target_entity != null and payer.entity_id == target_entity.entity_id:
		return null
	return payer


func _stage_source_inventory_changes(staged_entities: Dictionary) -> bool:
	if _config.option_source_entity_lookup_id.is_empty() or _session == null:
		return true
	var source := _resolve_source_entity()
	if source == null:
		return false
	var target := _resolve_target_entity()
	if target != null and source.entity_id == target.entity_id:
		return true
	var staged_source := _stage_entity(staged_entities, source.duplicate_instance(), _config.option_source_entity_lookup_id)
	if staged_source == null:
		return false
	var instance_ids := _session.get_newly_equipped_instance_ids()
	for instance_id in instance_ids:
		if not staged_source.remove_part(instance_id):
			return false
		_pending_part_removed_events.append({
			"entity_id": staged_source.entity_id,
			"template_id": _get_source_part_template_id(source, instance_id),
		})
	return true


func _get_source_part_template_id(source: EntityInstance, instance_id: String) -> String:
	if source == null:
		return ""
	var part := source.get_inventory_part(instance_id)
	if part == null:
		return ""
	return part.template_id


func _get_options_for_slot(slot_id: String) -> Array[Dictionary]:
	if _option_provider == null:
		return []
	return _option_provider.get_options_for_slot(slot_id)


func _find_initial_index(options: Array[Dictionary], template_id: String, instance_id: String = "") -> int:
	if template_id.is_empty() and instance_id.is_empty():
		return -1
	for index in range(options.size()):
		var option: Dictionary = options[index]
		if not instance_id.is_empty() and _get_option_instance_id(option) == instance_id:
			return index
		if instance_id.is_empty() and _get_option_template_id(option) == template_id:
			return index
	return -1


func _resolve_preview_index(slot_id: String, options: Array[Dictionary], current_template_id: String) -> int:
	if options.is_empty():
		return -1
	var state: Dictionary = _get_slot_state(slot_id)
	var existing_preview_option := _preview_option_from_state(state)
	var existing_preview_template_id := _get_option_template_id(existing_preview_option)
	var existing_preview_instance_id := _get_option_instance_id(existing_preview_option)
	var existing_index := _find_initial_index(options, existing_preview_template_id, existing_preview_instance_id)
	if existing_index >= 0:
		return existing_index
	var current_instance_id := _session.get_equipped_instance_id(slot_id)
	var current_index := _find_initial_index(options, current_template_id, current_instance_id)
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


func _build_price_text(slot_id: String, option: Dictionary) -> String:
	if _session == null or option.is_empty():
		return "Price: 0"
	if _is_free_inventory_option(option):
		return "Owned: no currency cost"
	var currency_id := _session.get_budget_currency_id()
	var price := _session.get_template_price(option)
	if currency_id.is_empty():
		return "Price: %.0f" % price
	var remaining_after := _get_remaining_budget_after_preview(slot_id, option)
	return "Price: %.0f %s | Remaining after apply: %.0f" % [price, currency_id, remaining_after]


func _build_template_stat_lines(template: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var stats_value: Variant = template.get("stats", template.get("stat_modifiers", {}))
	if not stats_value is Dictionary:
		result.append("No stat changes.")
		return result
	var stats: Dictionary = stats_value
	var stat_keys: Array = stats.keys()
	stat_keys.sort()
	for stat_key in stat_keys:
		var stat_id := str(stat_key)
		var amount := float(stats.get(stat_id, 0.0))
		result.append("%s %s" % [BACKEND_HELPERS.humanize_id(stat_id), "%+.0f" % amount if absf(amount - roundf(amount)) < 0.001 else "%+.2f" % amount])
	if result.is_empty():
		result.append("No stat changes.")
	return result


func _build_option_custom_summary(option: Dictionary) -> String:
	if option.is_empty():
		return ""
	var custom_values_data: Variant = option.get("_custom_values", {})
	if not custom_values_data is Dictionary:
		return ""
	var custom_values: Dictionary = custom_values_data
	if custom_values.is_empty():
		return ""
	var parts: Array[String] = []
	var keys: Array = custom_values.keys()
	keys.sort()
	for key_value in keys:
		var key := str(key_value)
		var value_text := str(custom_values.get(key_value, ""))
		if value_text.is_empty():
			continue
		parts.append("%s: %s" % [BACKEND_HELPERS.humanize_id(key), value_text])
	if parts.is_empty():
		return ""
	return "Custom values: %s" % ", ".join(parts)


func _get_option_template_id(option: Dictionary) -> String:
	return str(option.get("id", ""))


func _get_option_instance_id(option: Dictionary) -> String:
	return str(option.get("_part_instance_id", ""))


func _is_inventory_option(option: Dictionary) -> bool:
	return not _get_option_instance_id(option).is_empty()


func _is_free_inventory_option(option: Dictionary) -> bool:
	return _is_inventory_option(option) and _is_source_target_entity()


func _option_matches_current(slot_id: String, option: Dictionary) -> bool:
	if _session == null or option.is_empty():
		return false
	if _is_inventory_option(option):
		var instance_id := _get_option_instance_id(option)
		return not instance_id.is_empty() and instance_id == _session.get_equipped_instance_id(slot_id)
	var template_id := _get_option_template_id(option)
	return not template_id.is_empty() and template_id == _session.get_equipped_template_id(slot_id)


func _can_apply_option(slot_id: String, option: Dictionary) -> bool:
	if _session == null or option.is_empty():
		return false
	if _is_inventory_option(option):
		var source_part := _get_source_inventory_part(_get_option_instance_id(option))
		if source_part == null:
			return false
		if _is_free_inventory_option(option):
			return _session.can_apply_part_instance(slot_id, source_part)
		return _session.can_afford_part_instance(slot_id, source_part)
	var template_id := _get_option_template_id(option)
	return not template_id.is_empty() and _session.can_afford_template(slot_id, template_id)


func _apply_option(slot_id: String, option: Dictionary) -> bool:
	if _session == null or option.is_empty():
		return false
	if _is_inventory_option(option):
		var source_part := _get_source_inventory_part(_get_option_instance_id(option))
		if source_part == null:
			return false
		return _session.apply_part_instance(slot_id, source_part, not _is_free_inventory_option(option))
	var template_id := _get_option_template_id(option)
	if template_id.is_empty():
		return false
	return _session.apply_template(slot_id, template_id)


func _get_remaining_budget_after_preview(slot_id: String, option: Dictionary) -> float:
	if _session == null or option.is_empty():
		return 0.0
	if _is_free_inventory_option(option):
		return _session.starting_budget - _get_confirm_total_cost()
	if _is_inventory_option(option):
		var source_part := _get_source_inventory_part(_get_option_instance_id(option))
		if source_part == null:
			return _session.get_remaining_budget()
		return _session.get_remaining_budget_after_part_preview(slot_id, source_part)
	return _session.get_remaining_budget_after_preview(slot_id, _get_option_template_id(option))


func _get_confirm_total_cost() -> float:
	if _session == null:
		return 0.0
	if _is_source_target_entity() and not _config.option_source_entity_lookup_id.is_empty():
		return 0.0
	return _session.get_total_cost()


func _get_source_inventory_part(instance_id: String) -> PartInstance:
	if instance_id.is_empty():
		return null
	var source := _resolve_source_entity()
	if source == null:
		return null
	return source.get_inventory_part(instance_id)


func _is_source_target_entity() -> bool:
	if _config.option_source_entity_lookup_id.is_empty():
		return false
	var source := _resolve_source_entity()
	var target := _resolve_target_entity()
	return source != null and target != null and source.entity_id == target.entity_id


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


func _preview_option_from_state(state: Dictionary) -> Dictionary:
	var options: Array[Dictionary] = _state_options(state)
	if options.is_empty():
		return {}
	var preview_index := int(state.get("preview_index", -1))
	if preview_index < 0 or preview_index >= options.size():
		return {}
	return options[preview_index]


func _preview_template_id_from_state(state: Dictionary) -> String:
	return _get_option_template_id(_preview_option_from_state(state))


func _get_preview_template_id(slot_id: String) -> String:
	return _get_option_template_id(_get_preview_option(slot_id))


func _get_preview_option(slot_id: String) -> Dictionary:
	var state: Dictionary = _get_slot_state(slot_id)
	return _preview_option_from_state(state)


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
	ASSEMBLY_COMMIT_SERVICE.commit_entity(_session.original_entity, entity, _config.target_entity_lookup_id)


func _commit_entity_to_game_state(entity: EntityInstance, lookup_id: String = "") -> void:
	if entity == null:
		return
	GameState.commit_entity_instance(entity, lookup_id)


func _stage_entity(staged_entities: Dictionary, entity: EntityInstance, lookup_id: String) -> EntityInstance:
	if entity == null:
		return null
	var key := entity.entity_id
	if staged_entities.has(key):
		var staged_entry_value: Variant = staged_entities.get(key, {})
		if staged_entry_value is Dictionary:
			var staged_entry: Dictionary = staged_entry_value
			var staged_entity: EntityInstance = staged_entry.get("entity", null) as EntityInstance
			if staged_entity != null:
				return staged_entity
	staged_entities[key] = {
		"entity": entity,
		"lookup_id": lookup_id,
	}
	return entity


func _commit_staged_entities(staged_entities: Dictionary, target_entity_id: String, previous_entity: EntityInstance) -> void:
	var target_entry_value: Variant = staged_entities.get(target_entity_id, {})
	if target_entry_value is Dictionary:
		var target_entry: Dictionary = target_entry_value
		var target_entity: EntityInstance = target_entry.get("entity", null) as EntityInstance
		var target_lookup_id := str(target_entry.get("lookup_id", _config.target_entity_lookup_id))
		AssemblyCommitService.commit_entity(previous_entity, target_entity, target_lookup_id)
	for key_value in staged_entities.keys():
		var key := str(key_value)
		if key == target_entity_id:
			continue
		var entry_value: Variant = staged_entities.get(key_value, {})
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entity: EntityInstance = entry.get("entity", null) as EntityInstance
		var lookup_id := str(entry.get("lookup_id", ""))
		_commit_entity_to_game_state(entity, lookup_id)


func _emit_pending_part_removed_events() -> void:
	if not GameEvents:
		_pending_part_removed_events.clear()
		return
	for event_data in _pending_part_removed_events:
		var event: Dictionary = event_data
		var entity_id := str(event.get("entity_id", ""))
		var template_id := str(event.get("template_id", ""))
		GameEvents.part_removed.emit(entity_id, template_id)
	_pending_part_removed_events.clear()


func _emit_pending_transaction_events() -> void:
	if not GameEvents:
		_pending_transaction_events.clear()
		return
	for event_data in _pending_transaction_events:
		var event: Dictionary = event_data
		var buyer_id := str(event.get("buyer_id", ""))
		var seller_id := str(event.get("seller_id", ""))
		var part_id := str(event.get("part_id", ""))
		var amount := float(event.get("amount", 0.0))
		GameEvents.transaction_completed.emit(buyer_id, seller_id, part_id, amount)
	_pending_transaction_events.clear()


func _apply_confirm_transaction_effects(staged_entities: Dictionary, committed_target: EntityInstance, committed_payer: EntityInstance) -> bool:
	if _session == null:
		return false
	var total_cost := _get_confirm_total_cost()
	var buyer := committed_target if committed_payer == null else committed_payer
	if buyer == null:
		return false
	return _stage_payment_recipient(staged_entities, buyer, total_cost)


func _stage_payment_recipient(staged_entities: Dictionary, buyer: EntityInstance, amount: float) -> bool:
	if amount <= 0.0 or _config.budget_currency_id.is_empty():
		return true
	var recipient := _resolve_payment_recipient_entity()
	if recipient == null:
		return TRANSACTION_SERVICE.spend_currency(buyer, _config.budget_currency_id, amount)
	var committed_recipient := _stage_entity(staged_entities, recipient.duplicate_instance(), _config.payment_recipient_lookup_id)
	if committed_recipient == null:
		return false
	if not TRANSACTION_SERVICE.transfer_currency(buyer, committed_recipient, _config.budget_currency_id, amount, "", false):
		return false
	_pending_transaction_events.append({
		"buyer_id": buyer.entity_id,
		"seller_id": committed_recipient.entity_id,
		"part_id": "",
		"amount": amount,
	})
	return true


func _can_confirm() -> bool:
	if _session == null:
		return false
	if not _has_sufficient_source_inventory():
		return false
	if _config.allow_confirm_without_changes:
		return true
	if not _session.has_pending_changes():
		return false
	return true


func _has_sufficient_source_inventory() -> bool:
	if _option_provider == null or _config.option_source_entity_lookup_id.is_empty() or _session == null:
		return true
	var source := _resolve_source_entity()
	if source == null:
		return false
	var target := _resolve_target_entity()
	if target != null and source.entity_id == target.entity_id:
		return true
	var instance_ids := _session.get_newly_equipped_instance_ids()
	for instance_id in instance_ids:
		if source.get_inventory_part(instance_id) != null:
			continue
		return false
	return true
