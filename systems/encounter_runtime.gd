extends RefCounted

class_name EncounterRuntime


static func build_condition_context(
	player: EntityInstance,
	opponent: EntityInstance,
	encounter_stats: Dictionary,
	player_tags: Dictionary = {},
	opponent_tags: Dictionary = {}
) -> Dictionary:
	return {
		"encounter_entities": {
			"player": player,
			"opponent": opponent,
		},
		"encounter_stats": encounter_stats,
		"encounter_tags": {
			"player": player_tags,
			"opponent": opponent_tags,
		},
	}


static func pick_weighted_action(actions: Array, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		if not is_action_available(action, context):
			continue
		var weight := resolve_weight(action, context)
		if weight <= 0.0:
			continue
		candidates.append(action)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll := rng.randf() * total_weight
	var running := 0.0
	for index in range(candidates.size()):
		running += weights[index]
		if roll <= running:
			return candidates[index].duplicate(true)
	return candidates[candidates.size() - 1].duplicate(true)


static func resolve_weight(action: Dictionary, context: Dictionary) -> float:
	var weight := _read_float(action.get("weight", 1.0), 1.0)
	var modifiers_value: Variant = action.get("weight_modifiers", [])
	if not modifiers_value is Array:
		return weight
	var modifiers: Array = modifiers_value
	for modifier_value in modifiers:
		if not modifier_value is Dictionary:
			continue
		var modifier: Dictionary = modifier_value
		var condition_value: Variant = modifier.get("if", {})
		if not condition_value is Dictionary:
			continue
		var condition: Dictionary = condition_value
		if ConditionEvaluator.evaluate(condition, context):
			return _read_float(modifier.get("weight", weight), weight)
	return weight


static func is_action_available(action: Dictionary, context: Dictionary) -> bool:
	var availability_value: Variant = action.get("availability", {})
	if availability_value == null:
		return true
	if not availability_value is Dictionary:
		return true
	var availability: Dictionary = availability_value
	if availability.is_empty():
		return true
	return ConditionEvaluator.evaluate(availability, context)


static func evaluate_action_check(action: Dictionary, context: Dictionary) -> bool:
	var check_value: Variant = action.get("check", {})
	if check_value == null:
		return true
	if not check_value is Dictionary:
		return true
	var check: Dictionary = check_value
	if check.is_empty():
		return true
	return ConditionEvaluator.evaluate(check, context)


static func compute_delta(effect: Dictionary, user: EntityInstance, target: EntityInstance) -> float:
	var delta := _read_float(effect.get("base_delta", effect.get("delta", 0.0)), 0.0)
	var modifiers_value: Variant = effect.get("stat_modifiers", {})
	if not modifiers_value is Dictionary:
		return delta
	var modifiers: Dictionary = modifiers_value
	for key_value in modifiers.keys():
		var key := str(key_value)
		var multiplier := _read_float(modifiers.get(key_value, 0.0), 0.0)
		var stat_value := _resolve_modifier_stat(key, user, target)
		delta += multiplier * stat_value
	return delta


static func clamp_encounter_stat(stat_id: String, value: float, stat_defs: Dictionary) -> float:
	var stat_def_value: Variant = stat_defs.get(stat_id, {})
	if not stat_def_value is Dictionary:
		return value
	var stat_def: Dictionary = stat_def_value
	if str(stat_def.get("kind", "meter")) == "counter":
		return value
	var minimum := _read_float(stat_def.get("min", 0.0), 0.0)
	var maximum := _read_float(stat_def.get("max", 100.0), 100.0)
	return clampf(value, minimum, maximum)


static func read_effects(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var effects: Array = value
	for effect_value in effects:
		if effect_value is Dictionary:
			var effect: Dictionary = effect_value
			result.append(effect.duplicate(true))
	return result


static func _resolve_modifier_stat(key: String, user: EntityInstance, target: EntityInstance) -> float:
	var parts := key.split(".", false, 1)
	if parts.size() != 2:
		return 0.0
	var source := str(parts[0])
	var stat_id := str(parts[1])
	var entity := user if source == "user" else target
	if entity == null:
		return 0.0
	return entity.effective_stat(stat_id)


static func _read_float(value: Variant, default_value: float) -> float:
	if value is int or value is float:
		return float(value)
	return default_value
