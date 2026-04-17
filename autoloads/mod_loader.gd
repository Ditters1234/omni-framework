## ModLoader — Scans mods/, runs two-phase load pipeline.
## Phase 1: additions (new content added to registries).
## Phase 2: patches (modifications to existing content).
## Missing mods/base/ is a fatal boot error.
extends Node

class_name OmniModLoader

const SCRIPT_HOOK_LOADER := preload("res://systems/script_hook_loader.gd")

const MODS_PATH := "res://mods/"
const BASE_MOD_ID := "base"
const BASE_MOD_PATH := "res://mods/base/"
const MOD_MANIFEST := "mod.json"

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
	is_loaded = false
	loaded_mods.clear()
	load_report = _create_empty_load_report()
	DataManager.clear_all()

	var discovered := _discover_mods()
	if discovered.is_empty():
		_record_load_error(BASE_MOD_ID, "Failed to discover any valid mods.", true)
		return

	loaded_mods = _filter_loadable_mods(discovered)
	if loaded_mods.is_empty():
		_record_load_error(BASE_MOD_ID, "No loadable mods remained after validation.", true)
		return
	loaded_mods = _resolve_load_order(loaded_mods)
	if loaded_mods.is_empty():
		_record_load_error(BASE_MOD_ID, "Unable to resolve a valid mod load order.", true)
		return
	load_report["load_order"] = _manifest_id_list(loaded_mods)

	var phase_one_started_ms := Time.get_ticks_msec()
	_phase_one_additions(loaded_mods)
	load_report["phase_one_ms"] = Time.get_ticks_msec() - phase_one_started_ms

	var phase_two_started_ms := Time.get_ticks_msec()
	_phase_two_patches(loaded_mods)
	load_report["phase_two_ms"] = Time.get_ticks_msec() - phase_two_started_ms
	if _script_hook_loader != null:
		_script_hook_loader.clear_cache()
		_script_hook_loader.preload_all()
	is_loaded = true
	GameEvents.all_mods_loaded.emit()


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

## Returns an array of mod manifest dictionaries found under MODS_PATH.
## Emits a fatal error if the base mod is missing.
func _discover_mods() -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	var base_manifest := _read_manifest(BASE_MOD_PATH)
	if base_manifest.is_empty() or not _validate_manifest(base_manifest):
		_record_load_error(BASE_MOD_ID, "Missing or invalid base mod at %s." % BASE_MOD_PATH, true)
		return []
	if bool(base_manifest.get("enabled", true)):
		mods.append(base_manifest)

	var mods_dir := DirAccess.open(MODS_PATH)
	if mods_dir == null:
		_record_load_error(BASE_MOD_ID, "Unable to open mods directory at %s." % MODS_PATH, true)
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

	return mods


## Reads and parses a mod.json file. Returns empty dict on failure.
func _read_manifest(mod_path: String) -> Dictionary:
	var manifest_path := mod_path.path_join(MOD_MANIFEST)
	if not FileAccess.file_exists(manifest_path):
		return {}
	var raw_text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		var manifest_owner := mod_path.trim_suffix("/").get_file()
		_record_load_error(manifest_owner, "Invalid manifest JSON at '%s'." % manifest_path)
		return {}
	var manifest: Dictionary = parsed
	manifest["path"] = mod_path
	return manifest


## Validates required manifest fields. Returns true if valid.
func _validate_manifest(manifest: Dictionary) -> bool:
	var required_fields := ["id", "name", "version", "load_order"]
	var manifest_id := str(manifest.get("id", manifest.get("name", "<unknown>")))
	for field_name in required_fields:
		if not manifest.has(field_name):
			_record_load_error(manifest_id, "Manifest missing required field '%s'." % field_name)
			return false
	if str(manifest.get("id", "")).is_empty():
		_record_load_error(manifest_id, "Manifest field 'id' must be a non-empty string.")
		return false
	if str(manifest.get("name", "")).is_empty():
		_record_load_error(manifest_id, "Manifest field 'name' must be a non-empty string.")
		return false
	var dependencies_data: Variant = manifest.get("dependencies", [])
	if not dependencies_data is Array:
		_record_load_error(manifest_id, "Manifest field 'dependencies' must be an array when present.")
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
			_record_load_error(mod_id, "Duplicate mod id '%s' detected. Skipping later manifest." % mod_id)
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
				"Skipping mod because dependencies are unavailable: %s." % ", ".join(missing_dependencies)
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
				"Unable to resolve mod ordering because dependency requirements could not be satisfied."
			)
	return resolved


# ---------------------------------------------------------------------------
# Load phases
# ---------------------------------------------------------------------------

## Phase 1: iterate mods in order, call DataManager.register_additions() for each.
func _phase_one_additions(mods: Array[Dictionary]) -> void:
	for manifest in mods:
		var data_path := str(manifest.get("path", "")).path_join("data")
		DataManager.register_additions(str(manifest.get("id", "")), data_path)
		GameEvents.mod_loaded.emit(str(manifest.get("id", "")))


## Phase 2: iterate mods in order, call DataManager.apply_patches() for each.
func _phase_two_patches(mods: Array[Dictionary]) -> void:
	for manifest in mods:
		var data_path := str(manifest.get("path", "")).path_join("data")
		DataManager.apply_patches(str(manifest.get("id", "")), data_path)


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
		"discovered_mod_ids": [],
		"load_order": [],
		"errors": [],
		"phase_one_ms": 0,
		"phase_two_ms": 0,
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


func _record_load_error(mod_id: String, message: String, is_fatal: bool = false) -> void:
	var errors_data: Variant = load_report.get("errors", [])
	var errors: Array = []
	if errors_data is Array:
		errors = errors_data
	errors.append({
		"mod_id": mod_id,
		"message": message,
		"fatal": is_fatal,
	})
	load_report["errors"] = errors
	if GameEvents:
		GameEvents.mod_load_error.emit(mod_id, message)
	if is_fatal:
		push_error("ModLoader: %s" % message)
	else:
		push_warning("ModLoader: %s" % message)
