## DataManager — Central template registry.
## Populated by ModLoader after both load phases complete.
## All runtime systems query here for JSON template data.
## Never holds runtime/instance state — templates only.
extends Node

class_name OmniDataManager

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")
const LOAD_PHASE_IDLE := "idle"
const LOAD_PHASE_ADDITIONS := "additions"
const LOAD_PHASE_PATCHES := "patches"
const LOAD_PHASE_VALIDATION := "validation"
const LOAD_PHASE_READY := "ready"
const LOAD_PHASE_FAILED := "failed"
const FILE_STATUS_LOADED := "loaded"
const FILE_STATUS_MISSING := "missing"
const FILE_STATUS_INVALID := "invalid"
const MAX_DEBUG_ENTRIES := 10

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
var is_loaded: bool = false
var load_phase: String = LOAD_PHASE_IDLE
var _load_started_at: String = ""
var _load_finished_at: String = ""
var _load_issues: Array[Dictionary] = []
var _processed_files: Array[Dictionary] = []

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
func register_additions(mod_id: String, mod_data_path: String) -> Array[Dictionary]:
	_begin_load_phase(LOAD_PHASE_ADDITIONS)
	var issue_start := _load_issues.size()

	var definitions_path := mod_data_path.path_join(OmniConstants.DATA_DEFINITIONS)
	var definitions_data_value: Variant = _load_json_document(mod_id, definitions_path, LOAD_PHASE_ADDITIONS)
	if definitions_data_value is Dictionary:
		var definitions_data: Dictionary = definitions_data_value
		DefinitionLoader.load_additions(definitions_data)

	var parts_path := mod_data_path.path_join(OmniConstants.DATA_PARTS)
	var parts_data_value: Variant = _load_json_document(mod_id, parts_path, LOAD_PHASE_ADDITIONS)
	if parts_data_value is Dictionary:
		var parts_data: Dictionary = parts_data_value
		var part_entries: Array = _get_array_field(parts_data, "parts", mod_id, parts_path, LOAD_PHASE_ADDITIONS)
		part_entries = _filter_valid_additions(part_entries, parts, "parts", "id", ["id", "display_name", "description", "tags"], mod_id, parts_path, LOAD_PHASE_ADDITIONS)
		PartsRegistry.load_additions(part_entries)

	var entities_path := mod_data_path.path_join(OmniConstants.DATA_ENTITIES)
	var entities_data_value: Variant = _load_json_document(mod_id, entities_path, LOAD_PHASE_ADDITIONS)
	if entities_data_value is Dictionary:
		var entities_data: Dictionary = entities_data_value
		var entity_entries: Array = _get_array_field(entities_data, "entities", mod_id, entities_path, LOAD_PHASE_ADDITIONS)
		entity_entries = _filter_valid_additions(entity_entries, entities, "entities", "entity_id", ["entity_id", "display_name"], mod_id, entities_path, LOAD_PHASE_ADDITIONS)
		EntityRegistry.load_additions(entity_entries)

	var locations_path := mod_data_path.path_join(OmniConstants.DATA_LOCATIONS)
	var locations_data_value: Variant = _load_json_document(mod_id, locations_path, LOAD_PHASE_ADDITIONS)
	if locations_data_value is Dictionary:
		var locations_data: Dictionary = locations_data_value
		var location_entries: Array = _get_array_field(locations_data, "locations", mod_id, locations_path, LOAD_PHASE_ADDITIONS)
		location_entries = _filter_valid_additions(location_entries, locations, "locations", "location_id", ["location_id", "display_name"], mod_id, locations_path, LOAD_PHASE_ADDITIONS)
		LocationGraph.load_additions(location_entries)

	var factions_path := mod_data_path.path_join(OmniConstants.DATA_FACTIONS)
	var factions_data_value: Variant = _load_json_document(mod_id, factions_path, LOAD_PHASE_ADDITIONS)
	if factions_data_value is Dictionary:
		var factions_data: Dictionary = factions_data_value
		var faction_entries: Array = _get_array_field(factions_data, "factions", mod_id, factions_path, LOAD_PHASE_ADDITIONS)
		faction_entries = _filter_valid_additions(faction_entries, factions, "factions", "faction_id", ["faction_id", "display_name"], mod_id, factions_path, LOAD_PHASE_ADDITIONS)
		FactionRegistry.load_additions(faction_entries)

	var quests_path := mod_data_path.path_join(OmniConstants.DATA_QUESTS)
	var quests_data_value: Variant = _load_json_document(mod_id, quests_path, LOAD_PHASE_ADDITIONS)
	if quests_data_value is Dictionary:
		var quests_data: Dictionary = quests_data_value
		var quest_entries: Array = _get_array_field(quests_data, "quests", mod_id, quests_path, LOAD_PHASE_ADDITIONS)
		quest_entries = _filter_valid_additions(quest_entries, quests, "quests", "quest_id", ["quest_id", "display_name", "stages"], mod_id, quests_path, LOAD_PHASE_ADDITIONS)
		QuestRegistry.load_additions(quest_entries)

	var tasks_path := mod_data_path.path_join(OmniConstants.DATA_TASKS)
	var tasks_data_value: Variant = _load_json_document(mod_id, tasks_path, LOAD_PHASE_ADDITIONS)
	if tasks_data_value is Dictionary:
		var tasks_data: Dictionary = tasks_data_value
		var task_entries: Array = []
		if tasks_data.has("task_templates"):
			task_entries = _get_array_field(tasks_data, "task_templates", mod_id, tasks_path, LOAD_PHASE_ADDITIONS)
		else:
			task_entries = _get_array_field(tasks_data, "tasks", mod_id, tasks_path, LOAD_PHASE_ADDITIONS)
		task_entries = _filter_valid_additions(task_entries, tasks, "tasks", "template_id", ["template_id", "type"], mod_id, tasks_path, LOAD_PHASE_ADDITIONS)
		TaskRegistry.load_additions(task_entries)

	var achievements_path := mod_data_path.path_join(OmniConstants.DATA_ACHIEVEMENTS)
	var achievements_data_value: Variant = _load_json_document(mod_id, achievements_path, LOAD_PHASE_ADDITIONS)
	if achievements_data_value is Dictionary:
		var achievements_data: Dictionary = achievements_data_value
		var achievement_entries: Array = _get_array_field(achievements_data, "achievements", mod_id, achievements_path, LOAD_PHASE_ADDITIONS)
		achievement_entries = _filter_valid_additions(achievement_entries, achievements, "achievements", "achievement_id", ["achievement_id", "display_name", "stat_name", "requirement"], mod_id, achievements_path, LOAD_PHASE_ADDITIONS)
		AchievementRegistry.load_additions(achievement_entries)

	var config_path := mod_data_path.path_join(OmniConstants.DATA_CONFIG)
	var config_data_value: Variant = _load_json_document(mod_id, config_path, LOAD_PHASE_ADDITIONS)
	if config_data_value is Dictionary:
		var config_data: Dictionary = config_data_value
		ConfigLoader.load_additions(config_data)

	return get_load_issues(_load_issues.size() - issue_start)


