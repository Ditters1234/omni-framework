## DefinitionLoader — Loads definitions.json into DataManager.definitions.
## Definitions are categorized arrays (e.g. stat keys, slot types, currencies).
## They use no ID field — each category is an Array of strings or dicts.
extends RefCounted

class_name DefinitionLoader


## Parses definitions.json content and merges it into DataManager.definitions.
## Called by DataManager during phase 1 additions.
static func load_additions(data: Dictionary) -> void:
	if not DataManager.definitions.has("currencies"):
		DataManager.definitions["currencies"] = []
	if not DataManager.definitions.has("stats"):
		DataManager.definitions["stats"] = []

	for currency_id in data.get("currencies", []):
		var normalized_currency := str(currency_id)
		if normalized_currency.is_empty():
			continue
		if not normalized_currency in DataManager.definitions["currencies"]:
			DataManager.definitions["currencies"].append(normalized_currency)

	var raw_stats: Array = data.get("stats", [])
	var raw_stat_ids: Array[String] = []
	for raw_entry in raw_stats:
		if raw_entry is Dictionary:
			raw_stat_ids.append(str(raw_entry.get("id", "")))
		else:
			raw_stat_ids.append(str(raw_entry))

	for raw_entry in raw_stats:
		var stat_def := _normalize_stat_definition(raw_entry, raw_stat_ids)
		if stat_def.is_empty():
			continue
		var existing_index := _find_stat_index(str(stat_def.get("id", "")))
		if existing_index >= 0:
			DataManager.definitions["stats"][existing_index] = stat_def
		else:
			DataManager.definitions["stats"].append(stat_def)


## Applies patch operations to existing definition arrays.
## Called by DataManager during phase 2 patches.
static func apply_patch(patch: Dictionary) -> void:
	var category := str(patch.get("category", ""))
	if category.is_empty():
		return
	if not DataManager.definitions.has(category):
		DataManager.definitions[category] = []
	for value in patch.get("add", []):
		if not value in DataManager.definitions[category]:
			DataManager.definitions[category].append(value)
	for value in patch.get("remove", []):
		DataManager.definitions[category].erase(value)


## Returns all entries for a category, or empty array.
static func get_category(category: String) -> Array:
	return DataManager.definitions.get(category, [])


static func _find_stat_index(stat_id: String) -> int:
	for i in range(DataManager.definitions.get("stats", []).size()):
		var stat_def: Dictionary = DataManager.definitions["stats"][i]
		if str(stat_def.get("id", "")) == stat_id:
			return i
	return -1


static func _normalize_stat_definition(raw_entry: Variant, raw_stat_ids: Array[String]) -> Dictionary:
	var stat_def: Dictionary = {}
	if raw_entry is Dictionary:
		stat_def = raw_entry.duplicate(true)
	else:
		var stat_id := str(raw_entry)
		if stat_id.is_empty():
			return {}
		stat_def["id"] = stat_id

	var stat_id := str(stat_def.get("id", ""))
	if stat_id.is_empty():
		return {}

	if not stat_def.has("kind"):
		if stat_id.ends_with(OmniConstants.CAPACITY_SUFFIX):
			stat_def["kind"] = "capacity"
			stat_def["paired_base_id"] = stat_id.trim_suffix(OmniConstants.CAPACITY_SUFFIX)
		elif raw_stat_ids.has(stat_id + OmniConstants.CAPACITY_SUFFIX):
			stat_def["kind"] = "resource"
			stat_def["paired_capacity_id"] = stat_id + OmniConstants.CAPACITY_SUFFIX
		else:
			stat_def["kind"] = "flat"

	if stat_def["kind"] == "capacity" and not stat_def.has("paired_base_id"):
		stat_def["paired_base_id"] = stat_id.trim_suffix(OmniConstants.CAPACITY_SUFFIX)
	if stat_def["kind"] == "resource" and not stat_def.has("paired_capacity_id"):
		stat_def["paired_capacity_id"] = stat_id + OmniConstants.CAPACITY_SUFFIX
	if not stat_def.has("default_value"):
		stat_def["default_value"] = 0
	if (stat_def["kind"] == "resource" or stat_def["kind"] == "capacity") and not stat_def.has("clamp_min"):
		stat_def["clamp_min"] = 0
	return stat_def
