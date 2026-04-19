extends RefCounted

class_name OmniBackendHelpers


static func humanize_id(value: String) -> String:
	if value.is_empty():
		return ""
	var trimmed := value.get_slice(":", value.get_slice_count(":") - 1)
	var words := trimmed.split("_", false)
	var formatted_words: Array[String] = []
	for word_value in words:
		var word := str(word_value)
		if word.is_empty():
			continue
		formatted_words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(formatted_words)


static func resolve_entity_lookup(lookup_id: String) -> EntityInstance:
	var normalized_lookup := lookup_id.strip_edges()
	if normalized_lookup.is_empty() or normalized_lookup == "player":
		return GameState.player as EntityInstance
	if normalized_lookup.begins_with("entity:"):
		normalized_lookup = normalized_lookup.trim_prefix("entity:")
	return GameState.get_entity_instance(normalized_lookup)


static func get_currency_symbol() -> String:
	var currency_symbol_value: Variant = DataManager.get_config_value("ui.currency_symbol", "$")
	if currency_symbol_value is String:
		return str(currency_symbol_value)
	return "$"


static func get_part_default_sprite_paths() -> Dictionary:
	var sprite_paths_value: Variant = DataManager.get_config_value("ui.default_sprites.parts", {})
	if sprite_paths_value is Dictionary:
		var sprite_paths: Dictionary = sprite_paths_value
		return sprite_paths.duplicate(true)
	return {}


static func get_entity_template(entity: EntityInstance) -> Dictionary:
	if entity == null:
		return {}
	var template_value: Variant = entity.get_template()
	if template_value is Dictionary:
		var template: Dictionary = template_value
		return template.duplicate(true)
	return {}


static func get_entity_display_name(entity: EntityInstance, fallback_name: String = "") -> String:
	if entity == null:
		return fallback_name
	var template := get_entity_template(entity)
	return str(template.get("display_name", fallback_name if not fallback_name.is_empty() else entity.entity_id))


static func build_currency_display_view_model(entity: EntityInstance, currency_id: String = "", color_token: String = "primary") -> Dictionary:
	if entity == null:
		return {}
	var resolved_currency_id := currency_id
	if resolved_currency_id.is_empty():
		var currency_keys: Array = entity.currencies.keys()
		currency_keys.sort()
		if not currency_keys.is_empty():
			resolved_currency_id = str(currency_keys[0])
	if resolved_currency_id.is_empty():
		return {}
	return {
		"currency_id": resolved_currency_id,
		"label": humanize_id(resolved_currency_id),
		"amount": entity.get_currency(resolved_currency_id),
		"symbol": get_currency_symbol(),
		"color_token": color_token,
	}


