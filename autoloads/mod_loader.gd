## ModLoader — Scans mods/, runs two-phase load pipeline.
## Phase 1: additions (new content added to registries).
## Phase 2: patches (modifications to existing content).
## Missing mods/base/ is a fatal boot error.
extends Node

class_name OmniModLoader

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const ASSEMBLY_EDITOR_BACKEND := preload("res://ui/screens/backends/assembly_editor_backend.gd")
const EXCHANGE_BACKEND := preload("res://ui/screens/backends/exchange_backend.gd")
const LIST_BACKEND := preload("res://ui/screens/backends/list_backend.gd")
const CHALLENGE_BACKEND := preload("res://ui/screens/backends/challenge_backend.gd")
const TASK_PROVIDER_BACKEND := preload("res://ui/screens/backends/task_provider_backend.gd")
const CATALOG_LIST_BACKEND := preload("res://ui/screens/backends/catalog_list_backend.gd")
const CRAFTING_BACKEND := preload("res://ui/screens/backends/crafting_backend.gd")
const DIALOGUE_BACKEND := preload("res://ui/screens/backends/dialogue_backend.gd")
const ENTITY_SHEET_BACKEND := preload("res://ui/screens/backends/entity_sheet_backend.gd")
const OWNED_ENTITIES_BACKEND := preload("res://ui/screens/backends/owned_entities_backend.gd")
const ACTIVE_QUEST_LOG_BACKEND := preload("res://ui/screens/backends/active_quest_log_backend.gd")
const FACTION_REPUTATION_BACKEND := preload("res://ui/screens/backends/faction_reputation_backend.gd")
const ACHIEVEMENT_LIST_BACKEND := preload("res://ui/screens/backends/achievement_list_backend.gd")
const EVENT_LOG_BACKEND := preload("res://ui/screens/backends/event_log_backend.gd")
const WORLD_MAP_BACKEND := preload("res://ui/screens/backends/world_map_backend.gd")
const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")
const SCRIPT_HOOK_LOADER := preload("res://systems/script_hook_loader.gd")

const MODS_PATH := "res://mods/"
const BASE_MOD_ID := "base"
const BASE_MOD_PATH := "res://mods/base/"
const MOD_MANIFEST := "mod.json"
const REQUIRED_MANIFEST_FIELDS: Array[String] = ["id", "name", "version", "load_order"]
const LOAD_STATUS_IDLE := "idle"
const LOAD_STATUS_LOADING := "loading"
const LOAD_STATUS_LOADED := "loaded"
const LOAD_STATUS_FAILED := "failed"
const ERROR_STAGE_DISCOVERY := "discovery"
const ERROR_STAGE_VALIDATION := "validation"
const ERROR_STAGE_DEPENDENCIES := "dependencies"
const ERROR_STAGE_ORDERING := "ordering"

## Ordered list of loaded mod manifests: [{id, name, version, load_order, path, ...}]
var loaded_mods: Array[Dictionary] = []

## Whether all mods have finished loading.
var is_loaded: bool = false
var load_report: Dictionary = {}
var _script_hook_loader: ScriptHookLoader = null

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_script_hook_loader = SCRIPT_HOOK_LOADER.new()


