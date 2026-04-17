## ModLoader — Scans mods/, runs two-phase load pipeline.
## Phase 1: additions (new content added to registries).
## Phase 2: patches (modifications to existing content).
## Missing mods/base/ is a fatal boot error.
extends Node

class_name OmniModLoader

const MODS_PATH := "res://mods/"
const BASE_MOD_ID := "base"
const BASE_MOD_PATH := "res://mods/base/"
const MOD_MANIFEST := "mod.json"

## Ordered list of loaded mod manifests: [{id, name, version, load_order, path, ...}]
var loaded_mods: Array[Dictionary] = []

## Whether all mods have finished loading.
var is_loaded: bool = false

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass


## Entry point called by the boot sequence.
## Scans, validates, sorts, then runs both load phases.
func load_all_mods() -> void:
	is_loaded = false
	loaded_mods.clear()
	DataManager.clear_all()

	var discovered := _discover_mods()
	if discovered.is_empty():
		push_error("ModLoader: failed to discover any valid mods.")
		return

	loaded_mods = _sort_by_load_order(discovered)
	_phase_one_additions(loaded_mods)
	_phase_two_patches(loaded_mods)
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
		push_error("ModLoader: missing or invalid base mod at %s" % BASE_MOD_PATH)
		return []
	if bool(base_manifest.get("enabled", true)):
		mods.append(base_manifest)

	var mods_dir := DirAccess.open(MODS_PATH)
	if mods_dir == null:
		push_error("ModLoader: unable to open mods directory at %s" % MODS_PATH)
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

	return mods


## Reads and parses a mod.json file. Returns empty dict on failure.
func _read_manifest(mod_path: String) -> Dictionary:
	var manifest_path := mod_path.path_join(MOD_MANIFEST)
	if not FileAccess.file_exists(manifest_path):
		return {}
	var raw_text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		push_warning("ModLoader: invalid manifest JSON at '%s'" % manifest_path)
		return {}
	var manifest: Dictionary = parsed
	manifest["path"] = mod_path
	return manifest


## Validates required manifest fields. Returns true if valid.
func _validate_manifest(manifest: Dictionary) -> bool:
	var required_fields := ["id", "name", "version", "load_order"]
	for field_name in required_fields:
		if not manifest.has(field_name):
			push_warning("ModLoader: manifest missing required field '%s'" % field_name)
			return false
	return true


## Sorts manifests by load_order ascending. Base mod (load_order: 0) always first.
func _sort_by_load_order(mods: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := mods.duplicate()
	sorted.sort_custom(_compare_manifests)
	return sorted


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
