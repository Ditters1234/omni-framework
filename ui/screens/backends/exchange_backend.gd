extends "res://ui/screens/backends/backend_base.gd"

class_name OmniExchangeBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}
var _selected_instance_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ExchangeBackend", {
		"required": ["source_inventory", "destination_inventory", "currency_id"],
		"optional": [
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"cancel_label",
			"price_modifier",
			"transaction_sound",
			"empty_label",
			"next_screen_id",
			"next_screen_params",
			"pop_on_confirm",
		],
		"field_types": {
			"source_inventory": TYPE_STRING,
			"destination_inventory": TYPE_STRING,
			"currency_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"price_modifier": TYPE_FLOAT,
			"transaction_sound": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"next_screen_id": TYPE_STRING,
			"next_screen_params": TYPE_DICTIONARY,
			"pop_on_confirm": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_instance_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var source_entity := _resolve_source_entity()
	var destination_entity := _resolve_destination_entity()
	var title := str(_params.get("screen_title", "Exchange"))
	var description := str(_params.get("screen_description", "Purchase stocked parts from another entity's live inventory."))
	var summary := str(_params.get("screen_summary", "Select an item from the left to inspect it, then confirm the purchase on the right."))
	var empty_label := str(_params.get("empty_label", "This inventory is empty."))
	if source_entity == null or destination_entity == null:
		return {
			"title": title,
			"description": description,
			"summary": summary,
			"rows": [],
			"selected_card": {},
			"currency_display": {},
			"status_text": "The exchange could not resolve both inventory owners.",
			"confirm_label": str(_params.get("confirm_label", "Buy Selected")),
			"cancel_label": str(_params.get("cancel_label", "Back")),
			"empty_label": empty_label,
			"confirm_enabled": false,
			"source_name": "",
			"destination_name": "",
		}

	var stock := _get_stock_rows(source_entity)
	_select_first_row_if_needed(stock)
	var selected_row := _get_selected_row(stock)
	var selected_card := _build_selected_card_view_model(selected_row)
	var currency_id := str(_params.get("currency_id", ""))
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": stock,
		"selected_card": selected_card,
		"currency_display": BACKEND_HELPERS.build_currency_display_view_model(destination_entity, currency_id),
		"status_text": _build_status_text(stock, selected_row, source_entity, destination_entity, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Buy Selected")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty() and bool(selected_row.get("affordable", false)),
		"source_name": BACKEND_HELPERS.get_entity_display_name(source_entity, source_entity.entity_id),
		"destination_name": BACKEND_HELPERS.get_entity_display_name(destination_entity, destination_entity.entity_id),
	}


func select_row(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_status_text = ""


func confirm() -> Dictionary:
	var source_entity := _resolve_source_entity()
	var destination_entity := _resolve_destination_entity()
	if source_entity == null or destination_entity == null:
		_status_text = "The exchange could not resolve both inventory owners."
		return {}
	if source_entity.entity_id == destination_entity.entity_id:
		_status_text = "The buyer and seller cannot be the same inventory owner."
		return {}
	var price_modifier := _get_price_modifier()
	var source_clone := source_entity.duplicate_instance()
	var destination_clone := destination_entity.duplicate_instance()
	var source_part := _find_inventory_part(source_clone, _selected_instance_id)
	if source_part == null:
		_status_text = "Select an available item before confirming the exchange."
		return {}
	if source_part.is_equipped:
		_status_text = "Equipped parts cannot be sold through this exchange."
		return {}
	var template := source_part.get_template()
	if template.is_empty():
		_status_text = "That stocked part no longer has a valid template."
		return {}
	var currency_id := str(_params.get("currency_id", ""))
	var price := BACKEND_HELPERS.get_part_price_for_currency(template, currency_id, price_modifier)
	if price > 0.0 and destination_clone.get_currency(currency_id) < price:
		_status_text = "%s cannot afford that purchase." % BACKEND_HELPERS.get_entity_display_name(destination_entity, destination_entity.entity_id)
		return {}
	var moved_part := PartInstance.new()
	moved_part.from_dict(source_part.to_dict())
	moved_part.is_equipped = false
	moved_part.equipped_slot = ""
	if not source_clone.remove_part(source_part.instance_id):
		_status_text = "The selected item could not be removed from the source inventory."
		return {}
	if price > 0.0 and not TransactionService.transfer_currency(destination_clone, source_clone, currency_id, price, moved_part.template_id, false):
		_status_text = "The buyer could not cover the item cost."
		return {}
	destination_clone.add_part(moved_part)
	GameState.commit_entity_instance(source_clone, _resolve_lookup_id(str(_params.get("source_inventory", ""))))
	GameState.commit_entity_instance(destination_clone, _resolve_lookup_id(str(_params.get("destination_inventory", ""))))
	if GameEvents != null:
		GameEvents.part_removed.emit(source_clone.entity_id, moved_part.template_id)
		GameEvents.part_acquired.emit(destination_clone.entity_id, moved_part.template_id)
		if price > 0.0:
			GameEvents.transaction_completed.emit(destination_clone.entity_id, source_clone.entity_id, moved_part.template_id, price)
	var transaction_sound := str(_params.get("transaction_sound", ""))
	if not transaction_sound.is_empty():
		AudioManager.play_sfx(transaction_sound)
	_status_text = "Purchased %s for %s." % [
		str(template.get("display_name", moved_part.template_id)),
		BACKEND_HELPERS.build_price_text(template, currency_id, price_modifier).trim_prefix("Price: "),
	]
	var next_screen_id := str(_params.get("next_screen_id", ""))
	if not next_screen_id.is_empty():
		return {
			"type": "push_screen",
			"screen_id": next_screen_id,
			"params": _params.get("next_screen_params", {}),
		}
	if _params.get("pop_on_confirm", false):
		return {"type": "pop_screen"}
	return {}


func _resolve_source_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_resolve_lookup_id(str(_params.get("source_inventory", ""))))


func _resolve_destination_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_resolve_lookup_id(str(_params.get("destination_inventory", ""))))