# ---------------------------------------------------------------------------
# Phase 2 — Patches
# ---------------------------------------------------------------------------

## Called by ModLoader for each mod during phase 2.
## Applies JSON patch operations to existing template entries.
func apply_patches(mod_id: String, mod_data_path: String) -> Array[Dictionary]:
	_begin_load_phase(LOAD_PHASE_PATCHES)
	var issue_start := _load_issues.size()

	var definitions_path := mod_data_path.path_join(OmniConstants.DATA_DEFINITIONS)
	var definitions_data_value: Variant = _load_json_document(mod_id, definitions_path, LOAD_PHASE_PATCHES)
	if definitions_data_value is Dictionary:
		var definitions_data: Dictionary = definitions_data_value
		var definition_patches: Array = _get_array_field(definitions_data, "patches", mod_id, definitions_path, LOAD_PHASE_PATCHES)
		_validate_definition_patches(definition_patches, mod_id, definitions_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(definition_patches, ["category", "add", "remove"], "definitions", mod_id, definitions_path, LOAD_PHASE_PATCHES)
		for patch_value in definition_patches:
			if not patch_value is Dictionary:
				continue
			var patch_entry: Dictionary = patch_value
			DefinitionLoader.apply_patch(patch_entry)

	var parts_path := mod_data_path.path_join(OmniConstants.DATA_PARTS)
	var parts_data_value: Variant = _load_json_document(mod_id, parts_path, LOAD_PHASE_PATCHES)
	if parts_data_value is Dictionary:
		var parts_data: Dictionary = parts_data_value
		var part_patches: Array = _get_array_field(parts_data, "patches", mod_id, parts_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(part_patches, parts, "parts", mod_id, parts_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(part_patches, ["target", "set", "set_stats", "add_tags", "remove_tags", "remove_socket_ids"], "parts", mod_id, parts_path, LOAD_PHASE_PATCHES)
		PartsRegistry.apply_patch(part_patches)

	var entities_path := mod_data_path.path_join(OmniConstants.DATA_ENTITIES)
	var entities_data_value: Variant = _load_json_document(mod_id, entities_path, LOAD_PHASE_PATCHES)
	if entities_data_value is Dictionary:
		var entities_data: Dictionary = entities_data_value
		var entity_patches: Array = _get_array_field(entities_data, "patches", mod_id, entities_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(entity_patches, entities, "entities", mod_id, entities_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(entity_patches, ["target", "set", "set_currencies", "add_sockets", "remove_socket_ids"], "entities", mod_id, entities_path, LOAD_PHASE_PATCHES)
		EntityRegistry.apply_patch(entity_patches)

	var locations_path := mod_data_path.path_join(OmniConstants.DATA_LOCATIONS)
	var locations_data_value: Variant = _load_json_document(mod_id, locations_path, LOAD_PHASE_PATCHES)
	if locations_data_value is Dictionary:
		var locations_data: Dictionary = locations_data_value
		var location_patches: Array = _get_array_field(locations_data, "patches", mod_id, locations_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(location_patches, locations, "locations", mod_id, locations_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(location_patches, ["target", "set", "add_connections", "remove_connections", "add_screens", "remove_screens", "modify_screen"], "locations", mod_id, locations_path, LOAD_PHASE_PATCHES)
		LocationGraph.apply_patch(location_patches)

	var factions_path := mod_data_path.path_join(OmniConstants.DATA_FACTIONS)
	var factions_data_value: Variant = _load_json_document(mod_id, factions_path, LOAD_PHASE_PATCHES)
	if factions_data_value is Dictionary:
		var factions_data: Dictionary = factions_data_value
		var faction_patches: Array = _get_array_field(factions_data, "patches", mod_id, factions_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(faction_patches, factions, "factions", mod_id, factions_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(faction_patches, ["target", "set"], "factions", mod_id, factions_path, LOAD_PHASE_PATCHES)
		FactionRegistry.apply_patch(faction_patches)

	var quests_path := mod_data_path.path_join(OmniConstants.DATA_QUESTS)
	var quests_data_value: Variant = _load_json_document(mod_id, quests_path, LOAD_PHASE_PATCHES)
	if quests_data_value is Dictionary:
		var quests_data: Dictionary = quests_data_value
		var quest_patches: Array = _get_array_field(quests_data, "patches", mod_id, quests_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(quest_patches, quests, "quests", mod_id, quests_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(quest_patches, ["target", "set", "add_stages"], "quests", mod_id, quests_path, LOAD_PHASE_PATCHES)
		QuestRegistry.apply_patch(quest_patches)

	var tasks_path := mod_data_path.path_join(OmniConstants.DATA_TASKS)
	var tasks_data_value: Variant = _load_json_document(mod_id, tasks_path, LOAD_PHASE_PATCHES)
	if tasks_data_value is Dictionary:
		var tasks_data: Dictionary = tasks_data_value
		var task_patches: Array = _get_array_field(tasks_data, "patches", mod_id, tasks_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(task_patches, tasks, "tasks", mod_id, tasks_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(task_patches, ["target", "set", "set_reward"], "tasks", mod_id, tasks_path, LOAD_PHASE_PATCHES)
		TaskRegistry.apply_patch(task_patches)

	var achievements_path := mod_data_path.path_join(OmniConstants.DATA_ACHIEVEMENTS)
	var achievements_data_value: Variant = _load_json_document(mod_id, achievements_path, LOAD_PHASE_PATCHES)
	if achievements_data_value is Dictionary:
		var achievements_data: Dictionary = achievements_data_value
		var achievement_patches: Array = _get_array_field(achievements_data, "patches", mod_id, achievements_path, LOAD_PHASE_PATCHES)
		_validate_patch_targets(achievement_patches, achievements, "achievements", mod_id, achievements_path, LOAD_PHASE_PATCHES)
		_validate_patch_operations(achievement_patches, ["target", "set"], "achievements", mod_id, achievements_path, LOAD_PHASE_PATCHES)
		AchievementRegistry.apply_patch(achievement_patches)

	var config_path := mod_data_path.path_join(OmniConstants.DATA_CONFIG)
	var config_data_value: Variant = _load_json_document(mod_id, config_path, LOAD_PHASE_PATCHES)
	if config_data_value is Dictionary:
		var config_data: Dictionary = config_data_value
		var config_patch: Dictionary = _get_dictionary_field(config_data, "patches", mod_id, config_path, LOAD_PHASE_PATCHES)
		ConfigLoader.apply_patch(config_patch)

	return get_load_issues(_load_issues.size() - issue_start)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func get_part(part_id: String) -> Dictionary:
	return _duplicate_dictionary(parts.get(part_id, {}))


func get_entity(entity_id: String) -> Dictionary:
	return _duplicate_dictionary(entities.get(entity_id, {}))


func get_location(location_id: String) -> Dictionary:
	return _duplicate_dictionary(locations.get(location_id, {}))


func get_faction(faction_id: String) -> Dictionary:
	return _duplicate_dictionary(factions.get(faction_id, {}))


func get_quest(quest_id: String) -> Dictionary:
	return _duplicate_dictionary(quests.get(quest_id, {}))


func get_task(template_id: String) -> Dictionary:
	return _duplicate_dictionary(tasks.get(template_id, {}))


func get_achievement(achievement_id: String) -> Dictionary:
	return _duplicate_dictionary(achievements.get(achievement_id, {}))


func get_definitions(category: String) -> Array:
	return _duplicate_array(definitions.get(category, []))


func has_part(part_id: String) -> bool:
	return parts.has(part_id)


func has_entity(entity_id: String) -> bool:
	return entities.has(entity_id)


func has_location(location_id: String) -> bool:
	return locations.has(location_id)


func has_faction(faction_id: String) -> bool:
	return factions.has(faction_id)


func has_quest(quest_id: String) -> bool:
	return quests.has(quest_id)


func has_task(template_id: String) -> bool:
	return tasks.has(template_id)


func has_achievement(achievement_id: String) -> bool:
	return achievements.has(achievement_id)


func query_parts(filters: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var tag_filters := _variant_to_string_array(filters.get("tags", []))
	var required_tag_filters := _variant_to_string_array(filters.get("required_tags", []))
	var template_ids := _variant_to_string_array(filters.get("template_ids", []))
	for part_id_value in parts.keys():
		var part_id := str(part_id_value)
		if not template_ids.is_empty() and not template_ids.has(part_id):
			continue
		var part_value: Variant = parts.get(part_id_value, {})
		if not part_value is Dictionary:
			continue
		var part: Dictionary = part_value
		var part_tags := _variant_to_string_array(part.get("tags", []))
		var part_required_tags := _variant_to_string_array(part.get("required_tags", []))
		if not _contains_all_strings(part_tags, tag_filters):
			continue
		if not _contains_all_strings(part_required_tags, required_tag_filters):
			continue
		results.append(part.duplicate(true))
	return results


func query_entities(filters: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var location_id := str(filters.get("location_id", ""))
	var template_ids := _variant_to_string_array(filters.get("template_ids", []))
	for entity_id_value in entities.keys():
		var entity_id := str(entity_id_value)
		if not template_ids.is_empty() and not template_ids.has(entity_id):
			continue
		var entity_value: Variant = entities.get(entity_id_value, {})
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		if not location_id.is_empty() and str(entity.get("location_id", "")) != location_id:
			continue
		results.append(entity.duplicate(true))
	return results


func query_locations(filters: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var template_ids := _variant_to_string_array(filters.get("template_ids", []))
	var connected_to := str(filters.get("connected_to", ""))
	var backend_class := str(filters.get("backend_class", ""))
	var ui_group := str(filters.get("ui_group", ""))
	for location_id_value in locations.keys():
		var location_id := str(location_id_value)
		if not template_ids.is_empty() and not template_ids.has(location_id):
			continue
		var location_value: Variant = locations.get(location_id_value, {})
		if not location_value is Dictionary:
			continue
		var location: Dictionary = location_value
		if not connected_to.is_empty() and not _location_has_connection(location, connected_to):
			continue
		if not backend_class.is_empty() and not _location_has_screen_value(location, "backend_class", backend_class):
			continue
		if not ui_group.is_empty() and not _location_has_screen_value(location, "ui_group", ui_group):
			continue
		results.append(location.duplicate(true))
	return results


func get_registry_counts() -> Dictionary:
	return {
		"stats": get_definitions("stats").size(),
		"currencies": get_definitions("currencies").size(),
		"parts": parts.size(),
		"entities": entities.size(),
		"locations": locations.size(),
		"factions": factions.size(),
		"quests": quests.size(),
		"tasks": tasks.size(),
		"achievements": achievements.size(),
	}


func get_config_value(key_path: String, default_value: Variant = null) -> Variant:
	var current: Variant = config
	for key_part in key_path.split("."):
		if current is Dictionary and current.has(key_part):
			current = current[key_part]
		else:
			return default_value
	return current


func get_load_issues(limit: int = 0) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for issue in _load_issues:
		issues.append(issue.duplicate(true))
	if limit > 0 and issues.size() > limit:
		return issues.slice(issues.size() - limit, issues.size())
	return issues


func validate_loaded_content() -> Array[Dictionary]:
	_begin_load_phase(LOAD_PHASE_VALIDATION)
	var issue_start := _load_issues.size()
	_validate_definition_schema()
	_validate_template_schemas()
	_validate_config_references()
	_validate_entity_references()
	_validate_location_references()
	_validate_backend_contracts()
	_validate_action_payloads()
	return get_load_issues(_load_issues.size() - issue_start)


func finish_load(success: bool) -> void:
	is_loaded = success and _load_issues.is_empty()
	load_phase = LOAD_PHASE_READY if is_loaded else LOAD_PHASE_FAILED
	_load_finished_at = Time.get_datetime_string_from_system(true, true)


func get_debug_snapshot() -> Dictionary:
	return {
		"status": load_phase,
		"is_loaded": is_loaded,
		"started_at": _load_started_at,
		"finished_at": _load_finished_at,
		"issue_count": _load_issues.size(),
		"processed_file_count": _processed_files.size(),
		"loaded_file_count": _count_processed_files(FILE_STATUS_LOADED),
		"missing_file_count": _count_processed_files(FILE_STATUS_MISSING),
		"invalid_file_count": _count_processed_files(FILE_STATUS_INVALID),
		"registry_counts": get_registry_counts(),
		"recent_issues": get_load_issues(MAX_DEBUG_ENTRIES),
		"recent_files": _get_recent_processed_files(MAX_DEBUG_ENTRIES),
	}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Loads a JSON file and returns its parsed content, or null on failure.
func _load_json_document(mod_id: String, file_path: String, phase: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		_record_processed_file(mod_id, file_path, phase, FILE_STATUS_MISSING)
		return null
	var raw_text: String = FileAccess.get_file_as_string(file_path)
	var parser := JSON.new()
	var parse_error := parser.parse(raw_text)
	if parse_error != OK:
		_record_processed_file(mod_id, file_path, phase, FILE_STATUS_INVALID)
		_record_issue(
			mod_id,
			file_path,
			phase,
			"Invalid JSON at line %d: %s." % [parser.get_error_line(), parser.get_error_message()]
		)
		return null
	var document_value: Variant = parser.data
	if not document_value is Dictionary:
		_record_processed_file(mod_id, file_path, phase, FILE_STATUS_INVALID)
		_record_issue(mod_id, file_path, phase, "Top-level JSON document must be an object.")
		return null
	_record_processed_file(mod_id, file_path, phase, FILE_STATUS_LOADED)
	var document: Dictionary = document_value
	return document


## Deep-merges src into dst. Arrays are replaced, not appended.
func _deep_merge(dst: Dictionary, src: Dictionary) -> void:
	for key in src.keys():
		var src_value: Variant = src[key]
		if dst.has(key) and dst[key] is Dictionary and src_value is Dictionary:
			_deep_merge(dst[key], src_value)
		else:
			dst[key] = src_value


func _duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	return {}


func _duplicate_array(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	return []


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		var text := str(entry)
		if text.is_empty():
			continue
		result.append(text)
	return result


func _contains_all_strings(values: Array[String], required_values: Array[String]) -> bool:
	for required_value in required_values:
		if not values.has(required_value):
			return false
	return true


func _location_has_connection(location: Dictionary, target_location_id: String) -> bool:
	var connections_value: Variant = location.get("connections", {})
	if not connections_value is Dictionary:
		return false
	var connections: Dictionary = connections_value
	return connections.has(target_location_id)


func _location_has_screen_value(location: Dictionary, field_name: String, expected_value: String) -> bool:
	var screens_value: Variant = location.get("screens", [])
	if not screens_value is Array:
		return false
	var screens: Array = screens_value
	for screen_value in screens:
		if not screen_value is Dictionary:
			continue
		var screen: Dictionary = screen_value
		if str(screen.get(field_name, "")) == expected_value:
			return true
	return false


func _get_array_field(document: Dictionary, field_name: String, mod_id: String, file_path: String, phase: String) -> Array:
	if not document.has(field_name):
		return []
	var field_value: Variant = document.get(field_name, [])
	if field_value is Array:
		var values: Array = field_value
		return values
	_record_issue(mod_id, file_path, phase, "'%s' must be an array." % field_name)
	return []


func _filter_valid_additions(
	entries: Array,
	registry: Dictionary,
	registry_name: String,
	id_field: String,
	required_fields: Array[String],
	mod_id: String,
	file_path: String,
	phase: String
) -> Array:
	var valid_entries: Array = []
	var seen_ids: Dictionary = {}
	for entry_index in range(entries.size()):
		var entry_value: Variant = entries[entry_index]
		if not entry_value is Dictionary:
			_record_issue(mod_id, file_path, phase, "%s[%d] must be an object." % [registry_name, entry_index])
			continue
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get(id_field, ""))
		var has_required_issue := false
		for required_field in required_fields:
			if _entry_has_required_field(entry, required_field):
				continue
			_record_issue(mod_id, file_path, phase, "%s[%d] is missing required field '%s'." % [registry_name, entry_index, required_field])
			has_required_issue = true
		if entry_id.is_empty():
			continue
		if seen_ids.has(entry_id):
			_record_issue(mod_id, file_path, phase, "Duplicate %s id '%s' in this file." % [registry_name, entry_id])
			continue
		if registry.has(entry_id):
			_record_issue(mod_id, file_path, phase, "Duplicate %s id '%s' already exists in the registry." % [registry_name, entry_id])
			continue
		seen_ids[entry_id] = true
		if has_required_issue:
			continue
		valid_entries.append(entry)
	return valid_entries


func _entry_has_required_field(entry: Dictionary, field_name: String) -> bool:
	if not entry.has(field_name):
		return false
	var field_value: Variant = entry.get(field_name)
	if field_value is String:
		return not str(field_value).is_empty()
	return field_value != null


func _get_dictionary_field(document: Dictionary, field_name: String, mod_id: String, file_path: String, phase: String) -> Dictionary:
	if not document.has(field_name):
		return {}
	var field_value: Variant = document.get(field_name, {})
	if field_value is Dictionary:
		var values: Dictionary = field_value
		return values
	_record_issue(mod_id, file_path, phase, "'%s' must be an object." % field_name)
	return {}


func _validate_patch_targets(patches: Array, registry: Dictionary, registry_name: String, mod_id: String, file_path: String, phase: String) -> void:
	for patch_index in range(patches.size()):
		var patch_value: Variant = patches[patch_index]
		if not patch_value is Dictionary:
			_record_issue(mod_id, file_path, phase, "patches[%d] must be an object." % patch_index)
			continue
		var patch_entry: Dictionary = patch_value
		var target := str(patch_entry.get("target", ""))
		if target.is_empty():
			_record_issue(mod_id, file_path, phase, "patches[%d].target must be a non-empty string." % patch_index)
			continue
		if not registry.has(target):
			_record_issue(mod_id, file_path, phase, "Patch target '%s' does not exist in the %s registry." % [target, registry_name])


func _validate_patch_operations(patches: Array, allowed_operations: Array[String], registry_name: String, mod_id: String, file_path: String, phase: String) -> void:
	for patch_index in range(patches.size()):
		var patch_value: Variant = patches[patch_index]
		if not patch_value is Dictionary:
			continue
		var patch_entry: Dictionary = patch_value
		for operation_value in patch_entry.keys():
			var operation := str(operation_value)
			if allowed_operations.has(operation):
				continue
			_record_issue(mod_id, file_path, phase, "patches[%d].%s is not a supported %s patch operation." % [patch_index, operation, registry_name])


func _validate_definition_patches(patches: Array, mod_id: String, file_path: String, phase: String) -> void:
	for patch_index in range(patches.size()):
		var patch_value: Variant = patches[patch_index]
		if not patch_value is Dictionary:
			_record_issue(mod_id, file_path, phase, "patches[%d] must be an object." % patch_index)
			continue
		var patch_entry: Dictionary = patch_value
		var category := str(patch_entry.get("category", ""))
		if category.is_empty():
			_record_issue(mod_id, file_path, phase, "patches[%d].category must be a non-empty string." % patch_index)
		if patch_entry.has("add") and not patch_entry.get("add", []) is Array:
			_record_issue(mod_id, file_path, phase, "patches[%d].add must be an array." % patch_index)
		if patch_entry.has("remove") and not patch_entry.get("remove", []) is Array:
			_record_issue(mod_id, file_path, phase, "patches[%d].remove must be an array." % patch_index)


func _validate_definition_schema() -> void:
	var currency_ids: Dictionary = {}
	for currency_value in get_definitions("currencies"):
		var currency_id := str(currency_value)
		if currency_id.is_empty():
			_record_issue("definitions", OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Currency ids must be non-empty strings.")
			continue
		if currency_ids.has(currency_id):
			_record_issue("definitions", OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Duplicate currency id '%s'." % currency_id)
		currency_ids[currency_id] = true

	var stat_defs_by_id: Dictionary = {}
	for stat_value in get_definitions("stats"):
		if not stat_value is Dictionary:
			_record_issue("definitions", OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Stat definitions must be objects.")
			continue
		var stat_def: Dictionary = stat_value
		var stat_id := str(stat_def.get("id", ""))
		if stat_id.is_empty():
			_record_issue("definitions", OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Stat definitions must include a non-empty id.")
			continue
		if stat_defs_by_id.has(stat_id):
			_record_issue("definitions", OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Duplicate stat id '%s'." % stat_id)
		stat_defs_by_id[stat_id] = stat_def

	for stat_id_value in stat_defs_by_id.keys():
		var stat_id := str(stat_id_value)
		var stat_def_value: Variant = stat_defs_by_id.get(stat_id_value, {})
		if not stat_def_value is Dictionary:
			continue
		var stat_def: Dictionary = stat_def_value
		var kind := str(stat_def.get("kind", "flat"))
		if not ["flat", "resource", "capacity"].has(kind):
			_record_issue(stat_id, OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Stat '%s' has unknown kind '%s'." % [stat_id, kind])
		if kind == "resource":
			var capacity_id := str(stat_def.get("paired_capacity_id", ""))
			if capacity_id.is_empty() or not stat_defs_by_id.has(capacity_id):
				_record_issue(stat_id, OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Resource stat '%s' references missing capacity stat '%s'." % [stat_id, capacity_id])
			else:
				var capacity_def_value: Variant = stat_defs_by_id.get(capacity_id, {})
				if not capacity_def_value is Dictionary:
					continue
				var capacity_def: Dictionary = capacity_def_value
				if str(capacity_def.get("paired_base_id", "")) != stat_id:
					_record_issue(stat_id, OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Resource stat '%s' and capacity stat '%s' must reference each other." % [stat_id, capacity_id])
		elif kind == "capacity":
			var base_id := str(stat_def.get("paired_base_id", ""))
			if base_id.is_empty() or not stat_defs_by_id.has(base_id):
				_record_issue(stat_id, OmniConstants.DATA_DEFINITIONS, LOAD_PHASE_VALIDATION, "Capacity stat '%s' references missing base stat '%s'." % [stat_id, base_id])


func _validate_template_schemas() -> void:
	var stat_ids := _get_known_stat_ids()
	var currency_ids := _get_known_currency_ids()
	_validate_registry_required_fields(parts, OmniConstants.DATA_PARTS, "id", ["id", "display_name", "description", "tags"])
	_validate_registry_required_fields(entities, OmniConstants.DATA_ENTITIES, "entity_id", ["entity_id", "display_name"])
	_validate_registry_required_fields(locations, OmniConstants.DATA_LOCATIONS, "location_id", ["location_id", "display_name"])
	_validate_registry_required_fields(factions, OmniConstants.DATA_FACTIONS, "faction_id", ["faction_id", "display_name"])
	_validate_registry_required_fields(quests, OmniConstants.DATA_QUESTS, "quest_id", ["quest_id", "display_name", "stages"])
	_validate_registry_required_fields(tasks, OmniConstants.DATA_TASKS, "template_id", ["template_id", "type"])
	_validate_registry_required_fields(achievements, OmniConstants.DATA_ACHIEVEMENTS, "achievement_id", ["achievement_id", "display_name", "stat_name", "requirement"])

	for part_value in parts.values():
		if not part_value is Dictionary:
			continue
		var part: Dictionary = part_value
		var part_id := str(part.get("id", ""))
		_validate_array_field(part_id, OmniConstants.DATA_PARTS, "tags", part)
		_validate_stat_map(part_id, OmniConstants.DATA_PARTS, "stats", part.get("stats", {}), stat_ids)
		_validate_currency_map(part_id, OmniConstants.DATA_PARTS, "price", part.get("price", {}), currency_ids)
		_validate_unique_object_ids(part_id, OmniConstants.DATA_PARTS, "provides_sockets", part.get("provides_sockets", []))
		_validate_unique_object_ids(part_id, OmniConstants.DATA_PARTS, "custom_fields", part.get("custom_fields", []))

	for entity_value in entities.values():
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_id := str(entity.get("entity_id", ""))
		_validate_stat_map(entity_id, OmniConstants.DATA_ENTITIES, "stats", entity.get("stats", {}), stat_ids)
		_validate_currency_map(entity_id, OmniConstants.DATA_ENTITIES, "currencies", entity.get("currencies", {}), currency_ids)
		_validate_unique_object_ids(entity_id, OmniConstants.DATA_ENTITIES, "provides_sockets", entity.get("provides_sockets", []))

	var starting_money_value: Variant = get_config_value("game.starting_money", {})
	_validate_currency_map("config", OmniConstants.DATA_CONFIG, "game.starting_money", starting_money_value, currency_ids)


func _validate_registry_required_fields(registry: Dictionary, file_path: String, id_field: String, required_fields: Array[String]) -> void:
	for entry_value in registry.values():
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_id := str(entry.get(id_field, ""))
		for required_field in required_fields:
			if _entry_has_required_field(entry, required_field):
				continue
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s '%s' is missing required field '%s'." % [file_path, entry_id, required_field])


func _validate_array_field(entry_id: String, file_path: String, field_name: String, entry: Dictionary) -> void:
	if not entry.has(field_name):
		return
	var field_value: Variant = entry.get(field_name, [])
	if not field_value is Array:
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s must be an array." % [entry_id, field_name])


func _validate_stat_map(entry_id: String, file_path: String, field_path: String, value: Variant, stat_ids: Dictionary) -> void:
	if not value is Dictionary:
		return
	var stat_map: Dictionary = value
	for stat_key_value in stat_map.keys():
		var stat_id := str(stat_key_value)
		if stat_ids.has(stat_id):
			continue
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s references unknown stat '%s'." % [entry_id, field_path, stat_id])


func _validate_currency_map(entry_id: String, file_path: String, field_path: String, value: Variant, currency_ids: Dictionary) -> void:
	if not value is Dictionary:
		return
	var currency_map: Dictionary = value
	for currency_key_value in currency_map.keys():
		var currency_id := str(currency_key_value)
		if currency_ids.has(currency_id):
			continue
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s references unknown currency '%s'." % [entry_id, field_path, currency_id])


func _validate_unique_object_ids(entry_id: String, file_path: String, field_name: String, value: Variant) -> void:
	if not value is Array:
		return
	var entries: Array = value
	var seen_ids: Dictionary = {}
	for index in range(entries.size()):
		var item_value: Variant = entries[index]
		if not item_value is Dictionary:
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s[%d] must be an object." % [entry_id, field_name, index])
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s[%d].id must be a non-empty string." % [entry_id, field_name, index])
			continue
		if seen_ids.has(item_id):
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.%s contains duplicate id '%s'." % [entry_id, field_name, item_id])
		seen_ids[item_id] = true


func _get_known_stat_ids() -> Dictionary:
	var stat_ids: Dictionary = {}
	for stat_value in get_definitions("stats"):
		if stat_value is Dictionary:
			var stat_def: Dictionary = stat_value
			var stat_id := str(stat_def.get("id", ""))
			if not stat_id.is_empty():
				stat_ids[stat_id] = true
		else:
			var legacy_stat_id := str(stat_value)
			if not legacy_stat_id.is_empty():
				stat_ids[legacy_stat_id] = true
	return stat_ids


func _get_known_currency_ids() -> Dictionary:
	var currency_ids: Dictionary = {}
	for currency_value in get_definitions("currencies"):
		var currency_id := str(currency_value)
		if not currency_id.is_empty():
			currency_ids[currency_id] = true
	return currency_ids


func _validate_config_references() -> void:
	var player_template_id := str(get_config_value("game.starting_player_id", ""))
	if player_template_id.is_empty():
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_player_id' must reference a non-empty entity id.")
	elif not has_entity(player_template_id):
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_player_id' references unknown entity '%s'." % player_template_id)

	var starting_location_id := str(get_config_value("game.starting_location", ""))
	if not starting_location_id.is_empty() and not has_location(starting_location_id):
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_location' references unknown location '%s'." % starting_location_id)

	var game_config_value: Variant = config.get("game", {})
	if game_config_value is Dictionary:
		var game_config: Dictionary = game_config_value
		_validate_starting_discovered_locations(game_config)
		_validate_positive_integer_config("game.ticks_per_day", game_config.get("ticks_per_day", null), game_config.has("ticks_per_day"))
		_validate_positive_integer_config("game.ticks_per_hour", game_config.get("ticks_per_hour", null), game_config.has("ticks_per_hour"))

	var ui_config_value: Variant = config.get("ui", {})
	if ui_config_value is Dictionary:
		var ui_config: Dictionary = ui_config_value
		_validate_time_advance_buttons(ui_config)


func _validate_starting_discovered_locations(game_config: Dictionary) -> void:
	if not game_config.has("starting_discovered_locations"):
		return
	var locations_value: Variant = game_config.get("starting_discovered_locations", [])
	if not locations_value is Array:
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_discovered_locations' must be an array of location ids.")
		return
	var location_ids: Array = locations_value
	for index in range(location_ids.size()):
		var location_id := str(location_ids[index]).strip_edges()
		if location_id.is_empty():
			_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_discovered_locations[%d]' must be a non-empty location id." % index)
		elif not has_location(location_id):
			_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'game.starting_discovered_locations[%d]' references unknown location '%s'." % [index, location_id])


func _validate_positive_integer_config(field_path: String, value: Variant, is_present: bool) -> void:
	if not is_present:
		return
	if not _is_integral_number(value) or int(value) < 1:
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key '%s' must be an integer greater than or equal to 1." % field_path)


func _validate_time_advance_buttons(ui_config: Dictionary) -> void:
	if not ui_config.has("time_advance_buttons"):
		return
	var buttons_value: Variant = ui_config.get("time_advance_buttons", [])
	if not buttons_value is Array:
		_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'ui.time_advance_buttons' must be an array of time labels.")
		return
	var buttons: Array = buttons_value
	for index in range(buttons.size()):
		var button_value: Variant = buttons[index]
		if not button_value is String:
			_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'ui.time_advance_buttons[%d]' must be a string." % index)
			continue
		var label := str(button_value).strip_edges()
		if label.is_empty():
			_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'ui.time_advance_buttons[%d]' must be a non-empty string." % index)
		elif not _is_time_advance_label(label):
			_record_issue("base", OmniConstants.DATA_CONFIG, LOAD_PHASE_VALIDATION, "Config key 'ui.time_advance_buttons[%d]' must end with tick(s), hour(s), or day(s)." % index)


func _is_time_advance_label(label: String) -> bool:
	var split_parts := label.to_lower().split(" ", false)
	if split_parts.is_empty():
		return false
	var unit := split_parts[split_parts.size() - 1]
	return unit in ["tick", "ticks", "hour", "hours", "day", "days"]


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value := float(value)
		return is_equal_approx(numeric_value, roundf(numeric_value))
	return false


func _validate_entity_references() -> void:
	for entity_value in entities.values():
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_id := str(entity.get("entity_id", ""))
		var location_id := str(entity.get("location_id", ""))
		if not location_id.is_empty() and not has_location(location_id):
			_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' references unknown location '%s'." % [entity_id, location_id])

		var inventory_instance_ids: Dictionary = {}
		var inventory_value: Variant = entity.get("inventory", [])
		if inventory_value is Array:
			var inventory: Array = inventory_value
			for item_value in inventory:
				if not item_value is Dictionary:
					continue
				var item: Dictionary = item_value
				var instance_id := str(item.get("instance_id", ""))
				if not instance_id.is_empty():
					inventory_instance_ids[instance_id] = true
				var template_id := str(item.get("template_id", ""))
				if not template_id.is_empty() and not has_part(template_id):
					_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' inventory references unknown part template '%s'." % [entity_id, template_id])
		elif entity.has("inventory"):
			_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' field 'inventory' must be an array." % entity_id)

		var socket_map_value: Variant = entity.get("assembly_socket_map", {})
		if socket_map_value is Dictionary:
			var socket_map: Dictionary = socket_map_value
			for slot_key in socket_map.keys():
				var instance_id := str(socket_map.get(slot_key, ""))
				if instance_id.is_empty():
					continue
				if not inventory_instance_ids.has(instance_id):
					_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' socket '%s' references missing inventory instance '%s'." % [entity_id, str(slot_key), instance_id])
		elif entity.has("assembly_socket_map"):
			_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' field 'assembly_socket_map' must be an object." % entity_id)


func _validate_location_references() -> void:
	for location_value in locations.values():
		if not location_value is Dictionary:
			continue
		var location: Dictionary = location_value
		var location_id := str(location.get("location_id", ""))
		var connections_value: Variant = location.get("connections", {})
		if connections_value is Dictionary:
			var connections: Dictionary = connections_value
			for target_location_value in connections.keys():
				var target_location_id := str(target_location_value)
				if target_location_id.is_empty():
					continue
				if not has_location(target_location_id):
					_record_issue(location_id, OmniConstants.DATA_LOCATIONS, LOAD_PHASE_VALIDATION, "Location '%s' connection '%s' references unknown location '%s'." % [location_id, target_location_id, target_location_id])
		elif location.has("connections"):
			_record_issue(location_id, OmniConstants.DATA_LOCATIONS, LOAD_PHASE_VALIDATION, "Location '%s' field 'connections' must be an object." % location_id)


func _validate_backend_contracts() -> void:
	for entity_value in entities.values():
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_id := str(entity.get("entity_id", ""))
		var interactions_value: Variant = entity.get("interactions", [])
		if interactions_value is Array:
			var interactions: Array = interactions_value
			for index in range(interactions.size()):
				var interaction_value: Variant = interactions[index]
				if not interaction_value is Dictionary:
					_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' interactions[%d] must be an object." % [entity_id, index])
					continue
				var _interaction: Dictionary = interaction_value
				_record_backend_contract_issues(
					entity_id,
					OmniConstants.DATA_ENTITIES,
					interactions[index],
					"interactions[%d]" % index
				)
		elif entity.has("interactions"):
			_record_issue(entity_id, OmniConstants.DATA_ENTITIES, LOAD_PHASE_VALIDATION, "Entity '%s' field 'interactions' must be an array." % entity_id)

	for location_value in locations.values():
		if not location_value is Dictionary:
			continue
		var location: Dictionary = location_value
		var location_id := str(location.get("location_id", ""))
		var screens_value: Variant = location.get("screens", [])
		if screens_value is Array:
			var screens: Array = screens_value
			for index in range(screens.size()):
				var screen_value: Variant = screens[index]
				if not screen_value is Dictionary:
					_record_issue(location_id, OmniConstants.DATA_LOCATIONS, LOAD_PHASE_VALIDATION, "Location '%s' screens[%d] must be an object." % [location_id, index])
					continue
				_record_backend_contract_issues(
					location_id,
					OmniConstants.DATA_LOCATIONS,
					screen_value,
					"screens[%d]" % index
				)
		elif location.has("screens"):
			_record_issue(location_id, OmniConstants.DATA_LOCATIONS, LOAD_PHASE_VALIDATION, "Location '%s' field 'screens' must be an array." % location_id)


func _validate_action_payloads() -> void:
	for entity_value in entities.values():
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_id := str(entity.get("entity_id", ""))
		var interactions_value: Variant = entity.get("interactions", [])
		if not interactions_value is Array:
			continue
		var interactions: Array = interactions_value
		for index in range(interactions.size()):
			var interaction_value: Variant = interactions[index]
			if not interaction_value is Dictionary:
				continue
			_validate_action_fields(
				entity_id,
				OmniConstants.DATA_ENTITIES,
				interaction_value,
				"interactions[%d]" % index
			)

	for location_value in locations.values():
		if not location_value is Dictionary:
			continue
		var location: Dictionary = location_value
		var location_id := str(location.get("location_id", ""))
		var screens_value: Variant = location.get("screens", [])
		if not screens_value is Array:
			continue
		var screens: Array = screens_value
		for index in range(screens.size()):
			var screen_value: Variant = screens[index]
			if not screen_value is Dictionary:
				continue
			_validate_action_fields(
				location_id,
				OmniConstants.DATA_LOCATIONS,
				screen_value,
				"screens[%d]" % index
			)

	for quest_value in quests.values():
		if not quest_value is Dictionary:
			continue
		var quest: Dictionary = quest_value
		var quest_id := str(quest.get("quest_id", ""))
		_validate_action_fields(quest_id, OmniConstants.DATA_QUESTS, quest, "")

		var stages_value: Variant = quest.get("stages", [])
		if not stages_value is Array:
			continue
		var stages: Array = stages_value
		for stage_index in range(stages.size()):
			var stage_value: Variant = stages[stage_index]
			if not stage_value is Dictionary:
				continue
			_validate_action_fields(
				quest_id,
				OmniConstants.DATA_QUESTS,
				stage_value,
				"stages[%d]" % stage_index
			)


func _validate_action_fields(entry_id: String, file_path: String, payload_value: Variant, field_path: String) -> void:
	if not payload_value is Dictionary:
		return
	var payload: Dictionary = payload_value

	if payload.has("action_payload"):
		var action_payload_value: Variant = payload.get("action_payload", null)
		var action_field_path := _compose_field_path(field_path, "action_payload")
		if not action_payload_value is Dictionary:
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s must be an object." % action_field_path)
		else:
			_validate_action_payload(entry_id, file_path, action_payload_value, action_field_path)

	if payload.has("actions"):
		var actions_value: Variant = payload.get("actions", [])
		var actions_field_path := _compose_field_path(field_path, "actions")
		if not actions_value is Array:
			_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s must be an array." % actions_field_path)
			return
		var actions: Array = actions_value
		for action_index in range(actions.size()):
			var action_value: Variant = actions[action_index]
			var indexed_field_path := "%s[%d]" % [actions_field_path, action_index]
			if not action_value is Dictionary:
				_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s must be an object." % indexed_field_path)
				continue
			_validate_action_payload(entry_id, file_path, action_value, indexed_field_path)


func _validate_action_payload(entry_id: String, file_path: String, action_value: Variant, field_path: String) -> void:
	if not action_value is Dictionary:
		return
	var action: Dictionary = action_value
	var action_type := str(action.get("type", ""))
	if action_type.is_empty():
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.type must be a non-empty string." % field_path)
		return

	if action_type != "push_screen":
		return

	var screen_id := str(action.get("screen_id", ""))
	if screen_id.is_empty():
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.screen_id must be a non-empty string." % field_path)
	elif not UI_ROUTE_CATALOG.has_known_screen_id(screen_id):
		var known_screen_ids := ", ".join(UI_ROUTE_CATALOG.get_known_screen_ids())
		_record_issue(
			entry_id,
			file_path,
			LOAD_PHASE_VALIDATION,
			"%s.screen_id references unknown routed screen '%s'. Known screens: %s." % [field_path, screen_id, known_screen_ids]
		)

	if action.has("params") and not action.get("params", {}) is Dictionary:
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s.params must be an object." % field_path)


func _record_backend_contract_issues(entry_id: String, file_path: String, payload_value: Variant, field_path: String) -> void:
	if not payload_value is Dictionary:
		return
	var payload: Dictionary = payload_value
	if not payload.has("backend_class"):
		return
	var backend_class := str(payload.get("backend_class", ""))
	var issues := BACKEND_CONTRACT_REGISTRY.validate_payload(backend_class, payload, field_path)
	for issue_value in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		var issue_field_path := str(issue.get("field_path", field_path))
		var message := str(issue.get("message", "Invalid backend contract payload."))
		_record_issue(entry_id, file_path, LOAD_PHASE_VALIDATION, "%s: %s" % [issue_field_path, message])


func _compose_field_path(field_path: String, field_name: String) -> String:
	if field_path.is_empty():
		return field_name
	return "%s.%s" % [field_path, field_name]


func _begin_load_phase(phase: String) -> void:
	if _load_started_at.is_empty():
		_load_started_at = Time.get_datetime_string_from_system(true, true)
	_load_finished_at = ""
	is_loaded = false
	load_phase = phase


func _record_issue(mod_id: String, file_path: String, phase: String, message: String) -> void:
	_load_issues.append({
		"mod_id": mod_id,
		"file_path": file_path,
		"phase": phase,
		"message": message,
	})


func _record_processed_file(mod_id: String, file_path: String, phase: String, status: String) -> void:
	_processed_files.append({
		"mod_id": mod_id,
		"file_path": file_path,
		"phase": phase,
		"status": status,
	})


func _count_processed_files(status: String) -> int:
	var count := 0
	for entry in _processed_files:
		var entry_status := str(entry.get("status", ""))
		if entry_status == status:
			count += 1
	return count


func _get_recent_processed_files(limit: int) -> Array[Dictionary]:
	var files: Array[Dictionary] = []
	for entry in _processed_files:
		files.append(entry.duplicate(true))
	if limit > 0 and files.size() > limit:
		return files.slice(files.size() - limit, files.size())
	return files


func clear_all() -> void:
	is_loaded = false
	load_phase = LOAD_PHASE_IDLE
	_load_started_at = ""
	_load_finished_at = ""
	_load_issues.clear()
	_processed_files.clear()
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