## Entry point called by the boot sequence.
## Scans, validates, sorts, then runs both load phases.
func load_all_mods() -> void:
	var started_ms := Time.get_ticks_msec()
	is_loaded = false
	loaded_mods.clear()
	load_report = _create_empty_load_report()
	load_report["status"] = LOAD_STATUS_LOADING
	load_report["started_at"] = Time.get_datetime_string_from_system(true, true)
	_register_backend_contracts()
	DataManager.clear_all()

	var discovered := _discover_mods()
	if discovered.is_empty():
		_record_load_error(BASE_MOD_ID, "Failed to discover any valid mods.", true, ERROR_STAGE_DISCOVERY)
		DataManager.finish_load(false)
		_finalize_load(started_ms)
		return

	loaded_mods = _filter_loadable_mods(discovered)
	if loaded_mods.is_empty():
		_record_load_error(BASE_MOD_ID, "No loadable mods remained after validation.", true, ERROR_STAGE_VALIDATION)
		DataManager.finish_load(false)
		_finalize_load(started_ms)
		return
	loaded_mods = _resolve_load_order(loaded_mods)
	if loaded_mods.is_empty():
		_record_load_error(BASE_MOD_ID, "Unable to resolve a valid mod load order.", true, ERROR_STAGE_ORDERING)
		DataManager.finish_load(false)
		_finalize_load(started_ms)
		return
	load_report["load_order"] = _manifest_id_list(loaded_mods)
	load_report["loaded_mod_ids"] = _manifest_id_list(loaded_mods)
	load_report["loaded_mod_count"] = loaded_mods.size()

	var phase_one_started_ms := Time.get_ticks_msec()
	_phase_one_additions(loaded_mods)
	load_report["phase_one_ms"] = Time.get_ticks_msec() - phase_one_started_ms

	var phase_two_started_ms := Time.get_ticks_msec()
	_phase_two_patches(loaded_mods)
	load_report["phase_two_ms"] = Time.get_ticks_msec() - phase_two_started_ms

	var data_validation_started_ms := Time.get_ticks_msec()
	var data_issues := DataManager.validate_loaded_content()
	load_report["data_validation_ms"] = Time.get_ticks_msec() - data_validation_started_ms
	_record_data_manager_issues(data_issues)
	if not data_issues.is_empty():
		DataManager.finish_load(false)
		_finalize_load(started_ms)
		return

	var script_hook_started_ms := Time.get_ticks_msec()
	if _script_hook_loader != null:
		_script_hook_loader.clear_cache()
		_script_hook_loader.preload_all()
	load_report["script_hook_preload_ms"] = Time.get_ticks_msec() - script_hook_started_ms
	DataManager.finish_load(true)
	is_loaded = true
	_emit_loaded_mod_events(loaded_mods)
	if GameEvents:
		GameEvents.all_mods_loaded.emit()
	_finalize_load(started_ms)


func _register_backend_contracts() -> void:
	BACKEND_CONTRACT_REGISTRY.clear()
	ASSEMBLY_EDITOR_BACKEND.register_contract()
	EXCHANGE_BACKEND.register_contract()
	LIST_BACKEND.register_contract()
	CHALLENGE_BACKEND.register_contract()
	TASK_PROVIDER_BACKEND.register_contract()
	CATALOG_LIST_BACKEND.register_contract()
	CRAFTING_BACKEND.register_contract()
	DIALOGUE_BACKEND.register_contract()
	ENTITY_SHEET_BACKEND.register_contract()
	OWNED_ENTITIES_BACKEND.register_contract()
	ACTIVE_QUEST_LOG_BACKEND.register_contract()
	FACTION_REPUTATION_BACKEND.register_contract()
	ACHIEVEMENT_LIST_BACKEND.register_contract()
	EVENT_LOG_BACKEND.register_contract()
	WORLD_MAP_BACKEND.register_contract()
	ENCOUNTER_BACKEND.register_contract()
	BACKEND_CONTRACT_REGISTRY.lock()


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

## Returns an array of mod manifest dictionaries found under MODS_PATH.
## Emits a fatal error if the base mod is missing.
func _discover_mods() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	var base_manifest := _read_manifest(BASE_MOD_PATH)
	if base_manifest.is_empty() or not _validate_manifest(base_manifest) or not _validate_base_manifest(base_manifest):
		_record_load_error(BASE_MOD_ID, "Missing or invalid base mod at %s." % BASE_MOD_PATH, true, ERROR_STAGE_DISCOVERY)
		return []
	mods.append(base_manifest)

	var mods_dir := DirAccess.open(MODS_PATH)
	if mods_dir == null:
		_record_load_error(BASE_MOD_ID, "Unable to open mods directory at %s." % MODS_PATH, true, ERROR_STAGE_DISCOVERY)
		return []

	mods_dir.list_dir_begin()
	var author_id := mods_dir.get_next()
	while not author_id.is_empty():
		if mods_dir.current_is_dir() and not author_id.begins_with(".") and author_id != BASE_MOD_ID:
			var author_path := MODS_PATH.path_join(author_id)
			var author_dir := DirAccess.open(author_path)
			if author_dir:
				author_dir.list_dir_begin()
				var mod_id := author_dir.get_next()
				while not mod_id.is_empty():
					if author_dir.current_is_dir() and not mod_id.begins_with("."):
						var mod_path := author_path.path_join(mod_id)
						var manifest := _read_manifest(mod_path)
						if not manifest.is_empty() and _validate_manifest(manifest) and bool(manifest.get("enabled", true)):
							mods.append(manifest)
					mod_id = author_dir.get_next()
				author_dir.list_dir_end()
		author_id = mods_dir.get_next()
	mods_dir.list_dir_end()
	load_report["discovered_mod_ids"] = _manifest_id_list(mods)
	load_report["discovered_mod_count"] = mods.size()

	return mods