func _resolve_lookup_id(inventory_ref: String) -> String:
	var normalized_ref := inventory_ref.strip_edges()
	if normalized_ref.begins_with("entity:"):
		normalized_ref = normalized_ref.trim_prefix("entity:")
	if normalized_ref == "player":
		return "player"
	var segments := normalized_ref.split(":", false)
	if segments.size() >= 2:
		var suffix := str(segments[segments.size() - 1])
		if suffix == "inventory" or suffix == "equipped":
			return ":".join(segments.slice(0, segments.size() - 1))
	return normalized_ref


func _get_stock_rows(source_entity: EntityInstance) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var price_modifier := _get_price_modifier()
	var currency_id := str(_params.get("currency_id", ""))
	var destination_entity := _resolve_destination_entity()
	for part_data in source_entity.inventory:
		var part: PartInstance = part_data as PartInstance
		if part == null or part.is_equipped:
			continue
		var template := part.get_template()
		if template.is_empty():
			continue
		var price := BACKEND_HELPERS.get_part_price_for_currency(template, currency_id, price_modifier)
		var affordable := destination_entity != null and destination_entity.get_currency(currency_id) >= price
		result.append({
			"instance_id": part.instance_id,
			"template_id": part.template_id,
			"display_name": str(template.get("display_name", part.template_id)),
			"price_text": BACKEND_HELPERS.build_price_text(template, currency_id, price_modifier),
			"affordable": affordable,
			"selected": part.instance_id == _selected_instance_id,
			"card_view_model": BACKEND_HELPERS.build_part_card_view_model(
				template,
				currency_id,
				price_modifier,
				[
					{"label": "Stock", "color_token": "primary"},
					{"label": "Affordable" if affordable else "Too Expensive", "color_token": "positive" if affordable else "negative"},
				],
				affordable
			),
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	result.sort_custom(sort_callable)
	return result


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_instance_id = ""
		return
	for row in rows:
		if str(row.get("instance_id", "")) == _selected_instance_id:
			return
	_selected_instance_id = str(rows[0].get("instance_id", ""))


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("instance_id", "")) == _selected_instance_id:
			return row
	return {}


func _build_selected_card_view_model(selected_row: Dictionary) -> Dictionary:
	var card_view_model_value: Variant = selected_row.get("card_view_model", {})
	if card_view_model_value is Dictionary:
		var card_view_model: Dictionary = card_view_model_value
		return card_view_model.duplicate(true)
	return {}


func _build_status_text(
	rows: Array[Dictionary],
	selected_row: Dictionary,
	source_entity: EntityInstance,
	destination_entity: EntityInstance,
	empty_label: String
) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select an item from %s to inspect it." % BACKEND_HELPERS.get_entity_display_name(source_entity, source_entity.entity_id)
	var affordable := bool(selected_row.get("affordable", false))
	if affordable:
		return "%s can buy %s from %s." % [
			BACKEND_HELPERS.get_entity_display_name(destination_entity, destination_entity.entity_id),
			str(selected_row.get("display_name", "this item")),
			BACKEND_HELPERS.get_entity_display_name(source_entity, source_entity.entity_id),
		]
	return "%s cannot currently afford %s." % [
		BACKEND_HELPERS.get_entity_display_name(destination_entity, destination_entity.entity_id),
		str(selected_row.get("display_name", "that item")),
	]


func _find_inventory_part(entity: EntityInstance, instance_id: String) -> PartInstance:
	if entity == null or instance_id.is_empty():
		return null
	for part_data in entity.inventory:
		var part: PartInstance = part_data as PartInstance
		if part == null:
			continue
		if part.instance_id == instance_id:
			return part
	return null


func _get_price_modifier() -> float:
	var price_modifier_value: Variant = _params.get("price_modifier", 1.0)
	if price_modifier_value is int or price_modifier_value is float:
		return maxf(float(price_modifier_value), 0.0)
	return 1.0
