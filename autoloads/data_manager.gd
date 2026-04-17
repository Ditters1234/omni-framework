## DataManager — Central template registry.
## Populated by ModLoader after both load phases complete.
## All runtime systems query here for JSON template data.
## Never holds runtime/instance state — templates only.
extends Node

class_name OmniDataManager

# ---------------------------------------------------------------------------
# Registry tables  (template_id → Dictionary)
# ---------------------------------------------------------------------------
var definitions: Dictionary = {}       # keyed by category, value = Array
var parts: Dictionary = {}             # id → part template
var entities: Dictionary = {}          # entity_id → entity template
var locations: Dictionary = {}         # location_id → location template
var factions: Dictionary = {}          # faction_id → faction template
var quests: Dictionary = {}            # quest_id → quest template
var tasks: Dictionary = {}             # template_id → task template
var achievements: Dictionary = {}      # achievement_id → achievement template
var config: Dictionary = {}            # deep-merged runtime config

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	clear_all()


# ---------------------------------------------------------------------------
# Phase 1 — Additions
# ---------------------------------------------------------------------------

## Called by ModLoader for each mod during phase 1.
## mod_data_path: absolute path to the mod's data/ directory.
func register_additions(mod_id: String, mod_data_path: String) -> void:
	var definitions_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_DEFINITIONS))
	if definitions_data is Dictionary:
		DefinitionLoader.load_additions(definitions_data)

	var parts_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_PARTS))
	if parts_data is Dictionary:
		PartsRegistry.load_additions(parts_data.get("parts", []))

	var entities_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_ENTITIES))
	if entities_data is Dictionary:
		EntityRegistry.load_additions(entities_data.get("entities", []))

	var locations_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_LOCATIONS))
	if locations_data is Dictionary:
		LocationGraph.load_additions(locations_data.get("locations", []))

	var factions_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_FACTIONS))
	if factions_data is Dictionary:
		FactionRegistry.load_additions(factions_data.get("factions", []))

	var quests_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_QUESTS))
	if quests_data is Dictionary:
		QuestRegistry.load_additions(quests_data.get("quests", []))

	var tasks_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_TASKS))
	if tasks_data is Dictionary:
		TaskRegistry.load_additions(tasks_data.get("task_templates", tasks_data.get("tasks", [])))

	var achievements_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_ACHIEVEMENTS))
	if achievements_data is Dictionary:
		AchievementRegistry.load_additions(achievements_data.get("achievements", []))

	var config_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_CONFIG))
	if config_data is Dictionary:
		ConfigLoader.load_additions(config_data)


# ---------------------------------------------------------------------------
# Phase 2 — Patches
# ---------------------------------------------------------------------------

## Called by ModLoader for each mod during phase 2.
## Applies JSON patch operations to existing template entries.
func apply_patches(mod_id: String, mod_data_path: String) -> void:
	var parts_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_PARTS))
	if parts_data is Dictionary:
		PartsRegistry.apply_patch(parts_data.get("patches", []))

	var entities_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_ENTITIES))
	if entities_data is Dictionary:
		EntityRegistry.apply_patch(entities_data.get("patches", []))

	var locations_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_LOCATIONS))
	if locations_data is Dictionary:
		LocationGraph.apply_patch(locations_data.get("patches", []))

	var factions_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_FACTIONS))
	if factions_data is Dictionary:
		FactionRegistry.apply_patch(factions_data.get("patches", []))

	var quests_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_QUESTS))
	if quests_data is Dictionary:
		QuestRegistry.apply_patch(quests_data.get("patches", []))

	var tasks_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_TASKS))
	if tasks_data is Dictionary:
		TaskRegistry.apply_patch(tasks_data.get("patches", []))

	var achievements_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_ACHIEVEMENTS))
	if achievements_data is Dictionary:
		AchievementRegistry.apply_patch(achievements_data.get("patches", []))

	var config_data = _load_json(mod_data_path.path_join(OmniConstants.DATA_CONFIG))
	if config_data is Dictionary and config_data.has("patches"):
		ConfigLoader.apply_patch(config_data.get("patches", {}))


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func get_part(part_id: String) -> Dictionary:
	return parts.get(part_id, {})