static func build_priority_stat_preview(entity: EntityInstance, limit: int = 2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entity == null or limit <= 0:
		return result
	var stat_definitions_value: Variant = DataManager.get_definitions("stats")
	if stat_definitions_value is Array:
		var stat_definitions: Array = stat_definitions_value
		for stat_definition_value in stat_definitions:
			if not stat_definition_value is Dictionary:
				continue
			var stat_definition: Dictionary = stat_definition_value
			if str(stat_definition.get("kind", "flat")) != "resource":
				continue
			var line := build_stat_line(entity, stat_definition)
			if line.is_empty():
				continue
			result.append(line)
			if result.size() >= limit:
				return result
	var stat_keys: Array = entity.stats.keys()
	stat_keys.sort()
	for stat_key_value in stat_keys:
		var stat_id := str(stat_key_value)
		if stat_id.ends_with("_max"):
			continue
		result.append({
			"stat_id": stat_id,
			"label": humanize_id(stat_id),
			"value": float(entity.stats.get(stat_id, 0.0)),
			"color_token": "info",
		})
		if result.size() >= limit:
			break
	return result


static func build_stat_line(entity: EntityInstance, stat_definition: Dictionary) -> Dictionary:
	if entity == null:
		return {}
	var stat_id := str(stat_definition.get("id", ""))
	if stat_id.is_empty() or not entity.stats.has(stat_id):
		return {}
	var color_token := _color_token_for_group(str(stat_definition.get("ui_group", "other")))
	var kind := str(stat_definition.get("kind", "flat"))
	if kind == "resource":
		var capacity_id := str(stat_definition.get("paired_capacity_id", ""))
		return {
			"stat_id": stat_id,
			"label": humanize_id(stat_id),
			"value": float(entity.stats.get(stat_id, 0.0)),
			"max_value": float(entity.stats.get(capacity_id, 0.0)),
			"color_token": color_token,
		}
	return {
		"stat_id": stat_id,
		"label": humanize_id(stat_id),
		"value": float(entity.stats.get(stat_id, 0.0)),
		"color_token": color_token,
	}


static func build_entity_portrait_view_model(
	entity: EntityInstance,
	fallback_name: String = "",
	fallback_description: String = "",
	faction_id: String = ""
) -> Dictionary:
	if entity == null:
		return {
			"display_name": fallback_name if not fallback_name.is_empty() else "Unknown Entity",
			"description": fallback_description,
			"stat_preview": [],
		}
	var template := get_entity_template(entity)
	return {
		"display_name": get_entity_display_name(entity, fallback_name),
		"description": str(template.get("description", fallback_description)),
		"emblem_path": _resolve_entity_emblem_path(template),
		"faction_badge": build_faction_badge_view_model(entity, faction_id),
		"stat_preview": build_priority_stat_preview(entity),
	}


static func build_faction_badge_view_model(entity: EntityInstance, faction_id: String = "") -> Dictionary:
	var resolved_faction_id := faction_id
	if entity != null and resolved_faction_id.is_empty():
		var reputation_keys: Array = entity.reputation.keys()
		reputation_keys.sort()
		if not reputation_keys.is_empty():
			resolved_faction_id = str(reputation_keys[0])
	if resolved_faction_id.is_empty():
		return {}
	var faction := DataManager.get_faction(resolved_faction_id)
	var reputation_value := 0.0 if entity == null else entity.get_reputation(resolved_faction_id)
	return {
		"faction_id": resolved_faction_id,
		"emblem_path": _resolve_faction_emblem_path(faction),
		"reputation_tier": _reputation_tier_for_value(reputation_value),
		"reputation_value": reputation_value,
		"color": str(faction.get("faction_color", "secondary")),
	}


static func build_part_card_view_model(
	template: Dictionary,
	currency_id: String = "",
	price_modifier: float = 1.0,
	badges: Array = [],
	affordable: bool = true,
	custom_price_text: String = ""
) -> Dictionary:
	return {
		"template": template.duplicate(true),
		"default_sprite_paths": get_part_default_sprite_paths(),
		"price_text": custom_price_text if not custom_price_text.is_empty() else build_price_text(template, currency_id, price_modifier),
		"badges": badges.duplicate(true),
		"affordable": affordable,
	}


static func get_part_price_for_currency(template: Dictionary, currency_id: String, price_modifier: float = 1.0) -> float:
	if template.is_empty() or currency_id.is_empty():
		return 0.0
	var price_value: Variant = template.get("price", {})
	if not price_value is Dictionary:
		return 0.0
	var price: Dictionary = price_value
	var raw_amount: Variant = price.get(currency_id, 0.0)
	var amount := 0.0
	if raw_amount is int or raw_amount is float:
		amount = float(raw_amount)
	amount = maxf(amount, 0.0)
	var safe_modifier := maxf(price_modifier, 0.0)
	return amount * safe_modifier


static func build_price_text(template: Dictionary, currency_id: String = "", price_modifier: float = 1.0) -> String:
	if template.is_empty():
		return ""
	if not currency_id.is_empty():
		var amount := get_part_price_for_currency(template, currency_id, price_modifier)
		return "Price: %s %s" % [_format_number(amount), humanize_id(currency_id)]
	var price_value: Variant = template.get("price", {})
	if not price_value is Dictionary:
		return ""
	var price: Dictionary = price_value
	if price.is_empty():
		return ""
	var keys: Array = price.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		var price_key := str(key_value)
		var amount_value: Variant = price.get(key_value, 0.0)
		var amount := 0.0
		if amount_value is int or amount_value is float:
			amount = float(amount_value)
		parts.append("%s %s" % [_format_number(amount * maxf(price_modifier, 0.0)), humanize_id(price_key)])
	return "Price: %s" % ", ".join(parts)


static func build_task_card_view_model(task_template: Dictionary) -> Dictionary:
	var template_id := str(task_template.get("template_id", ""))
	var duration := int(task_template.get("duration", task_template.get("travel_cost", 1)))
	var objective_label := _build_task_objective_label(task_template)
	return {
		"quest_id": template_id,
		"display_name": str(task_template.get("display_name", task_template.get("title", humanize_id(template_id)))),
		"current_stage": humanize_id(str(task_template.get("type", "WAIT"))),
		"objectives": [
			{
				"label": objective_label,
				"satisfied": false,
			},
			{
				"label": "Estimated Duration: %s ticks" % str(duration),
				"satisfied": false,
			},
		],
		"rewards": _duplicate_dictionary(task_template.get("reward", {})),
	}


static func _build_task_objective_label(task_template: Dictionary) -> String:
	var target := str(task_template.get("target", ""))
	if target.is_empty():
		return str(task_template.get("description", "Complete the offered task."))
	return "%s %s" % [str(task_template.get("description", "Reach")), humanize_id(target)]


static func _resolve_entity_emblem_path(entity_template: Dictionary) -> String:
	var emblem_fields := ["portrait", "emblem_path", "sprite"]
	for field_name_value in emblem_fields:
		var field_name := str(field_name_value)
		var resource_path := str(entity_template.get(field_name, ""))
		if resource_path.is_empty():
			continue
		if ResourceLoader.exists(resource_path):
			return resource_path
	return ""


static func _resolve_faction_emblem_path(faction_template: Dictionary) -> String:
	var emblem_fields := ["emblem_path", "portrait", "icon"]
	for field_name_value in emblem_fields:
		var field_name := str(field_name_value)
		var resource_path := str(faction_template.get(field_name, ""))
		if resource_path.is_empty():
			continue
		if ResourceLoader.exists(resource_path):
			return resource_path
	return ""


static func _reputation_tier_for_value(value: float) -> String:
	if value >= 75.0:
		return "Allied"
	if value >= 25.0:
		return "Friendly"
	if value <= -75.0:
		return "Hostile"
	if value <= -25.0:
		return "Unfriendly"
	return "Neutral"


static func _color_token_for_group(group_name: String) -> String:
	match group_name:
		"combat":
			return "warning"
		"survival":
			return "positive"
		"economy":
			return "primary"
		_:
			return "info"


static func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount


static func _duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