## Reads and parses a mod.json file. Returns empty dict on failure.
func _read_manifest(mod_path: String) -> Dictionary:
	var manifest_path := mod_path.path_join(MOD_MANIFEST)
	if not FileAccess.file_exists(manifest_path):
		var manifest_owner := mod_path.trim_suffix("/").get_file()
		_record_load_error(manifest_owner, "Missing manifest at '%s'." % manifest_path, false, ERROR_STAGE_DISCOVERY)
		return {}
	var raw_text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		var manifest_owner := mod_path.trim_suffix("/").get_file()
		_record_load_error(manifest_owner, "Invalid manifest JSON at '%s'." % manifest_path, false, ERROR_STAGE_DISCOVERY)
		return {}
	var manifest: Dictionary = parsed
	manifest["path"] = mod_path
	return manifest


## Validates required manifest fields. Returns true if valid.
func _validate_manifest(manifest: Dictionary) -> bool:
	var manifest_id := str(manifest.get("id", manifest.get("name", "<unknown>")))
	for field_name in REQUIRED_MANIFEST_FIELDS:
		if not manifest.has(field_name):
			_record_load_error(manifest_id, "Manifest missing required field '%s'." % field_name, false, ERROR_STAGE_VALIDATION)
			return false
	var id_value: Variant = manifest.get("id", "")
	if not id_value is String:
		_record_load_error(manifest_id, "Manifest field 'id' must be a string.", false, ERROR_STAGE_VALIDATION)
		return false
	var normalized_id := str(id_value).strip_edges()
	if normalized_id.is_empty():
		_record_load_error(manifest_id, "Manifest field 'id' must be a non-empty string.", false, ERROR_STAGE_VALIDATION)
		return false
	manifest["id"] = normalized_id
	manifest_id = normalized_id

	var name_value: Variant = manifest.get("name", "")
	if not name_value is String:
		_record_load_error(manifest_id, "Manifest field 'name' must be a string.", false, ERROR_STAGE_VALIDATION)
		return false
	var normalized_name := str(name_value).strip_edges()
	if normalized_name.is_empty():
		_record_load_error(manifest_id, "Manifest field 'name' must be a non-empty string.", false, ERROR_STAGE_VALIDATION)
		return false
	manifest["name"] = normalized_name

	var version_value: Variant = manifest.get("version", "")
	if not version_value is String:
		_record_load_error(manifest_id, "Manifest field 'version' must be a string.", false, ERROR_STAGE_VALIDATION)
		return false
	var normalized_version := str(version_value).strip_edges()
	if normalized_version.is_empty():
		_record_load_error(manifest_id, "Manifest field 'version' must be a non-empty string.", false, ERROR_STAGE_VALIDATION)
		return false
	manifest["version"] = normalized_version

	var load_order_value: Variant = manifest.get("load_order", null)
	if not _is_integral_number(load_order_value):
		_record_load_error(manifest_id, "Manifest field 'load_order' must be an integer.", false, ERROR_STAGE_VALIDATION)
		return false
	manifest["load_order"] = int(load_order_value)

	var enabled_value: Variant = manifest.get("enabled", true)
	if not enabled_value is bool:
		_record_load_error(manifest_id, "Manifest field 'enabled' must be a bool when present.", false, ERROR_STAGE_VALIDATION)
		return false
	manifest["enabled"] = bool(enabled_value)

	if manifest.has("schema_version"):
		var schema_version_value: Variant = manifest.get("schema_version", null)
		if not _is_integral_number(schema_version_value):
			_record_load_error(manifest_id, "Manifest field 'schema_version' must be an integer when present.", false, ERROR_STAGE_VALIDATION)
			return false
		manifest["schema_version"] = int(schema_version_value)

	var dependencies_data: Variant = manifest.get("dependencies", [])
	if not dependencies_data is Array:
		_record_load_error(manifest_id, "Manifest field 'dependencies' must be an array when present.", false, ERROR_STAGE_VALIDATION)
		return false
	var dependencies: Array[String] = []
	var seen_dependencies: Dictionary = {}
	var dependencies_array: Array = dependencies_data
	for dependency_value in dependencies_array:
		if not dependency_value is String:
			_record_load_error(manifest_id, "Manifest dependencies must contain only non-empty strings.", false, ERROR_STAGE_VALIDATION)
			return false
		var dependency_id := str(dependency_value).strip_edges()
		if dependency_id.is_empty():
			_record_load_error(manifest_id, "Manifest dependencies must contain only non-empty strings.", false, ERROR_STAGE_VALIDATION)
			return false
		if dependency_id == normalized_id:
			_record_load_error(manifest_id, "Manifest cannot depend on itself.", false, ERROR_STAGE_VALIDATION)
			return false
		if seen_dependencies.has(dependency_id):
			continue
		seen_dependencies[dependency_id] = true
		dependencies.append(dependency_id)
	manifest["dependencies"] = dependencies
	return true


