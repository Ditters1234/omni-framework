extends "res://ui/screens/backends/backend_base.gd"

class_name OmniLootBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}
var _selected_instance_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("LootBackend", {
		"required": ["source_entity_id"],
		"optional": [
			"destination_entity_id",
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"take_all_label",
			"cancel_label",
			"empty_label",
			"include_currencies",
			"pop_when_empty",
			"hide_when_empty",
		],
		"field_types": {
			"source_entity_id": TYPE_STRING,
			"destination_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"take_all_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"include_currencies": TYPE_BOOL,
			"pop_when_empty": TYPE_BOOL,
			"hide_when_empty": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_instance_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var source := _resolve_source_entity()
	var destination := _resolve_destination_entity()
	var title := str(_params.get("screen_title", "Loot"))
	var description := str(_params.get("screen_description", "Review and transfer available items."))
	var summary := str(_params.get("screen_summary", "Select one item to take it, or take everything available."))
	var empty_label := str(_params.get("empty_label", "Nothing is available to take."))
	if source == null or destination == null:
		return _empty_view_model(title, description, summary, empty_label, "The loot source or destination could not be resolved.")
	if source.entity_id == destination.entity_id:
		return _empty_view_model(title, description, summary, empty_label, "Loot source and destination must be different entities.")

	var rows := _build_rows(source)
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	var currency_rows := _build_currency_rows(source)
	var can_take_all := not rows.is_empty() or (bool(_params.get("include_currencies", true)) and not currency_rows.is_empty())
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": rows,
		"currency_rows": currency_rows,
		"selected_detail": _read_dictionary(selected_row.get("detail_view_model", {})),
		"detail_kind": str(selected_row.get("detail_kind", "")),
		"status_text": _build_status_text(rows, currency_rows, selected_row, source, destination, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Take Selected")),
		"take_all_label": str(_params.get("take_all_label", "Take All")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty(),
		"take_all_enabled": can_take_all,
		"source_name": BACKEND_HELPERS.get_entity_display_name(source, source.entity_id),
		"destination_name": BACKEND_HELPERS.get_entity_display_name(destination, destination.entity_id),
	}


func select_row(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_status_text = ""


func take_selected() -> Dictionary:
	var source := _resolve_source_entity()
	var destination := _resolve_destination_entity()
	if source == null or destination == null:
		_status_text = "The loot source or destination could not be resolved."
		return {}
	if source.entity_id == destination.entity_id:
		_status_text = "Loot source and destination must be different entities."
		return {}
	var source_clone := source.duplicate_instance()
	var destination_clone := destination.duplicate_instance()
	var part := source_clone.get_inventory_part(_selected_instance_id)
	if part == null or part.is_equipped:
		_status_text = "Select an available item before taking loot."
		return {}
	var moved_part := _duplicate_part(part)
	if moved_part == null or not source_clone.remove_part(part.instance_id):
		_status_text = "The selected item could not be moved."
		return {}
	destination_clone.add_part(moved_part)
	_commit_transfer(source_clone, destination_clone)
	_emit_part_transfer(source_clone.entity_id, destination_clone.entity_id, moved_part.template_id)
	_status_text = "Took %s." % _get_part_display_name(moved_part)
	_selected_instance_id = ""
	return _build_completion_action(source_clone)


func take_all() -> Dictionary:
	var source := _resolve_source_entity()
	var destination := _resolve_destination_entity()
	if source == null or destination == null:
		_status_text = "The loot source or destination could not be resolved."
		return {}
	if source.entity_id == destination.entity_id:
		_status_text = "Loot source and destination must be different entities."
		return {}
	var source_clone := source.duplicate_instance()
	var destination_clone := destination.duplicate_instance()
	var moved_count := _move_all_parts(source_clone, destination_clone)
	var currency_count := 0
	if bool(_params.get("include_currencies", true)):
		currency_count = _move_all_currencies(source_clone, destination_clone)
	if moved_count <= 0 and currency_count <= 0:
		_status_text = str(_params.get("empty_label", "Nothing is available to take."))
		return {}
	_commit_transfer(source_clone, destination_clone)
	_status_text = "Took %s item%s%s." % [
		str(moved_count),
		"" if moved_count == 1 else "s",
		" and %s currency balance%s" % [str(currency_count), "" if currency_count == 1 else "s"] if currency_count > 0 else "",
	]
	_selected_instance_id = ""
	return _build_completion_action(source_clone)


func _empty_view_model(title: String, description: String, summary: String, empty_label: String, status_text: String) -> Dictionary:
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": [],
		"currency_rows": [],
		"selected_detail": {},
		"detail_kind": "",
		"status_text": status_text,
		"confirm_label": str(_params.get("confirm_label", "Take Selected")),
		"take_all_label": str(_params.get("take_all_label", "Take All")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": false,
		"take_all_enabled": false,
		"source_name": "",
		"destination_name": "",
	}


func _build_rows(source: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for part_data in source.inventory:
		var part := part_data as PartInstance
		if part == null or part.is_equipped:
			continue
		var template := part.get_template()
		if template.is_empty():
			continue
		rows.append({
			"row_id": part.instance_id,
			"instance_id": part.instance_id,
			"template_id": part.template_id,
			"display_name": str(template.get("display_name", part.template_id)),
			"detail_text": str(template.get("description", "")),
			"selected": part.instance_id == _selected_instance_id,
			"detail_kind": "part_card",
			"detail_view_model": BACKEND_HELPERS.build_part_card_view_model(
				template,
				"",
				1.0,
				[{"label": "Available", "color_token": "primary"}],
				true
			),
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _build_currency_rows(source: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not bool(_params.get("include_currencies", true)):
		return rows
	var currency_ids: Array = source.currencies.keys()
	currency_ids.sort()
	for currency_id_value in currency_ids:
		var currency_id := str(currency_id_value)
		var amount := source.get_currency(currency_id)
		if amount <= 0.0:
			continue
		rows.append({
			"currency_id": currency_id,
			"display_name": BACKEND_HELPERS.humanize_id(currency_id),
			"amount": amount,
			"detail_text": _format_amount(amount),
		})
	return rows


func _build_status_text(rows: Array[Dictionary], currency_rows: Array[Dictionary], selected_row: Dictionary, source: EntityInstance, destination: EntityInstance, empty_label: String) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty() and currency_rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Review loot from %s for %s." % [
			BACKEND_HELPERS.get_entity_display_name(source, source.entity_id),
			BACKEND_HELPERS.get_entity_display_name(destination, destination.entity_id),
		]
	return "Ready to take %s." % str(selected_row.get("display_name", "the selected item"))


func _move_all_parts(source: EntityInstance, destination: EntityInstance) -> int:
	var instance_ids: Array[String] = []
	for part_data in source.inventory:
		var part := part_data as PartInstance
		if part == null or part.is_equipped:
			continue
		instance_ids.append(part.instance_id)
	var moved := 0
	for instance_id in instance_ids:
		var part := source.get_inventory_part(instance_id)
		if part == null:
			continue
		var moved_part := _duplicate_part(part)
		if moved_part == null or not source.remove_part(instance_id):
			continue
		destination.add_part(moved_part)
		_emit_part_transfer(source.entity_id, destination.entity_id, moved_part.template_id)
		moved += 1
	return moved


func _move_all_currencies(source: EntityInstance, destination: EntityInstance) -> int:
	var moved_balances := 0
	var currency_ids: Array = source.currencies.keys()
	for currency_id_value in currency_ids:
		var currency_id := str(currency_id_value)
		var amount := source.get_currency(currency_id)
		if amount <= 0.0:
			continue
		if source.spend_currency(currency_id, amount):
			destination.add_currency(currency_id, amount)
			moved_balances += 1
	return moved_balances


func _commit_transfer(source: EntityInstance, destination: EntityInstance) -> void:
	GameState.commit_entity_instance(source, source.entity_id)
	GameState.commit_entity_instance(destination, destination.entity_id)


func _emit_part_transfer(source_id: String, destination_id: String, template_id: String) -> void:
	if GameEvents == null:
		return
	GameEvents.part_removed.emit(source_id, template_id)
	GameEvents.part_acquired.emit(destination_id, template_id)


func _build_completion_action(source: EntityInstance) -> Dictionary:
	if bool(_params.get("pop_when_empty", true)) and source.inventory.is_empty() and _build_currency_rows(source).is_empty():
		return {"type": "pop"}
	return {}


func _duplicate_part(part: PartInstance) -> PartInstance:
	if part == null:
		return null
	var moved_part := PartInstance.new()
	moved_part.from_dict(part.to_dict())
	moved_part.is_equipped = false
	moved_part.equipped_slot = ""
	return moved_part


func _get_part_display_name(part: PartInstance) -> String:
	if part == null:
		return "item"
	var template := part.get_template()
	return str(template.get("display_name", part.template_id))


func _resolve_source_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_resolve_lookup_id(str(_params.get("source_entity_id", ""))))


func _resolve_destination_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_resolve_lookup_id(str(_params.get("destination_entity_id", "player"))))


func _resolve_lookup_id(raw_id: String) -> String:
	var lookup_id := raw_id.strip_edges()
	if lookup_id.begins_with("entity:"):
		lookup_id = lookup_id.trim_prefix("entity:")
	return lookup_id


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("instance_id", "")) == _selected_instance_id:
			return row
	return {}


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_instance_id = ""
		return
	for row in rows:
		if str(row.get("instance_id", "")) == _selected_instance_id:
			return
	_selected_instance_id = str(rows[0].get("instance_id", ""))


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}


func _format_amount(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return "%d" % int(roundf(amount))
	return "%.2f" % amount