func get_entity(entity_id: String) -> Dictionary:
	return entities.get(entity_id, {})


func get_location(location_id: String) -> Dictionary:
	return locations.get(location_id, {})


func get_faction(faction_id: String) -> Dictionary:
	return factions.get(faction_id, {})


func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})


func get_task(template_id: String) -> Dictionary:
	return tasks.get(template_id, {})


func get_achievement(achievement_id: String) -> Dictionary:
	return achievements.get(achievement_id, {})


func get_definitions(category: String) -> Array:
	return definitions.get(category, [])


func get_config_value(key_path: String, default_value: Variant = null) -> Variant:
	var current: Variant = config
	for key_part in key_path.split("."):
		if current is Dictionary and current.has(key_part):
			current = current[key_part]
		else:
			return default_value
	return current


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Loads a JSON file and returns its parsed content, or null on failure.
func _load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var raw_text := FileAccess.get_file_as_string(file_path)
	return JSON.parse_string(raw_text)


## Deep-merges src into dst. Arrays are replaced, not appended.
func _deep_merge(dst: Dictionary, src: Dictionary) -> void:
	for key in src.keys():
		var src_value = src[key]
		if dst.has(key) and dst[key] is Dictionary and src_value is Dictionary:
			_deep_merge(dst[key], src_value)
		else:
			dst[key] = src_value


func clear_all() -> void:
	definitions = {
		"currencies": [],
		"stats": [],
	}
	parts.clear()
	entities.clear()
	locations.clear()
	factions.clear()
	quests.clear()
	tasks.clear()
	achievements.clear()
	config.clear()


func _apply_set_operations(entry: Dictionary, patch: Dictionary) -> void:
	var set_values: Dictionary = patch.get("set", {})
	for key in set_values.keys():
		entry[key] = set_values[key]


func _merge_dict_field(entry: Dictionary, field_name: String, values: Dictionary) -> void:
	if not entry.has(field_name) or not entry[field_name] is Dictionary:
		entry[field_name] = {}
	for key in values.keys():
		entry[field_name][key] = values[key]


func _append_array_field(entry: Dictionary, field_name: String, values: Array) -> void:
	if values.is_empty():
		return
	if not entry.has(field_name) or not entry[field_name] is Array:
		entry[field_name] = []
	for value in values:
		if not value in entry[field_name]:
			entry[field_name].append(value)


func _remove_array_values(entry: Dictionary, field_name: String, values: Array) -> void:
	if not entry.has(field_name) or not entry[field_name] is Array:
		return
	for value in values:
		entry[field_name].erase(value)


func _remove_objects_by_key(entry: Dictionary, field_name: String, key_name: String, ids: Array) -> void:
	if not entry.has(field_name) or not entry[field_name] is Array:
		return
	var filtered: Array = []
	for item in entry[field_name]:
		if item is Dictionary and str(item.get(key_name, "")) in ids:
			continue
		filtered.append(item)
	entry[field_name] = filtered


func _modify_objects_by_key(entry: Dictionary, field_name: String, key_name: String, modifications: Array) -> void:
	if not entry.has(field_name) or not entry[field_name] is Array:
		return
	for modification in modifications:
		if not modification is Dictionary:
			continue
		var target_id := str(modification.get(key_name, ""))
		if target_id.is_empty():
			continue
		for i in range(entry[field_name].size()):
			var item = entry[field_name][i]
			if item is Dictionary and str(item.get(key_name, "")) == target_id:
				var updated: Dictionary = item.duplicate(true)
				_apply_set_operations(updated, modification)
				entry[field_name][i] = updated
				break
