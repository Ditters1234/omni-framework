extends "res://ui/screens/backends/backend_base.gd"

class_name OmniEntitySheetBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

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
			"show_reputation",
			"inventory_limit",
			"currency_empty_label",
			"equipped_empty_label",
			"inventory_empty_label",
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
			"show_reputation": TYPE_BOOL,
			"inventory_limit": TYPE_INT,
			"currency_empty_label": TYPE_STRING,
			"equipped_empty_label": TYPE_STRING,
			"inventory_empty_label": TYPE_STRING,
			"reputation_empty_label": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


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
			"reputation_rows": [],
			"show_currencies": show_currencies,
			"show_equipped": show_equipped,
			"show_inventory": show_inventory,
			"show_reputation": show_reputation,
			"status_text": "The entity sheet target could not be resolved.",
			"summary_text": "",
			"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
			"currency_empty_label": _get_empty_label("currency_empty_label", "No currencies are recorded."),
			"equipped_empty_label": _get_empty_label("equipped_empty_label", "No parts are equipped."),
			"inventory_empty_label": _get_empty_label("inventory_empty_label", "Inventory is empty."),
			"reputation_empty_label": _get_empty_label("reputation_empty_label", "No faction standing is recorded."),
			"inventory_overflow_count": 0,
			"inventory_total_instances": 0,
			"inventory_total_stacks": 0,
			"inventory_shown_stacks": 0,
		}

	var currency_rows := _build_currency_rows(target_entity)
	var equipped_rows := _build_equipped_rows(target_entity)
	var inventory_result := _build_inventory_result(target_entity)
	var inventory_rows := _read_dictionary_rows(inventory_result.get("rows", []))
	var reputation_rows := _build_reputation_rows(target_entity)
	return {
		"title": title,
		"description": description,
		"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(target_entity, target_entity.entity_id),
		"stat_sheet": BACKEND_HELPERS.build_stat_sheet_view_model(target_entity, stat_title),
		"currency_rows": currency_rows,
		"equipped_rows": equipped_rows,
		"inventory_rows": inventory_rows,
		"reputation_rows": reputation_rows,
		"show_currencies": show_currencies,
		"show_equipped": show_equipped,
		"show_inventory": show_inventory,
		"show_reputation": show_reputation,
		"status_text": _build_status_text(target_entity, equipped_rows, inventory_result),
		"summary_text": _build_summary_text(target_entity, equipped_rows, inventory_result),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"currency_empty_label": _get_empty_label("currency_empty_label", "No currencies are recorded."),
		"equipped_empty_label": _get_empty_label("equipped_empty_label", "No parts are equipped."),
		"inventory_empty_label": _get_empty_label("inventory_empty_label", "Inventory is empty."),
		"reputation_empty_label": _get_empty_label("reputation_empty_label", "No faction standing is recorded."),
		"inventory_overflow_count": int(inventory_result.get("overflow_count", 0)),
		"inventory_total_instances": int(inventory_result.get("total_instances", 0)),
		"inventory_total_stacks": int(inventory_result.get("total_stacks", 0)),
		"inventory_shown_stacks": int(inventory_result.get("shown_stacks", 0)),
	}


func _resolve_target_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_get_string_param(_params, "target_entity_id", "player"))


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
			"display_name": str(template.get("display_name", part.template_id)),
			"description": str(template.get("description", "")),
			"stat_summary": _build_part_instance_summary(template, part),
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
		entry["template_id"] = part.template_id
		entry["display_name"] = str(template.get("display_name", part.template_id))
		entry["description"] = str(template.get("description", ""))
		entry["count"] = count
		entry["stat_summary"] = _build_part_stat_summary(template, {})
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


func _build_summary_text(entity: EntityInstance, equipped_rows: Array[Dictionary], inventory_result: Dictionary) -> String:
	var location_label := BACKEND_HELPERS.humanize_id(entity.location_id)
	if not entity.location_id.is_empty():
		var location := DataManager.get_location(entity.location_id)
		location_label = str(location.get("display_name", location_label))
	return "%s currency balances, %s equipped, %s inventory stacks shown of %s total, location: %s." % [
		str(entity.currencies.size()),
		str(equipped_rows.size()),
		str(int(inventory_result.get("shown_stacks", 0))),
		str(int(inventory_result.get("total_stacks", 0))),
		location_label if not location_label.is_empty() else "Unknown",
	]


func _build_status_text(entity: EntityInstance, equipped_rows: Array[Dictionary], inventory_result: Dictionary) -> String:
	return "%s has %s currency balances, %s equipped parts, %s inventory items, and %s inventory stacks." % [
		BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
		str(entity.currencies.size()),
		str(equipped_rows.size()),
		str(int(inventory_result.get("total_instances", 0))),
		str(int(inventory_result.get("total_stacks", 0))),
	]


func _read_inventory_limit() -> int:
	return _get_int_param(_params, "inventory_limit", 12, 0)


func _get_empty_label(field_name: String, default_value: String) -> String:
	return _get_string_param(_params, field_name, default_value)


func _read_float(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0


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


func _format_currency_amount(symbol: String, amount: float) -> String:
	var amount_text := "%d" % int(roundf(amount)) if absf(amount - roundf(amount)) < 0.001 else "%.2f" % amount
	if symbol.is_empty():
		return amount_text
	return "%s%s" % [symbol, amount_text]
