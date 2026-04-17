## RewardService -- Shared runtime helper for applying reward dictionaries.
## Keeps task, quest, and action reward handling consistent across systems.
extends RefCounted

class_name RewardService


static func apply_reward(entity: EntityInstance, reward_data: Variant) -> void:
	if entity == null or not reward_data is Dictionary:
		return
	var reward: Dictionary = reward_data
	for reward_key_value in reward.keys():
		var reward_key := str(reward_key_value)
		var reward_value: Variant = reward.get(reward_key_value, null)
		match reward_key:
			"reputation":
				_apply_reputation_reward(entity, reward_value)
			"items":
				_apply_item_reward(entity, reward_value)
			"flags":
				_apply_flag_reward(entity, reward_value)
			_:
				entity.add_currency(reward_key, float(reward_value))


static func _apply_reputation_reward(entity: EntityInstance, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reputation_reward: Dictionary = reward_value
	for faction_id_value in reputation_reward.keys():
		var faction_id := str(faction_id_value)
		var amount := float(reputation_reward.get(faction_id_value, 0.0))
		entity.add_reputation(faction_id, amount)


static func _apply_item_reward(entity: EntityInstance, reward_value: Variant) -> void:
	if not reward_value is Array:
		return
	var item_list: Array = reward_value
	for item_entry in item_list:
		if item_entry is String:
			_grant_template(entity, str(item_entry), 1)
			continue
		if not item_entry is Dictionary:
			continue
		var item_dict: Dictionary = item_entry
		var template_id := str(item_dict.get("template_id", item_dict.get("part_id", "")))
		var count := int(item_dict.get("count", item_dict.get("quantity", 1)))
		_grant_template(entity, template_id, count)


static func _apply_flag_reward(entity: EntityInstance, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var flag_reward: Dictionary = reward_value
	for flag_key_value in flag_reward.keys():
		var flag_key := str(flag_key_value)
		entity.set_flag(flag_key, flag_reward.get(flag_key_value, true))


static func _grant_template(entity: EntityInstance, template_id: String, count: int) -> void:
	if entity == null or template_id.is_empty() or count <= 0:
		return
	var template := DataManager.get_part(template_id)
	if template.is_empty():
		return
	for _i in range(count):
		var part := PartInstance.from_template(template)
		entity.add_part(part)
		GameEvents.part_acquired.emit(entity.entity_id, part.template_id)
