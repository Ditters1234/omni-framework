## WeightedChoiceService -- Shared condition filtering and weighted selection.
## Used by activity outcomes and any future data-authored weighted lists.
extends RefCounted

class_name WeightedChoiceService


static func filter_available(entries: Array, context: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var conditions := _array_value(entry.get("conditions", []))
		if not _conditions_pass_all(conditions, context):
			continue
		result.append(entry.duplicate(true))
	return result


static func pick_weighted(entries: Array, context: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	var available := filter_available(entries, context)
	if available.is_empty():
		return {}

	var weights: Array[float] = []
	var total_weight := 0.0
	for entry in available:
		var weight := resolve_weight(entry, context)
		weights.append(weight)
		if weight > 0.0:
			total_weight += weight

	if total_weight <= 0.0:
		return available[0].duplicate(true)

	var resolved_rng := rng
	if resolved_rng == null:
		resolved_rng = RandomNumberGenerator.new()
		resolved_rng.randomize()

	var roll := resolved_rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for index in range(available.size()):
		var weight := weights[index]
		if weight <= 0.0:
			continue
		accumulated += weight
		if roll <= accumulated:
			return available[index].duplicate(true)

	return available[available.size() - 1].duplicate(true)


static func resolve_weight(entry: Dictionary, _context: Dictionary = {}) -> float:
	var weight_value: Variant = entry.get("weight", 1.0)
	if weight_value is int or weight_value is float:
		return maxf(float(weight_value), 0.0)
	if weight_value is String and str(weight_value).is_valid_float():
		return maxf(float(str(weight_value)), 0.0)
	return 1.0


static func _conditions_pass_all(conditions: Array, context: Dictionary = {}) -> bool:
	for condition_value in conditions:
		if not condition_value is Dictionary:
			return false
		var condition: Dictionary = condition_value
		if not ConditionEvaluator.evaluate(condition, context):
			return false
	return true


static func _array_value(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value
	return []