func _validate_base_manifest(manifest: Dictionary) -> bool:
	var manifest_id := str(manifest.get("id", ""))
	if manifest_id != BASE_MOD_ID:
		_record_load_error(manifest_id, "Base mod manifest must use id '%s'." % BASE_MOD_ID, true, ERROR_STAGE_VALIDATION)
		return false
	if not bool(manifest.get("enabled", true)):
		_record_load_error(manifest_id, "Base mod cannot be disabled.", true, ERROR_STAGE_VALIDATION)
		return false
	if int(manifest.get("load_order", -1)) != 0:
		_record_load_error(manifest_id, "Base mod must use load_order 0.", true, ERROR_STAGE_VALIDATION)
		return false
	if not _get_dependencies(manifest).is_empty():
		_record_load_error(manifest_id, "Base mod cannot declare dependencies.", true, ERROR_STAGE_VALIDATION)
		return false
	return true


## Sorts manifests by load_order ascending. Base mod (load_order: 0) always first.
func _sort_by_load_order(mods: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := mods.duplicate()
	sorted.sort_custom(_compare_manifests)
	return sorted


func _filter_loadable_mods(mods: Array[Dictionary]) -> Array[Dictionary]:
	var unique_mods: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for manifest in _sort_by_load_order(mods):
		var mod_id := str(manifest.get("id", ""))
		if seen_ids.has(mod_id):
			_record_load_error(mod_id, "Duplicate mod id '%s' detected. Skipping later manifest." % mod_id, false, ERROR_STAGE_VALIDATION)
			continue
		seen_ids[mod_id] = true
		unique_mods.append(manifest)

	var filtered := unique_mods
	var removed_any := true
	while removed_any:
		removed_any = false
		var available_ids := _manifest_id_set(filtered)
		var next_filtered: Array[Dictionary] = []
		for manifest in filtered:
			var missing_dependencies := _get_missing_dependencies(manifest, available_ids)
			if missing_dependencies.is_empty():
				next_filtered.append(manifest)
				continue
			removed_any = true
			_record_load_error(
				str(manifest.get("id", "")),
				"Skipping mod because dependencies are unavailable: %s." % ", ".join(missing_dependencies),
				false,
				ERROR_STAGE_DEPENDENCIES
			)
		filtered = next_filtered
	return filtered


func _resolve_load_order(mods: Array[Dictionary]) -> Array[Dictionary]:
	var pending := _sort_by_load_order(mods)
	var resolved: Array[Dictionary] = []
	var resolved_ids: Dictionary = {}
	var made_progress := true

	while not pending.is_empty() and made_progress:
		made_progress = false
		var next_pending: Array[Dictionary] = []
		for manifest in pending:
			var dependencies := _get_dependencies(manifest)
			if _dependencies_resolved(dependencies, resolved_ids):
				resolved.append(manifest)
				resolved_ids[str(manifest.get("id", ""))] = true
				made_progress = true
				continue
			next_pending.append(manifest)
		pending = next_pending

	if not pending.is_empty():
		for manifest in pending:
			_record_load_error(
				str(manifest.get("id", "")),
				"Unable to resolve mod ordering because dependency requirements could not be satisfied.",
				false,
				ERROR_STAGE_ORDERING
			)
	return resolved


# ---------------------------------------------------------------------------
# Load phases
# ---------------------------------------------------------------------------

## Phase 1: iterate mods in order, call DataManager.register_additions() for each.
func _phase_one_additions(mods: Array[Dictionary]) -> void:
	for manifest in mods:
		var data_path := str(manifest.get("path", "")).path_join("data")
		_record_data_manager_issues(DataManager.register_additions(str(manifest.get("id", "")), data_path))


## Phase 2: iterate mods in order, call DataManager.apply_patches() for each.
func _phase_two_patches(mods: Array[Dictionary]) -> void:
	for manifest in mods:
		var data_path := str(manifest.get("path", "")).path_join("data")
		_record_data_manager_issues(DataManager.apply_patches(str(manifest.get("id", "")), data_path))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a loaded mod manifest by id, or empty dict.
func get_mod(mod_id: String) -> Dictionary:
	for manifest in loaded_mods:
		if str(manifest.get("id", "")) == mod_id:
			return manifest
	return {}


## Returns true if a mod with the given id is loaded.
func is_mod_loaded(mod_id: String) -> bool:
	return not get_mod(mod_id).is_empty()


func get_script_hook(script_path: String) -> ScriptHook:
	if _script_hook_loader == null:
		return null
	return _script_hook_loader.get_hook(script_path)


func get_load_errors(include_fatal: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var errors_data: Variant = load_report.get("errors", [])
	if not errors_data is Array:
		return result
	var errors: Array = errors_data
	for error_value in errors:
		if not error_value is Dictionary:
			continue
		var error_entry: Dictionary = error_value
		if not include_fatal and bool(error_entry.get("fatal", false)):
			continue
		result.append(error_entry.duplicate(true))
	return result


func get_debug_snapshot() -> Dictionary:
	return {
		"status": str(load_report.get("status", LOAD_STATUS_IDLE)),
		"is_loaded": is_loaded,
		"loaded_mod_count": loaded_mods.size(),
		"loaded_mod_ids": _manifest_id_list(loaded_mods),
		"discovered_mod_count": int(load_report.get("discovered_mod_count", 0)),
		"discovered_mod_ids": _duplicate_string_array(load_report.get("discovered_mod_ids", [])),
		"load_order": _duplicate_string_array(load_report.get("load_order", [])),
		"error_count": int(load_report.get("error_count", 0)),
		"fatal_error_count": int(load_report.get("fatal_error_count", 0)),
		"nonfatal_error_count": int(load_report.get("nonfatal_error_count", 0)),
		"phase_one_ms": int(load_report.get("phase_one_ms", 0)),
		"phase_two_ms": int(load_report.get("phase_two_ms", 0)),
		"data_validation_ms": int(load_report.get("data_validation_ms", 0)),
		"script_hook_preload_ms": int(load_report.get("script_hook_preload_ms", 0)),
		"total_ms": int(load_report.get("total_ms", 0)),
		"started_at": str(load_report.get("started_at", "")),
		"finished_at": str(load_report.get("finished_at", "")),
	}


func _compare_manifests(a: Dictionary, b: Dictionary) -> bool:
	var a_id := str(a.get("id", ""))
	var b_id := str(b.get("id", ""))
	if a_id == BASE_MOD_ID and b_id != BASE_MOD_ID:
		return true
	if b_id == BASE_MOD_ID and a_id != BASE_MOD_ID:
		return false

	var a_order := int(a.get("load_order", 0))
	var b_order := int(b.get("load_order", 0))
	if a_order != b_order:
		return a_order < b_order

	return a_id.naturalnocasecmp_to(b_id) < 0


func _create_empty_load_report() -> Dictionary:
	return {
		"status": LOAD_STATUS_IDLE,
		"started_at": "",
		"finished_at": "",
		"total_ms": 0,
		"discovered_mod_count": 0,
		"discovered_mod_ids": [],
		"loaded_mod_ids": [],
		"loaded_mod_count": 0,
		"load_order": [],
		"errors": [],
		"error_count": 0,
		"fatal_error_count": 0,
		"nonfatal_error_count": 0,
		"phase_one_ms": 0,
		"phase_two_ms": 0,
		"data_validation_ms": 0,
		"script_hook_preload_ms": 0,
	}


func _manifest_id_list(mods: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for manifest in mods:
		result.append(str(manifest.get("id", "")))
	return result


func _manifest_id_set(mods: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for manifest in mods:
		result[str(manifest.get("id", ""))] = true
	return result


func _get_dependencies(manifest: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var dependencies_data: Variant = manifest.get("dependencies", [])
	if not dependencies_data is Array:
		return result
	for dependency in dependencies_data:
		var dependency_id := str(dependency)
		if dependency_id.is_empty():
			continue
		result.append(dependency_id)
	return result


func _get_missing_dependencies(manifest: Dictionary, available_ids: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for dependency_id in _get_dependencies(manifest):
		if not available_ids.has(dependency_id):
			missing.append(dependency_id)
	return missing


func _dependencies_resolved(dependencies: Array[String], resolved_ids: Dictionary) -> bool:
	for dependency_id in dependencies:
		if not resolved_ids.has(dependency_id):
			return false
	return true


func _emit_loaded_mod_events(mods: Array[Dictionary]) -> void:
	if not GameEvents:
		return
	for manifest in mods:
		GameEvents.mod_loaded.emit(str(manifest.get("id", "")))


func _record_data_manager_issues(issues: Array[Dictionary]) -> void:
	for issue in issues:
		var mod_id := str(issue.get("mod_id", "data_manager"))
		var file_path := str(issue.get("file_path", ""))
		var message := str(issue.get("message", "Unknown DataManager issue."))
		var phase := str(issue.get("phase", ERROR_STAGE_VALIDATION))
		if not file_path.is_empty():
			message = "%s (%s)" % [message, file_path]
		_record_load_error(mod_id, message, true, phase)


func _finalize_load(started_ms: int) -> void:
	load_report["finished_at"] = Time.get_datetime_string_from_system(true, true)
	load_report["total_ms"] = Time.get_ticks_msec() - started_ms
	var fatal_error_count := 0
	var errors := get_load_errors()
	for error_entry in errors:
		if bool(error_entry.get("fatal", false)):
			fatal_error_count += 1
	load_report["error_count"] = errors.size()
	load_report["fatal_error_count"] = fatal_error_count
	load_report["nonfatal_error_count"] = errors.size() - fatal_error_count
	load_report["status"] = LOAD_STATUS_LOADED if is_loaded and fatal_error_count == 0 else LOAD_STATUS_FAILED


func _record_load_error(mod_id: String, message: String, is_fatal: bool = false, stage: String = "") -> void:
	var errors_data: Variant = load_report.get("errors", [])
	var errors: Array = []
	if errors_data is Array:
		errors = errors_data
	errors.append({
		"mod_id": mod_id,
		"message": message,
		"fatal": is_fatal,
		"stage": stage,
	})
	load_report["errors"] = errors
	if GameEvents:
		GameEvents.mod_load_error.emit(mod_id, message)
	if is_fatal:
		push_error("ModLoader: %s" % message)
	else:
		push_warning("ModLoader: %s" % message)


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value := float(value)
		return is_equal_approx(numeric_value, roundf(numeric_value))
	return false


func _duplicate_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		result.append(str(entry))
	return result
