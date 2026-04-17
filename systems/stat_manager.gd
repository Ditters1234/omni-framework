## StatManager — Helpers for applying and querying stats on EntityInstances.
## Handles capacity clamping, part modifier stacking, and stat validation.
## Does not hold state — operates on EntityInstance objects passed in.
extends RefCounted

class_name StatManager


## Applies all equipped part `stats` modifiers to an entity's base stats.
## Returns a Dictionary of { stat_key → effective_value }.
static func compute_effective_stats(entity: EntityInstance) -> Dictionary:
	var result: Dictionary = entity.stats.duplicate()
	for slot in entity.equipped:
		var part: PartInstance = entity.equipped[slot]
		if not part:
			continue
		var template := part.get_template()
		var mods: Dictionary = template.get("stats", template.get("stat_modifiers", {}))
		for key in mods:
			result[key] = result.get(key, 0.0) + float(mods[key])
	# Clamp all base stats to their capacity
	for key in result.keys():
		if key.ends_with(OmniConstants.CAPACITY_SUFFIX):
			continue
		var cap_key: String = str(key) + OmniConstants.CAPACITY_SUFFIX
		if result.has(cap_key):
			result[key] = clamp(result[key], OmniConstants.STAT_MIN, result[cap_key])
	return result


## Clamps all base stats in an entity to their current capacity stats.
## Should be called whenever a capacity stat changes.
static func clamp_all_to_capacity(entity: EntityInstance) -> void:
	for key in entity.stats.keys():
		if key.ends_with(OmniConstants.CAPACITY_SUFFIX):
			continue
		var cap_key: String = str(key) + OmniConstants.CAPACITY_SUFFIX
		if entity.stats.has(cap_key):
			entity.stats[key] = clamp(
				entity.stats[key],
				OmniConstants.STAT_MIN,
				entity.stats[cap_key]
			)


## Validates that a stat key follows the naming convention.
## Returns true if it's a valid stat key string.
static func is_valid_stat_key(stat_key: String) -> bool:
	return stat_key.length() > 0 and not stat_key.contains(" ")


## Returns the capacity stat key for a given base stat key.
## e.g. "health" → "health_max"
static func capacity_key_for(stat_key: String) -> String:
	return stat_key + OmniConstants.CAPACITY_SUFFIX


## Returns true if the given key is a capacity stat (ends with _max).
static func is_capacity_stat(stat_key: String) -> bool:
	return stat_key.ends_with(OmniConstants.CAPACITY_SUFFIX)
