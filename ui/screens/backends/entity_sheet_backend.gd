extends "res://ui/screens/backends/backend_base.gd"

class_name OmniEntitySheetBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const ASSEMBLY_COMMIT_SERVICE := preload("res://systems/assembly_commit_service.gd")
const INVENTORY_FLAG_FAVORITE := "favorite"
const INVENTORY_FLAG_LOCKED := "inventory_locked"

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("EntitySheetBackend", {
		"required": [],
		"optional": [
			"target_entity_id",
			"screen_title",
			"screen_description",
			"stat_title",
			"cancel_label",
			"show_currencies",
			"show_equipped",
			"show_inventory",
			"show_status_effects",
			"show_reputation",
			"inventory_limit",
			"currency_empty_label",
			"equipped_empty_label",
			"inventory_empty_label",
			"status_effect_empty_label",
			"reputation_empty_label",
		],
		"field_types": {
			"target_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"stat_title": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"show_currencies": TYPE_BOOL,
			"show_equipped": TYPE_BOOL,
			"show_inventory": TYPE_BOOL,
			"show_status_effects": TYPE_BOOL,
			"show_reputation": TYPE_BOOL,
			"inventory_limit": TYPE_INT,
			"currency_empty_label": TYPE_STRING,
			"equipped_empty_label": TYPE_STRING,
			"inventory_empty_label": TYPE_STRING,
			"status_effect_empty_label": TYPE_STRING,
			"reputation_empty_label": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_equipment_management_params() -> Dictionary:
	return {
		"target_entity_id": "player",
		"budget_entity_id": "player",
		"budget_currency_id": _resolve_player_budget_currency_id(),
		"option_source_entity_id": "player",
		"screen_title": "Manage Equipment",
		"screen_description": "Equip carried parts and preview stat changes before committing.",
		"cancel_label": "Back",
		"confirm_label": "Apply",
		"pop_on_confirm": true,
	}


func can_use_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	var template: Dictionary = _read_dictionary(row.get("template", {}))
	if _read_use_actions(template).is_empty():
		return false
	if bool(template.get("consume_on_use", false)):
		return not _read_first_unlocked_instance_id(row).is_empty()
	return true


func can_equip_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	if _read_first_instance_id(row).is_empty():
		return false
	return bool(row.get("can_equip", false)) and not str(row.get("recommended_slot_id", "")).is_empty()


func can_discard_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	return not _read_first_unlocked_instance_id(row).is_empty()


func is_selected_inventory_flag_set(row: Dictionary, flag_id: String) -> bool:
	var instance_id := _read_first_instance_id(row)
	if instance_id.is_empty():
		return false
	var player := GameState.player as EntityInstance
	if player == null:
		return false
	var part := player.get_inventory_part(instance_id)
	if part == null:
		return false
	return bool(part.flags.get(flag_id, false))


func equip_inventory_row(row: Dictionary) -> Dictionary:
	if row.is_empty() or not can_equip_inventory_row(row):
		return {"ok": false, "message": ""}
	var player := GameState.player as EntityInstance
	if player == null:
		return {"ok": false, "message": ""}
	var instance_id := _read_first_instance_id(row)
	var slot_id := str(row.get("recommended_slot_id", ""))
	if instance_id.is_empty() or slot_id.is_empty():
		return {"ok": false, "message": ""}
	var previous_entity := player
	var committed_entity := player.duplicate_instance()
	if not committed_entity.equip(instance_id, slot_id):
		return {"ok": false, "message": ""}
	ASSEMBLY_COMMIT_SERVICE.commit_entity(previous_entity, committed_entity, "player")
	var display_name := str(row.get("display_name", "item"))
	var slot_label := str(row.get("recommended_slot_label", slot_id))
	var message := "Equipped %s to %s." % [display_name, slot_label]
	GameEvents.ui_notification_requested.emit(message, "info")
	return {"ok": true, "message": message}


func use_inventory_row(row: Dictionary) -> Dictionary:
	if row.is_empty() or not can_use_inventory_row(row):
		return {"ok": false, "message": ""}
	var display_name := str(row.get("display_name", "item"))
	var template: Dictionary = _read_dictionary(row.get("template", {}))
	var consumes_item := bool(template.get("consume_on_use", false))
	var instance_id := _read_first_unlocked_instance_id(row) if consumes_item else _read_first_instance_id(row)
	var actions := _read_use_actions(template)
	for action in actions:
		var action_payload := action.duplicate(true)
		if not action_payload.has("entity_id"):
			action_payload["entity_id"] = "player"
		if not action_payload.has("instance_id") and not instance_id.is_empty():
			action_payload["instance_id"] = instance_id
		if not action_payload.has("template_id"):
			action_payload["template_id"] = str(row.get("template_id", ""))
		if not action_payload.has("part_id"):
			action_payload["part_id"] = str(row.get("template_id", ""))
		ActionDispatcher.dispatch(action_payload)
	if consumes_item:
		ActionDispatcher.dispatch({
			"type": "consume",
			"entity_id": "player",
			"instance_id": instance_id,
			"template_id": str(row.get("template_id", "")),
		})
	var message := "Used %s." % display_name
	GameEvents.ui_notification_requested.emit(message, "info")
	return {"ok": true, "message": message}


func discard_inventory_row(row: Dictionary) -> Dictionary:
	if row.is_empty() or not can_discard_inventory_row(row):
		return {"ok": false, "message": ""}
	var display_name := str(row.get("display_name", "item"))
	var instance_id := _read_first_unlocked_instance_id(row)
	ActionDispatcher.dispatch({
		"type": "consume",
		"entity_id": "player",
		"instance_id": instance_id,
		"template_id": str(row.get("template_id", "")),
	})
	var message := "Discarded %s." % display_name
	GameEvents.ui_notification_requested.emit(message, "info")
	return {"ok": true, "message": message}


func toggle_inventory_flag(row: Dictionary, flag_id: String, label: String) -> Dictionary:
	if row.is_empty() or bool(row.get("is_equipped", false)):
		return {"ok": false, "message": ""}
	var instance_id := _read_first_instance_id(row)
	if instance_id.is_empty():
		return {"ok": false, "message": ""}
	var player := GameState.player as EntityInstance
	if player == null:
		return {"ok": false, "message": ""}
	var part := player.get_inventory_part(instance_id)
	if part == null:
		return {"ok": false, "message": ""}
	var next_value := not bool(part.flags.get(flag_id, false))
	if next_value:
		part.flags[flag_id] = true
	else:
		part.flags.erase(flag_id)
	var display_name := str(row.get("display_name", "item"))
	var action_label := label.capitalize() if next_value else "un%s" % label
	var message := "%s %s." % [action_label, display_name]
	GameEvents.ui_notification_requested.emit(message, "info")
	return {"ok": true, "message": message, "value": next_value}


func build_view_model() -> Dictionary:
	var target_entity := _resolve_target_entity()
	var fallback_title := "Entity Sheet"
	if target_entity != null:
		fallback_title = "%s Sheet" % BACKEND_HELPERS.get_entity_display_name(target_entity, target_entity.entity_id)
	var title := _get_string_param(_params, "screen_title", fallback_title)
	var description := _get_string_param(_params, "screen_description", "Review the selected entity's stats, equipment, inventory, and standing.")
	var stat_title := _get_string_param(_params, "stat_title", "Stats")
	var show_currencies := _get_bool_param(_params, "show_currencies", true)
	var show_equipped := _get_bool_param(_params, "show_equipped", true)
	var show_inventory := _get_bool_param(_params, "show_inventory", true)
	var show_status_effects := _get_bool_param(_params, "show_status_effects", true)
	var show_reputation := _get_bool_param(_params, "show_reputation", true)

	if target_entity == null:
		return {
			"title": title,
			"description": description,
			"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(null, "Unknown Entity", "The requested entity could not be resolved."),
			"stat_sheet": BACKEND_HELPERS.build_stat_sheet_view_model(null, stat_title),
			"currency_rows": [],
			"equipped_rows": [],
			"inventory_rows": [],
			"status_effect_rows": [],
			"reputation_rows": [],
			"overview_rows": [],
			"progress_rows": _build_progress_rows(),
			"activity_rows": _build_activity_rows(),
			"show_currencies": show_currencies,
			"show_equipped": show_equipped,
			"show_inventory": show_inventory,
			"show_status_effects": show_status_effects,
			"show_reputation": show_reputation,
			"status_text": "The entity sheet target could not be resolved.",
			"summary_text": "",
			"ai_lore": "",
			"ai_lore_template_id": "",
			"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
			"currency_empty_label": _get_empty_label("currency_empty_label", "No currencies are recorded."),
			"equipped_empty_label": _get_empty_label("equipped_empty_label", "No parts are equipped."),
			"inventory_empty_label": _get_empty_label("inventory_empty_label", "Inventory is empty."),
			"status_effect_empty_label": _get_empty_label("status_effect_empty_label", "No active status effects."),
			"reputation_empty_label": _get_empty_label("reputation_empty_label", "No faction standing is recorded."),
			"inventory_overflow_count": 0,
			"inventory_total_instances": 0,
			"inventory_total_stacks": 0,
			"inventory_shown_stacks": 0,
			"target_entity_id": "",
			"is_player_sheet": false,
		}

	var currency_rows := _build_currency_rows(target_entity)
	var equipped_rows := _build_equipped_rows(target_entity)
	var inventory_result := _build_inventory_result(target_entity)
	var inventory_rows := _read_dictionary_rows(inventory_result.get("rows", []))
	var status_effect_rows := _build_status_effect_rows(target_entity)
	var reputation_rows := _build_reputation_rows(target_entity)
	var overview_rows := _build_overview_rows(currency_rows, equipped_rows, inventory_result, status_effect_rows)
	var entity_template := BACKEND_HELPERS.get_entity_template(target_entity)
	var ai_lore_template_id := str(entity_template.get("entity_id", ""))
	var ai_lore := ScriptHookService.request_entity_lore(entity_template, {
		"entity_id": target_entity.entity_id,
	})
	return {
		"title": title,
		"description": description,
		"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(target_entity, target_entity.entity_id),
		"stat_sheet": BACKEND_HELPERS.build_stat_sheet_view_model(target_entity, stat_title),
		"currency_rows": currency_rows,
		"equipped_rows": equipped_rows,
		"inventory_rows": inventory_rows,
		"status_effect_rows": status_effect_rows,
		"reputation_rows": reputation_rows,
		"overview_rows": overview_rows,
		"progress_rows": _build_progress_rows(),
		"activity_rows": _build_activity_rows(),
		"show_currencies": show_currencies,
		"show_equipped": show_equipped,
		"show_inventory": show_inventory,
		"show_status_effects": show_status_effects,
		"show_reputation": show_reputation,
		"ai_lore": ai_lore,
		"ai_lore_template_id": ai_lore_template_id,
		"status_text": _build_status_text(target_entity, equipped_rows, inventory_result, status_effect_rows),
		"summary_text": _build_summary_text(target_entity, equipped_rows, inventory_result, status_effect_rows),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"currency_empty_label": _get_empty_label("currency_empty_label", "No currencies are recorded."),
		"equipped_empty_label": _get_empty_label("equipped_empty_label", "No parts are equipped."),
		"inventory_empty_label": _get_empty_label("inventory_empty_label", "Inventory is empty."),
		"status_effect_empty_label": _get_empty_label("status_effect_empty_label", "No active status effects."),
		"reputation_empty_label": _get_empty_label("reputation_empty_label", "No faction standing is recorded."),
		"inventory_overflow_count": int(inventory_result.get("overflow_count", 0)),
		"inventory_total_instances": int(inventory_result.get("total_instances", 0)),
		"inventory_total_stacks": int(inventory_result.get("total_stacks", 0)),
		"inventory_shown_stacks": int(inventory_result.get("shown_stacks", 0)),
		"target_entity_id": target_entity.entity_id,
		"is_player_sheet": _is_player_entity(target_entity),
	}


func _resolve_target_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_get_string_param(_params, "target_entity_id", "player"))


func _is_player_entity(entity: EntityInstance) -> bool:
	var player := GameState.player as EntityInstance
	return player != null and entity != null and entity.entity_id == player.entity_id


func _build_equipped_rows(entity: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entity == null:
		return rows

	var socket_labels := _build_socket_label_map(entity)
	var ordered_slot_ids := _build_ordered_slot_ids(entity)
	for slot_id in ordered_slot_ids:
		var part := entity.get_equipped(slot_id)
		if part == null:
			continue
		var template := part.get_template()
		rows.append({
			"slot_id": slot_id,
			"slot_label": str(socket_labels.get(slot_id, BACKEND_HELPERS.humanize_id(slot_id))),
			"template_id": part.template_id,
			"instance_id": part.instance_id,
			"instance_ids": [part.instance_id],
			"count": 1,
			"is_equipped": true,
			"template": template.duplicate(true),
			"tags": _read_string_array(template.get("tags", [])),
			"display_name": str(template.get("display_name", part.template_id)),
			"description": str(template.get("description", "")),
			"stat_summary": _build_part_instance_summary(template, part),
			"custom_summary": _build_part_custom_summary(template, part.custom_values),
		})
	return rows


func _build_currency_rows(entity: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entity == null:
		return rows
	var currency_ids: Array = entity.currencies.keys()
	currency_ids.sort()
	var currency_symbol := BACKEND_HELPERS.get_currency_symbol()
	for currency_id_value in currency_ids:
		var currency_id := str(currency_id_value)
		if currency_id.is_empty():
			continue
		rows.append({
			"currency_id": currency_id,
			"display_name": BACKEND_HELPERS.humanize_id(currency_id),
			"stat_summary": _format_currency_amount(currency_symbol, entity.get_currency(currency_id)),
		})
	return rows


func _build_overview_rows(currency_rows: Array[Dictionary], equipped_rows: Array[Dictionary], inventory_result: Dictionary, status_effect_rows: Array[Dictionary]) -> Array[Dictionary]:
	return [
		{"display_name": "Currency Balances", "stat_summary": str(currency_rows.size())},
		{"display_name": "Equipped Parts", "stat_summary": str(equipped_rows.size())},
		{"display_name": "Loose Inventory Items", "stat_summary": str(int(inventory_result.get("total_instances", 0)))},
		{"display_name": "Loose Inventory Stacks", "stat_summary": str(int(inventory_result.get("total_stacks", 0)))},
		{"display_name": "Active Effects", "stat_summary": str(status_effect_rows.size())},
		{"display_name": "Active Quests", "stat_summary": str(GameState.active_quests.size())},
		{"display_name": "Completed Quests", "stat_summary": str(GameState.completed_quests.size())},
		{"display_name": "Unlocked Achievements", "stat_summary": str(GameState.unlocked_achievements.size())},
		{"display_name": "Discovered Recipes", "stat_summary": str(GameState.discovered_recipes.size())},
	]


func _build_progress_rows() -> Array[Dictionary]:
	var flag_keys: Array = GameState.flags.keys()
	flag_keys.sort()
	return [
		{"display_name": "Unlocked Achievements", "stat_summary": _join_string_array(GameState.unlocked_achievements, "None")},
		{"display_name": "Discovered Recipes", "stat_summary": _join_string_array(GameState.discovered_recipes, "None")},
		{"display_name": "Completed Quests", "stat_summary": _join_string_array(GameState.completed_quests, "None")},
		{"display_name": "Completed Tasks", "stat_summary": _join_string_array(GameState.completed_task_templates, "None")},
		{"display_name": "Flags", "stat_summary": _join_variant_array(flag_keys, "None")},
	]


func _build_activity_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if GameState.event_history.is_empty():
		return rows
	var start_index := maxi(GameState.event_history.size() - 25, 0)
	for index in range(GameState.event_history.size() - 1, start_index - 1, -1):
		var event_value: Variant = GameState.event_history[index]
		if not event_value is Dictionary:
			continue
		var event_entry: Dictionary = event_value
		var event_type := str(event_entry.get("event_type", "event"))
		var day := int(event_entry.get("day", 0))
		var tick := int(event_entry.get("tick", 0))
		rows.append({
			"display_name": "Day %s, Tick %s - %s" % [str(day), str(tick), event_type],
			"stat_summary": _summarize_payload(_read_dictionary(event_entry.get("payload", {}))),
		})
	return rows


func _build_inventory_result(entity: EntityInstance) -> Dictionary:
	var rows: Array[Dictionary] = []
	if entity == null:
		return {
			"rows": rows,
			"total_instances": 0,
			"total_stacks": 0,
			"shown_stacks": 0,
			"overflow_count": 0,
		}

	var grouped: Dictionary = {}
	var total_instances := 0
	for part_value in entity.inventory:
		var part := part_value as PartInstance
		if part == null:
			continue
		total_instances += 1
		var entry_value: Variant = grouped.get(part.template_id, {})
		var entry: Dictionary = {}
		if entry_value is Dictionary:
			entry = entry_value
		var count := int(entry.get("count", 0)) + 1
		var template := part.get_template()
		var instance_ids := _read_string_array(entry.get("instance_ids", []))
		if not part.instance_id.is_empty():
			instance_ids.append(part.instance_id)
		var locked_count := int(entry.get("locked_count", 0))
		if bool(part.flags.get("inventory_locked", false)):
			locked_count += 1
		var favorite_count := int(entry.get("favorite_count", 0))
		if bool(part.flags.get("favorite", false)):
			favorite_count += 1
		entry["template_id"] = part.template_id
		entry["instance_ids"] = instance_ids
		entry["template"] = template.duplicate(true)
		entry["tags"] = _read_string_array(template.get("tags", []))
		entry["display_name"] = str(template.get("display_name", part.template_id))
		entry["description"] = str(template.get("description", ""))
		entry["count"] = count
		entry["locked_count"] = locked_count
		entry["favorite_count"] = favorite_count
		entry["stat_summary"] = _build_part_stat_summary(template, {})
		entry["custom_summary"] = _build_inventory_custom_summary(template, entry.get("instance_ids", []), entity)
		entry["is_equipped"] = false
		var equip_data := _build_inventory_equip_data(entity, part.template_id)
		for key_value in equip_data.keys():
			entry[key_value] = equip_data.get(key_value)
		grouped[part.template_id] = entry

	var grouped_values: Array = grouped.values()
	for grouped_value in grouped_values:
		if grouped_value is Dictionary:
			var row: Dictionary = grouped_value
			rows.append(row.duplicate(true))

	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)

	var total_stacks := rows.size()
	var shown_rows := rows
	var inventory_limit := _read_inventory_limit()
	if inventory_limit > 0 and rows.size() > inventory_limit:
		shown_rows = []
		for index in range(inventory_limit):
			shown_rows.append(rows[index].duplicate(true))

	return {
		"rows": shown_rows,
		"total_instances": total_instances,
		"total_stacks": total_stacks,
		"shown_stacks": shown_rows.size(),
		"overflow_count": maxi(total_stacks - shown_rows.size(), 0),
	}


func _build_reputation_rows(entity: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entity == null:
		return rows
	var faction_ids: Array = entity.reputation.keys()
	faction_ids.sort()
	for faction_id_value in faction_ids:
		var faction_id := str(faction_id_value)
		if faction_id.is_empty():
			continue
		var faction := DataManager.get_faction(faction_id)
		rows.append({
			"faction_id": faction_id,
			"display_name": str(faction.get("display_name", BACKEND_HELPERS.humanize_id(faction_id))),
			"description": str(faction.get("description", "")),
			"badge": BACKEND_HELPERS.build_faction_badge_view_model(entity, faction_id),
		})
	return rows


func _build_status_effect_rows(entity: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if entity == null:
		return rows
	var effects := GameState.get_status_effects_for_entity(entity.entity_id)
	for effect in effects:
		var status_effect_id := str(effect.get("status_effect_id", ""))
		if status_effect_id.is_empty():
			continue
		var template := DataManager.get_status_effect(status_effect_id)
		var display_name := str(template.get("display_name", BACKEND_HELPERS.humanize_id(status_effect_id)))
		var remaining_ticks := int(effect.get("remaining_ticks", 0))
		var duration := int(effect.get("duration", remaining_ticks))
		var stacks := maxi(int(effect.get("stacks", 1)), 1)
		var stat_summary := _build_status_effect_stat_summary(template, stacks)
		var timing_summary := _build_status_effect_timing_summary(remaining_ticks, duration, stacks)
		var summary_parts: Array[String] = []
		if not timing_summary.is_empty():
			summary_parts.append(timing_summary)
		if not stat_summary.is_empty():
			summary_parts.append(stat_summary)
		rows.append({
			"runtime_id": str(effect.get("runtime_id", "")),
			"status_effect_id": status_effect_id,
			"display_name": display_name,
			"description": str(template.get("description", "")),
			"tags": _read_string_array(template.get("tags", [])),
			"remaining_ticks": remaining_ticks,
			"duration": duration,
			"stacks": stacks,
			"stat_summary": "\n".join(summary_parts),
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _build_socket_label_map(entity: EntityInstance) -> Dictionary:
	var labels: Dictionary = {}
	if entity == null:
		return labels
	for socket_definition in entity.get_available_socket_definitions():
		var socket_id := str(socket_definition.get("id", ""))
		if socket_id.is_empty():
			continue
		labels[socket_id] = str(socket_definition.get("label", BACKEND_HELPERS.humanize_id(socket_id)))
	return labels


func _build_inventory_equip_data(entity: EntityInstance, template_id: String) -> Dictionary:
	var compatible_slot_ids: Array[String] = []
	var compatible_slot_labels: Array[String] = []
	var recommended_slot_id := ""
	var recommended_slot_label := ""
	if entity == null or template_id.is_empty():
		return {
			"can_equip": false,
			"compatible_slot_ids": compatible_slot_ids,
			"compatible_slot_labels": compatible_slot_labels,
			"recommended_slot_id": "",
			"recommended_slot_label": "",
		}

	var socket_labels := _build_socket_label_map(entity)
	var ordered_slot_ids := _build_ordered_slot_ids(entity)
	for slot_id in ordered_slot_ids:
		if not entity.can_equip_template_in_slot(slot_id, template_id):
			continue
		compatible_slot_ids.append(slot_id)
		compatible_slot_labels.append(str(socket_labels.get(slot_id, BACKEND_HELPERS.humanize_id(slot_id))))

	for slot_id in compatible_slot_ids:
		if entity.get_equipped(slot_id) == null:
			recommended_slot_id = slot_id
			break
	if recommended_slot_id.is_empty() and not compatible_slot_ids.is_empty():
		recommended_slot_id = compatible_slot_ids[0]
	if not recommended_slot_id.is_empty():
		recommended_slot_label = str(socket_labels.get(recommended_slot_id, BACKEND_HELPERS.humanize_id(recommended_slot_id)))

	return {
		"can_equip": not compatible_slot_ids.is_empty(),
		"compatible_slot_ids": compatible_slot_ids,
		"compatible_slot_labels": compatible_slot_labels,
		"recommended_slot_id": recommended_slot_id,
		"recommended_slot_label": recommended_slot_label,
	}


func _build_ordered_slot_ids(entity: EntityInstance) -> Array[String]:
	var ordered_slot_ids: Array[String] = []
	var seen: Dictionary = {}
	if entity == null:
		return ordered_slot_ids

	for socket_definition in entity.get_available_socket_definitions():
		var socket_id := str(socket_definition.get("id", ""))
		if socket_id.is_empty() or seen.has(socket_id):
			continue
		seen[socket_id] = true
		ordered_slot_ids.append(socket_id)

	var extra_slot_ids: Array[String] = []
	for slot_value in entity.equipped.keys():
		var slot_id := str(slot_value)
		if slot_id.is_empty() or seen.has(slot_id):
			continue
		extra_slot_ids.append(slot_id)
	extra_slot_ids.sort()
	ordered_slot_ids.append_array(extra_slot_ids)
	return ordered_slot_ids


func _build_part_stat_summary(template: Dictionary, overrides: Dictionary) -> String:
	var stats_value: Variant = template.get("stats", template.get("stat_modifiers", {}))
	var stats: Dictionary = {}
	if stats_value is Dictionary:
		stats = stats_value.duplicate(true)
	for key_value in overrides.keys():
		stats[key_value] = overrides.get(key_value, 0.0)
	if stats.is_empty():
		return "No stat modifiers."
	var stat_keys: Array = stats.keys()
	stat_keys.sort()
	var parts: Array[String] = []
	for stat_key_value in stat_keys:
		var stat_id := str(stat_key_value)
		var amount := _read_float(stats.get(stat_key_value, 0.0))
		var amount_text := "%+.0f" % amount if absf(amount - roundf(amount)) < 0.001 else "%+.2f" % amount
		parts.append("%s %s" % [BACKEND_HELPERS.humanize_id(stat_id), amount_text])
	return ", ".join(parts)


func _build_status_effect_stat_summary(template: Dictionary, stacks: int) -> String:
	var modifiers_value: Variant = template.get("stat_modifiers", {})
	if not modifiers_value is Dictionary:
		return ""
	var modifiers: Dictionary = modifiers_value
	if modifiers.is_empty():
		return ""
	var modifier_keys: Array = modifiers.keys()
	modifier_keys.sort()
	var parts: Array[String] = []
	for modifier_key_value in modifier_keys:
		var stat_id := str(modifier_key_value)
		if stat_id.is_empty():
			continue
		var amount := _read_float(modifiers.get(modifier_key_value, 0.0)) * float(maxi(stacks, 1))
		if absf(amount) < 0.001:
			continue
		var amount_text := "%+.0f" % amount if absf(amount - roundf(amount)) < 0.001 else "%+.2f" % amount
		parts.append("%s %s" % [BACKEND_HELPERS.humanize_id(stat_id), amount_text])
	if parts.is_empty():
		return ""
	return "Modifiers: %s" % ", ".join(parts)


func _build_status_effect_timing_summary(remaining_ticks: int, duration: int, stacks: int) -> String:
	var parts: Array[String] = []
	if remaining_ticks > 0:
		parts.append("%s tick%s remaining" % [str(remaining_ticks), "" if remaining_ticks == 1 else "s"])
	if duration > 0:
		parts.append("%s tick%s total" % [str(duration), "" if duration == 1 else "s"])
	if stacks > 1:
		parts.append("%sx stacks" % str(stacks))
	return ", ".join(parts)


func _build_part_instance_summary(template: Dictionary, part: PartInstance) -> String:
	var lines: Array[String] = []
	lines.append(_build_part_stat_summary(template, part.stat_overrides))
	var custom_summary := _build_part_custom_summary(template, part.custom_values)
	if not custom_summary.is_empty():
		lines.append(custom_summary)
	return "\n".join(lines)


func _build_part_custom_summary(template: Dictionary, custom_values: Dictionary) -> String:
	if custom_values.is_empty():
		return ""
	var labels := _build_custom_field_label_map(template)
	var keys: Array = custom_values.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		var field_id := str(key_value)
		var label := str(labels.get(field_id, BACKEND_HELPERS.humanize_id(field_id)))
		var value_text := str(custom_values.get(key_value, ""))
		if value_text.is_empty():
			continue
		parts.append("%s: %s" % [label, value_text])
	if parts.is_empty():
		return ""
	return "Custom: %s" % ", ".join(parts)


func _build_custom_field_label_map(template: Dictionary) -> Dictionary:
	var labels: Dictionary = {}
	var fields_value: Variant = template.get("custom_fields", [])
	if fields_value is Array:
		var fields: Array = fields_value
		for field_value in fields:
			if not field_value is Dictionary:
				continue
			var field: Dictionary = field_value
			var field_id := str(field.get("id", ""))
			if field_id.is_empty():
				continue
			labels[field_id] = str(field.get("label", BACKEND_HELPERS.humanize_id(field_id)))
	return labels


func _build_summary_text(entity: EntityInstance, equipped_rows: Array[Dictionary], inventory_result: Dictionary, status_effect_rows: Array[Dictionary]) -> String:
	var location_label := BACKEND_HELPERS.humanize_id(entity.location_id)
	if not entity.location_id.is_empty():
		var location := DataManager.get_location(entity.location_id)
		location_label = str(location.get("display_name", location_label))
	return "%s currency balances, %s equipped, %s active effects, %s inventory stacks shown of %s total, location: %s." % [
		str(entity.currencies.size()),
		str(equipped_rows.size()),
		str(status_effect_rows.size()),
		str(int(inventory_result.get("shown_stacks", 0))),
		str(int(inventory_result.get("total_stacks", 0))),
		location_label if not location_label.is_empty() else "Unknown",
	]


func _build_status_text(entity: EntityInstance, equipped_rows: Array[Dictionary], inventory_result: Dictionary, status_effect_rows: Array[Dictionary]) -> String:
	return "%s has %s currency balances, %s equipped parts, %s active effects, %s inventory items, and %s inventory stacks." % [
		BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
		str(entity.currencies.size()),
		str(equipped_rows.size()),
		str(status_effect_rows.size()),
		str(int(inventory_result.get("total_instances", 0))),
		str(int(inventory_result.get("total_stacks", 0))),
	]


func _build_inventory_custom_summary(template: Dictionary, instance_ids_value: Variant, entity: EntityInstance) -> String:
	var instance_ids := _read_string_array(instance_ids_value)
	if instance_ids.is_empty():
		return ""
	for instance_id in instance_ids:
		var part := entity.get_inventory_part(instance_id)
		if part == null:
			continue
		var summary := _build_part_custom_summary(template, part.custom_values)
		if not summary.is_empty():
			return summary
	return ""


func _read_use_actions(template: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var actions_value: Variant = template.get("use_actions", [])
	if actions_value is Array:
		var raw_actions: Array = actions_value
		for action_value in raw_actions:
			if action_value is Dictionary:
				var action: Dictionary = action_value
				actions.append(action.duplicate(true))
	var action_payload_value: Variant = template.get("use_action_payload", {})
	if action_payload_value is Dictionary:
		var action_payload: Dictionary = action_payload_value
		if not action_payload.is_empty():
			actions.append(action_payload.duplicate(true))
	return actions


func _read_first_instance_id(row: Dictionary) -> String:
	var instance_ids := _read_string_array(row.get("instance_ids", []))
	if not instance_ids.is_empty():
		return instance_ids[0]
	return str(row.get("instance_id", ""))


func _read_first_unlocked_instance_id(row: Dictionary) -> String:
	var player := GameState.player as EntityInstance
	if player == null:
		return ""
	var instance_ids := _read_string_array(row.get("instance_ids", []))
	if instance_ids.is_empty():
		var instance_id := str(row.get("instance_id", ""))
		if not instance_id.is_empty():
			instance_ids.append(instance_id)
	for instance_id in instance_ids:
		var part := player.get_inventory_part(instance_id)
		if part == null:
			continue
		if not bool(part.flags.get(INVENTORY_FLAG_LOCKED, false)):
			return instance_id
	return ""


func _resolve_player_budget_currency_id() -> String:
	var configured_value: Variant = DataManager.get_config_value("economy.default_currency_id", DataManager.get_config_value("ui.default_budget_currency_id", ""))
	var configured_id := str(configured_value).strip_edges()
	var player := GameState.player as EntityInstance
	if player != null and not configured_id.is_empty() and player.currencies.has(configured_id):
		return configured_id
	if player == null or player.currencies.is_empty():
		return configured_id
	var currency_keys: Array = player.currencies.keys()
	currency_keys.sort()
	return str(currency_keys[0])


func _read_inventory_limit() -> int:
	return _get_int_param(_params, "inventory_limit", 0, 0)


func _get_empty_label(field_name: String, default_value: String) -> String:
	return _get_string_param(_params, field_name, default_value)


func _read_float(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}


func _read_dictionary_rows(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not value is Array:
		return rows
	var values: Array = value
	for entry_value in values:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		rows.append(entry.duplicate(true))
	return rows


func _read_string_array(value: Variant) -> Array[String]:
	var results: Array[String] = []
	if not value is Array:
		return results
	var values: Array = value
	for item in values:
		var text := str(item)
		if text.is_empty():
			continue
		results.append(text)
	return results


func _join_string_array(values: Array, empty_label: String) -> String:
	if values.is_empty():
		return empty_label
	var labels: Array[String] = []
	for value in values:
		labels.append(str(value))
	return ", ".join(labels)


func _join_variant_array(values: Array, empty_label: String) -> String:
	if values.is_empty():
		return empty_label
	var labels: Array[String] = []
	for value in values:
		labels.append(str(value))
	return ", ".join(labels)


func _summarize_payload(payload: Dictionary) -> String:
	var parts: Array[String] = []
	var keys: Array = payload.keys()
	keys.sort()
	for key_value in keys:
		var key := str(key_value)
		var value: Variant = payload.get(key, null)
		if value is Dictionary or value is Array:
			continue
		parts.append("%s: %s" % [BACKEND_HELPERS.humanize_id(key), str(value)])
	return ", ".join(parts)


func _format_currency_amount(symbol: String, amount: float) -> String:
	var amount_text := "%d" % int(roundf(amount)) if absf(amount - roundf(amount)) < 0.001 else "%.2f" % amount
	if symbol.is_empty():
		return amount_text
	return "%s%s" % [symbol, amount_text]
