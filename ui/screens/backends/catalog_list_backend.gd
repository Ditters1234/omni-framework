extends "res://ui/screens/backends/backend_base.gd"

class_name OmniCatalogListBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}
var _selected_template_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("CatalogListBackend", {
		"required": ["data_source"],
		"optional": [
			"action_payload",
			"buyer_entity_id",
			"currency_id",
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"cancel_label",
			"price_modifier",
			"option_tags",
			"template_ids",
			"empty_label",
			"next_screen_id",
			"next_screen_params",
			"pop_on_confirm",
		],
		"field_types": {
			"data_source": TYPE_STRING,
			"action_payload": TYPE_DICTIONARY,
			"buyer_entity_id": TYPE_STRING,
			"currency_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"price_modifier": TYPE_FLOAT,
			"option_tags": TYPE_ARRAY,
			"template_ids": TYPE_ARRAY,
			"empty_label": TYPE_STRING,
			"next_screen_id": TYPE_STRING,
			"next_screen_params": TYPE_DICTIONARY,
			"pop_on_confirm": TYPE_BOOL,
		},
		"array_element_types": {
			"option_tags": TYPE_STRING,
			"template_ids": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_template_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var buyer := _resolve_buyer()
	var title := str(_params.get("screen_title", "Catalog Vendor"))
	var description := str(_params.get("screen_description", "Purchase fresh template instances directly from the parts registry."))
	var summary := str(_params.get("screen_summary", "Select a catalog item to inspect it, then mint a new copy into the buyer inventory."))
	var empty_label := str(_params.get("empty_label", "This catalog has no matching items."))
	if buyer == null:
		return {
			"title": title,
			"description": description,
			"summary": summary,
			"rows": [],
			"selected_card": {},
			"currency_display": {},
			"status_text": "The catalog could not resolve the buyer entity.",
			"confirm_label": str(_params.get("confirm_label", "Buy Selected")),
			"cancel_label": str(_params.get("cancel_label", "Back")),
			"empty_label": empty_label,
			"confirm_enabled": false,
		}
	var rows := _build_catalog_rows(buyer)
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": rows,
		"selected_card": _read_card_view_model(selected_row),
		"currency_display": BACKEND_HELPERS.build_currency_display_view_model(buyer, str(_params.get("currency_id", ""))),
		"status_text": _build_status_text(rows, selected_row, buyer, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Buy Selected")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty() and bool(selected_row.get("affordable", false)),
	}


func select_row(template_id: String) -> void:
	_selected_template_id = template_id
	_status_text = ""


func confirm() -> Dictionary:
	if str(_params.get("data_source", "")) != "catalog":
		_status_text = "CatalogListBackend currently only supports data_source = 'catalog'."
		return {}
	var buyer := _resolve_buyer()
	if buyer == null:
		_status_text = "The buyer entity could not be resolved."
		return {}
	var template := DataManager.get_part(_selected_template_id)
	if template.is_empty():
		_status_text = "Select a valid catalog item before purchasing."
		return {}
	var currency_id := str(_params.get("currency_id", ""))
	var price_modifier := _get_price_modifier()
	var price := BACKEND_HELPERS.get_part_price_for_currency(template, currency_id, price_modifier)
	var buyer_clone := buyer.duplicate_instance()
	if price > 0.0 and not TransactionService.spend_currency(buyer_clone, currency_id, price):
		_status_text = "%s cannot afford that purchase." % BACKEND_HELPERS.get_entity_display_name(buyer, buyer.entity_id)
		return {}
	var new_part := PartInstance.from_template(template)
	buyer_clone.add_part(new_part)
	GameState.commit_entity_instance(buyer_clone, _resolve_buyer_lookup())
	if GameEvents != null:
		GameEvents.part_acquired.emit(buyer_clone.entity_id, new_part.template_id)
	_dispatch_catalog_action(template, buyer_clone)
	_status_text = "Purchased %s for %s." % [
		str(template.get("display_name", new_part.template_id)),
		BACKEND_HELPERS.build_price_text(template, currency_id, price_modifier).trim_prefix("Price: "),
	]
	var next_screen_id := str(_params.get("next_screen_id", ""))
	if not next_screen_id.is_empty():
		return {
			"type": "push",
			"screen_id": next_screen_id,
			"params": _params.get("next_screen_params", {}).duplicate(true),
		}
	if _params.get("pop_on_confirm", false):
		return {"type": "pop"}
	return {}


func _resolve_buyer() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_resolve_buyer_lookup())


func _resolve_buyer_lookup() -> String:
	var buyer_lookup := str(_params.get("buyer_entity_id", "player"))
	if buyer_lookup.is_empty():
		return "player"
	return buyer_lookup


func _build_catalog_rows(buyer: EntityInstance) -> Array[Dictionary]:
	var filters: Dictionary = {}
	var option_tags := _read_string_array(_params.get("option_tags", []))
	if not option_tags.is_empty():
		filters["tags"] = option_tags
	var template_ids := _read_string_array(_params.get("template_ids", []))
	if not template_ids.is_empty():
		filters["template_ids"] = template_ids
	var parts := DataManager.query_parts(filters)
	var result: Array[Dictionary] = []
	var currency_id := str(_params.get("currency_id", ""))
	var price_modifier := _get_price_modifier()
	for part_template in parts:
		var template_id := str(part_template.get("id", ""))
		if template_id.is_empty():
			continue
		var price := BACKEND_HELPERS.get_part_price_for_currency(part_template, currency_id, price_modifier)
		var affordable := buyer.get_currency(currency_id) >= price
		result.append({
			"template_id": template_id,
			"display_name": str(part_template.get("display_name", template_id)),
			"price_text": BACKEND_HELPERS.build_price_text(part_template, currency_id, price_modifier),
			"selected": template_id == _selected_template_id,
			"affordable": affordable,
			"card_view_model": BACKEND_HELPERS.build_part_card_view_model(
				part_template,
				currency_id,
				price_modifier,
				[
					{"label": "Catalog", "color_token": "primary"},
					{"label": "Affordable" if affordable else "Too Expensive", "color_token": "positive" if affordable else "negative"},
				],
				affordable
			),
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	result.sort_custom(sort_callable)
	return result


func _dispatch_catalog_action(template: Dictionary, buyer: EntityInstance) -> void:
	var action_payload_value: Variant = _params.get("action_payload", {})
	if not action_payload_value is Dictionary:
		return
	var action_payload: Dictionary = action_payload_value.duplicate(true)
	var action_type := str(action_payload.get("type", ""))
	if action_type == "buy_item":
		return
	if not action_payload.has("template_id"):
		action_payload["template_id"] = str(template.get("id", ""))
	if not action_payload.has("part_id"):
		action_payload["part_id"] = str(template.get("id", ""))
	if not action_payload.has("entity_id"):
		action_payload["entity_id"] = buyer.entity_id
	ActionDispatcher.dispatch(action_payload)


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_template_id = ""
		return
	for row in rows:
		if str(row.get("template_id", "")) == _selected_template_id:
			return
	_selected_template_id = str(rows[0].get("template_id", ""))


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("template_id", "")) == _selected_template_id:
			return row
	return {}


func _read_card_view_model(row: Dictionary) -> Dictionary:
	var card_view_model_value: Variant = row.get("card_view_model", {})
	if card_view_model_value is Dictionary:
		var card_view_model: Dictionary = card_view_model_value
		return card_view_model.duplicate(true)
	return {}


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, buyer: EntityInstance, empty_label: String) -> String:
	if not _status_text.is_empty():
		return _status_text
	if str(_params.get("data_source", "")) != "catalog":
		return "CatalogListBackend currently only supports data_source = 'catalog'."
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select a catalog item to inspect it."
	if bool(selected_row.get("affordable", false)):
		return "%s can afford %s." % [
			BACKEND_HELPERS.get_entity_display_name(buyer, buyer.entity_id),
			str(selected_row.get("display_name", "that item")),
		]
	return "%s cannot currently afford %s." % [
		BACKEND_HELPERS.get_entity_display_name(buyer, buyer.entity_id),
		str(selected_row.get("display_name", "that item")),
	]


func _get_price_modifier() -> float:
	var price_modifier_value: Variant = _params.get("price_modifier", 1.0)
	if price_modifier_value is int or price_modifier_value is float:
		return maxf(float(price_modifier_value), 0.0)
	return 1.0


func _read_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for item in values:
		var text := str(item)
		if text.is_empty():
			continue
		result.append(text)
	return result
