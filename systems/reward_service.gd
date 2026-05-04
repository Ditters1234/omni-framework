## RewardService -- Shared runtime helper for applying reward dictionaries.
## Keeps task, quest, and action reward handling consistent across systems.
extends RefCounted

class_name RewardService


static func apply_reward(entity: EntityInstance, reward_data: Variant, emit_events: bool = true) -> Array[Dictionary]:
	var deferred_events: Array[Dictionary] = []
	if entity == null or not reward_data is Dictionary:
		return deferred_events
	var reward: Dictionary = reward_data
	for reward_key_value in reward.keys():
		var reward_key := str(reward_key_value)
		var reward_value: Variant = reward.get(reward_key_value, null)
		match reward_key:
			"reputation":
				_apply_reputation_reward(entity, reward_value)
			"items":
				_apply_item_reward(entity, reward_value, emit_events, deferred_events)
			"flags":
				_apply_flag_reward(entity, reward_value, emit_events, deferred_events)
			_:
				var amount := 0.0
				if reward_value is int or reward_value is float:
					amount = float(reward_value)
				_apply_currency_reward(entity, reward_key, amount, emit_events, deferred_events)
	return deferred_events


static func build_reward_lines(reward_data: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not reward_data is Dictionary:
		return lines
	var reward: Dictionary = reward_data
	if reward.is_empty():
		return lines
	var keys: Array = reward.keys()
	keys.sort()
	for reward_key_value in keys:
		var reward_key := str(reward_key_value)
		var reward_value: Variant = reward.get(reward_key_value, null)
		match reward_key:
			"items":
				lines.append_array(_build_item_reward_lines(reward_value))
			"flags":
				lines.append_array(_build_flag_reward_lines(reward_value))
			"reputation":
				lines.append_array(_build_reputation_reward_lines(reward_value))
			_:
				if reward_value is int or reward_value is float:
					var amount := float(reward_value)
					if amount != 0.0:
						lines.append("%s %s" % [_humanize_id(reward_key), _format_signed_number(amount)])
	return lines


static func build_reward_summary(reward_data: Variant, empty_text: String = "No rewards") -> String:
	var lines := build_reward_lines(reward_data)
	if lines.is_empty():
		return empty_text
	return ", ".join(lines)


static func _apply_reputation_reward(entity: EntityInstance, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reputation_reward: Dictionary = reward_value
	for faction_id_value in reputation_reward.keys():
		var faction_id := str(faction_id_value)
		var amount := float(reputation_reward.get(faction_id_value, 0.0))
		entity.add_reputation(faction_id, amount)


static func _apply_item_reward(
	entity: EntityInstance,
	reward_value: Variant,
	emit_events: bool,
	deferred_events: Array[Dictionary]
) -> void:
	if not reward_value is Array:
		return
	var item_list: Array = reward_value
	for item_entry in item_list:
		if item_entry is String:
			_grant_template(entity, str(item_entry), 1, emit_events, deferred_events)
			continue
		if not item_entry is Dictionary:
			continue
		var item_dict: Dictionary = item_entry
		var template_id := str(item_dict.get("template_id", item_dict.get("part_id", "")))
		var count := int(item_dict.get("count", item_dict.get("quantity", 1)))
		_grant_template(entity, template_id, count, emit_events, deferred_events)


static func _apply_flag_reward(
	entity: EntityInstance,
	reward_value: Variant,
	emit_events: bool,
	deferred_events: Array[Dictionary]
) -> void:
	if not reward_value is Dictionary:
		return
	var flag_reward: Dictionary = reward_value
	for flag_key_value in flag_reward.keys():
		var flag_key := str(flag_key_value)
		var flag_value: Variant = flag_reward.get(flag_key_value, true)
		if emit_events:
			entity.set_flag(flag_key, flag_value)
		else:
			entity.flags[flag_key] = flag_value
			deferred_events.append({
				"signal": "flag_changed",
				"entity_id": entity.entity_id,
				"flag_id": flag_key,
				"value": flag_value,
			})


static func _apply_currency_reward(
	entity: EntityInstance,
	currency_id: String,
	amount: float,
	emit_events: bool,
	deferred_events: Array[Dictionary]
) -> void:
	if currency_id.is_empty():
		return
	if emit_events:
		entity.add_currency(currency_id, amount)
		return
	var old_amount := entity.get_currency(currency_id)
	entity.currencies[currency_id] = old_amount + amount
	deferred_events.append({
		"signal": "entity_currency_changed",
		"entity_id": entity.entity_id,
		"currency_id": currency_id,
		"old_amount": old_amount,
		"new_amount": entity.get_currency(currency_id),
	})


static func _grant_template(
	entity: EntityInstance,
	template_id: String,
	count: int,
	emit_events: bool,
	deferred_events: Array[Dictionary]
) -> void:
	if entity == null or template_id.is_empty() or count <= 0:
		return
	var template := DataManager.get_part(template_id)
	if template.is_empty():
		return
	for _i in range(count):
		var part := PartInstance.from_template(template)
		entity.add_part(part)
		if emit_events:
			GameEvents.part_acquired.emit(entity.entity_id, part.template_id)
		else:
			deferred_events.append({
				"signal": "part_acquired",
				"entity_id": entity.entity_id,
				"template_id": part.template_id,
			})


static func _build_item_reward_lines(reward_value: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not reward_value is Array:
		return lines
	var item_list: Array = reward_value
	for item_entry in item_list:
		var template_id := ""
		var count := 1
		if item_entry is String:
			template_id = str(item_entry)
		elif item_entry is Dictionary:
			var item_dict: Dictionary = item_entry
			template_id = str(item_dict.get("template_id", item_dict.get("part_id", "")))
			count = maxi(1, int(item_dict.get("count", item_dict.get("quantity", 1))))
		if template_id.is_empty():
			continue
		var template := DataManager.get_part(template_id)
		var display_name := str(template.get("display_name", _humanize_id(template_id)))
		lines.append("%s x%s" % [display_name, str(count)] if count > 1 else display_name)
	return lines


static func _build_flag_reward_lines(reward_value: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not reward_value is Dictionary:
		return lines
	var flag_reward: Dictionary = reward_value
	var keys: Array = flag_reward.keys()
	keys.sort()
	for flag_key_value in keys:
		var flag_key := str(flag_key_value)
		var flag_value: Variant = flag_reward.get(flag_key_value, true)
		lines.append("%s: %s" % [_humanize_id(flag_key), str(flag_value)])
	return lines


static func _build_reputation_reward_lines(reward_value: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not reward_value is Dictionary:
		return lines
	var reputation_reward: Dictionary = reward_value
	var keys: Array = reputation_reward.keys()
	keys.sort()
	for faction_id_value in keys:
		var faction_id := str(faction_id_value)
		var amount_value: Variant = reputation_reward.get(faction_id_value, 0.0)
		if not (amount_value is int or amount_value is float):
			continue
		var faction := DataManager.get_faction(faction_id)
		var display_name := str(faction.get("display_name", _humanize_id(faction_id)))
		lines.append("%s Reputation %s" % [display_name, _format_signed_number(float(amount_value))])
	return lines


static func _format_signed_number(amount: float) -> String:
	var abs_amount := absf(amount)
	var number_text := str(int(abs_amount)) if is_equal_approx(abs_amount, float(int(abs_amount))) else "%.2f" % abs_amount
	return "+%s" % number_text if amount >= 0.0 else "-%s" % number_text


static func _humanize_id(value: String) -> String:
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
