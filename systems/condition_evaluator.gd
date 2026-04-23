## ConditionEvaluator — Evaluates JSON condition blocks against game state.
## Used by quests, tasks, challenges, and shop unlock requirements.
##
## Condition block format (all fields optional, ANDed together):
## {
##   "stat_check": { "stat": "strength", "op": ">=", "value": 10 },
##   "has_flag": "completed_tutorial",
##   "has_part": "base:lockpick",
##   "has_currency": { "key": "gold", "amount": 50 },
##   "quest_complete": "base:the_first_hunt",
##   "location": "base:town_square"
## }
extends RefCounted

class_name ConditionEvaluator


## Evaluates a condition dictionary against the current GameState.
## Returns true only if ALL conditions in the block are satisfied.
static func evaluate(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if not _evaluate_logic_block(conditions):
		return false
	if conditions.has("type"):
		return _evaluate_typed_condition(conditions)
	return _evaluate_legacy_condition(conditions)


## Evaluates an array of condition blocks (OR logic — any one passing = true).
static func evaluate_any(condition_list: Array) -> bool:
	for cond in condition_list:
		if cond is Dictionary and evaluate(cond):
			return true
	return false


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _check_stat(stat_check: Dictionary) -> bool:
	var entity := _resolve_entity(str(stat_check.get("entity_id", "player")))
	if entity == null:
		return false
	var stat_key := str(stat_check.get("stat", ""))
	var op := str(stat_check.get("op", ">="))
	var required := float(stat_check.get("value", 0))
	var actual := entity.effective_stat(stat_key)
	match op:
		">=": return actual >= required
		">":  return actual > required
		"<=": return actual <= required
		"<":  return actual < required
		"==": return actual == required
		"!=": return actual != required
	return false


static func _check_flag(flag_check: Variant) -> bool:
	if flag_check is String:
		return GameState.has_flag(str(flag_check))
	if not flag_check is Dictionary:
		return false
	var flag_dict: Dictionary = flag_check
	var entity_id := str(flag_dict.get("entity_id", "global"))
	var flag_id := str(flag_dict.get("flag_id", flag_dict.get("key", "")))
	var expected: Variant = flag_dict.get("value", true)
	if entity_id == "global":
		return _flag_values_match(GameState.get_flag(flag_id), expected)
	var entity := _resolve_entity(entity_id)
	if entity == null:
		return false
	return _flag_values_match(entity.get_flag(flag_id, null), expected)


## Compares flag values with type coercion so that bool true/false matches
## int 1/0 and vice-versa.  All other types use strict equality.
static func _flag_values_match(actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	# Coerce bool <-> int: true==1, false==0
	if (actual is bool or actual is int or actual is float) and (expected is bool or expected is int or expected is float):
		return float(actual) == float(expected)
	return false


static func _check_has_part(part_check: Variant) -> bool:
	if part_check is String:
		return _check_has_part({
			"entity_id": "player",
			"template_id": str(part_check),
			"count": 1,
		})
	if not part_check is Dictionary:
		return false
	var part_dict: Dictionary = part_check
	var entity := _resolve_entity(str(part_dict.get("entity_id", "player")))
	if entity == null:
		return false
	var template_id := str(part_dict.get("template_id", part_dict.get("part_id", "")))
	var required_count := int(part_dict.get("count", 1))
	if template_id.is_empty() or required_count <= 0:
		return false
	var match_count := 0
	for part in _collect_entity_parts(entity):
		if part.template_id != template_id:
			continue
		match_count += 1
		if match_count >= required_count:
			return true
	return false


static func _check_currency(currency_check: Dictionary) -> bool:
	var entity := _resolve_entity(str(currency_check.get("entity_id", "player")))
	if entity == null:
		return false
	var key := str(currency_check.get("currency_id", currency_check.get("key", "")))
	var amount := float(currency_check.get("amount", 0))
	return entity.get_currency(key) >= amount


static func _check_has_item_tag(item_check: Variant) -> bool:
	if not item_check is Dictionary:
		return false
	var item_dict: Dictionary = item_check
	var entity := _resolve_entity(str(item_dict.get("entity_id", "player")))
	if entity == null:
		return false
	var tag := str(item_dict.get("tag", ""))
	var required_count := int(item_dict.get("count", 1))
	if tag.is_empty() or required_count <= 0:
		return false
	var match_count := 0
	for part in _collect_entity_parts(entity):
		var template := part.get_template()
		var tags_data: Variant = template.get("tags", [])
		if not tags_data is Array:
			continue
		var tags: Array = tags_data
		if tag in tags:
			match_count += 1
			if match_count >= required_count:
				return true
	return false


static func _check_stat_comparison(stat_check: Dictionary, fallback_op: String) -> bool:
	var stat_dict: Dictionary = stat_check.duplicate(true)
	if not stat_dict.has("op"):
		stat_dict["op"] = fallback_op
	return _check_stat(stat_dict)


static func _check_reputation(reputation_check: Variant) -> bool:
	if not reputation_check is Dictionary:
		return false
	var reputation_dict: Dictionary = reputation_check
	var entity := _resolve_entity(str(reputation_dict.get("entity_id", "player")))
	if entity == null:
		return false
	var faction_id := str(reputation_dict.get("faction_id", ""))
	var threshold := float(reputation_dict.get("threshold", 0.0))
	var comparison := str(reputation_dict.get("comparison", ">="))
	var actual := entity.get_reputation(faction_id)
	match comparison:
		">=": return actual >= threshold
		">": return actual > threshold
		"<=": return actual <= threshold
		"<": return actual < threshold
		"==": return actual == threshold
		"!=": return actual != threshold
	return false


static func _evaluate_logic_block(conditions: Dictionary) -> bool:
	if conditions.has("AND"):
		var and_conditions_data: Variant = conditions.get("AND", [])
		if not and_conditions_data is Array:
			return false
		var and_conditions: Array = and_conditions_data
		# An empty AND list is vacuously satisfied (no constraints); skip it.
		for child in and_conditions:
			if not _evaluate_node(child):
				return false
	if conditions.has("OR"):
		var or_conditions_data: Variant = conditions.get("OR", [])
		if not or_conditions_data is Array:
			return false
		var or_conditions: Array = or_conditions_data
		# An empty OR list is vacuously satisfied (no constraints); skip it.
		if not or_conditions.is_empty():
			var any_passed := false
			for child in or_conditions:
				if _evaluate_node(child):
					any_passed = true
					break
			if not any_passed:
				return false
	if conditions.has("NOT"):
		var not_condition: Variant = conditions.get("NOT", null)
		if _evaluate_node(not_condition):
			return false
	return true


static func _evaluate_node(condition_node: Variant) -> bool:
	if not condition_node is Dictionary:
		return false
	var condition_dict: Dictionary = condition_node
	return evaluate(condition_dict)


static func _evaluate_typed_condition(condition: Dictionary) -> bool:
	var condition_type := str(condition.get("type", ""))
	match condition_type:
		"has_flag":
			return _check_typed_has_flag(condition)
		"stat_check":
			return _check_stat(condition)
		"stat_greater_than":
			return _check_stat_comparison(condition, ">")
		"stat_less_than":
			return _check_stat_comparison(condition, "<")
		"has_item_tag":
			return _check_has_item_tag(condition)
		"has_currency":
			return _check_currency(condition)
		"reputation_threshold":
			return _check_reputation(condition)
		"quest_complete":
			return _check_quest_complete(condition)
		"reach_location":
			return _check_location(condition)
		"has_part":
			return _check_has_part(condition)
		_:
			push_warning("ConditionEvaluator: unknown condition type '%s'" % condition_type)
			return false


## Extracts the flag payload from a typed condition dict so _check_flag
## receives the same shape it gets from the legacy path (a string or sub-dict),
## not the entire typed condition wrapper.
static func _check_typed_has_flag(condition: Dictionary) -> bool:
	if condition.has("entity_id") or condition.has("value"):
		var flag_payload := {
			"entity_id": condition.get("entity_id", "global"),
			"flag_id": str(condition.get("flag_id", condition.get("key", ""))),
			"value": condition.get("value", true),
		}
		return _check_flag(flag_payload)
	return _check_flag(str(condition.get("flag_id", condition.get("key", ""))))


static func _evaluate_legacy_condition(conditions: Dictionary) -> bool:
	var stat_check_data: Variant = conditions.get("stat_check", null)
	if stat_check_data is Dictionary and not _check_stat(stat_check_data):
		return false
	var has_flag_data: Variant = conditions.get("has_flag", null)
	if has_flag_data != null and not _check_flag(has_flag_data):
		return false
	var has_part_data: Variant = conditions.get("has_part", null)
	if has_part_data != null and not _check_has_part(has_part_data):
		return false
	var has_item_tag_data: Variant = conditions.get("has_item_tag", null)
	if has_item_tag_data != null and not _check_has_item_tag(has_item_tag_data):
		return false
	var has_currency_data: Variant = conditions.get("has_currency", null)
	if has_currency_data is Dictionary and not _check_currency(has_currency_data):
		return false
	var stat_gt_data: Variant = conditions.get("stat_greater_than", null)
	if stat_gt_data is Dictionary and not _check_stat_comparison(stat_gt_data, ">"):
		return false
	var stat_lt_data: Variant = conditions.get("stat_less_than", null)
	if stat_lt_data is Dictionary and not _check_stat_comparison(stat_lt_data, "<"):
		return false
	var reputation_data: Variant = conditions.get("reputation_threshold", null)
	if reputation_data != null and not _check_reputation(reputation_data):
		return false
	var quest_complete_data: Variant = conditions.get("quest_complete", null)
	if quest_complete_data != null and not _check_quest_complete(quest_complete_data):
		return false
	if conditions.has("location") and not _check_location({"location_id": conditions.get("location", "")}):
		return false
	return true


static func _check_quest_complete(quest_check: Variant) -> bool:
	if quest_check is String:
		return str(quest_check) in GameState.completed_quests
	if not quest_check is Dictionary:
		return false
	var quest_dict: Dictionary = quest_check
	return str(quest_dict.get("quest_id", "")) in GameState.completed_quests


static func _check_location(location_check: Variant) -> bool:
	if location_check is String:
		return GameState.current_location_id == str(location_check)
	if not location_check is Dictionary:
		return false
	var location_dict: Dictionary = location_check
	var entity := _resolve_entity(str(location_dict.get("entity_id", "player")))
	if entity == null:
		return false
	var location_id := str(location_dict.get("location_id", location_dict.get("location", "")))
	return entity.location_id == location_id


static func _collect_entity_parts(entity: EntityInstance) -> Array[PartInstance]:
	var parts: Array[PartInstance] = []
	if entity == null:
		return parts
	for part_data in entity.inventory:
		var inventory_part := part_data as PartInstance
		if inventory_part != null:
			parts.append(inventory_part)
	for part_data in entity.equipped.values():
		var equipped_part := part_data as PartInstance
		if equipped_part != null and not equipped_part in parts:
			parts.append(equipped_part)
	return parts


static func _resolve_entity(entity_id: String) -> EntityInstance:
	if entity_id.is_empty() or entity_id == "player":
		return GameState.player as EntityInstance
	return GameState.get_entity_instance(entity_id)
