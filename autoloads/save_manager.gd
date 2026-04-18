## SaveManager — JSON save/load using A2J for typed, lossless round-trips.
## Saves written to user://saves/slot_N.json
## All runtime classes that need serialization must be registered
## in A2J.object_registry during _ready().
extends Node

class_name OmniSaveManager

const SAVE_DIR := "user://saves/"
const SAVE_FILE_TEMPLATE := "user://saves/slot_%d.json"
const MAX_SAVE_SLOTS := 5
const SCHEMA_VERSION := 1
const REQUIRED_SAVE_FIELDS := ["game_state"]
const OPTIONAL_SAVE_FIELDS := ["save_schema_version", "created_at", "updated_at", "slot_metadata"]
const REQUIRED_RUNTIME_CLASSES := ["EntityInstance", "PartInstance"]

var last_operation_summary: Dictionary = {}
var _registered_runtime_classes: Array[String] = []
var _save_dir_ready: bool = false

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_save_dir_ready = _ensure_save_dir()
	_register_runtime_classes()
	last_operation_summary = {
		"kind": "boot",
		"status": "ok" if _save_dir_ready else "failed",
		"save_dir": SAVE_DIR,
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
		"missing_runtime_classes": _get_missing_runtime_classes(),
	}


## Creates the save directory if it doesn't exist.
func _ensure_save_dir() -> bool:
	var make_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	return make_result == OK


## Registers all runtime classes with A2J.object_registry so A2J can
## serialize and deserialize typed objects. Add new classes here as they
## are created (EntityInstance, PartInstance, QuestInstance, etc.).
func _register_runtime_classes() -> void:
	_registered_runtime_classes.clear()
	A2J.object_registry["EntityInstance"] = EntityInstance
	_registered_runtime_classes.append("EntityInstance")
	A2J.object_registry["PartInstance"] = PartInstance
	_registered_runtime_classes.append("PartInstance")


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

## Saves the current GameState to the given slot (1-indexed).
## Emits GameEvents.save_started / save_completed / save_failed.
func save_game(slot: int) -> void:
	if not _is_valid_slot(slot):
		var reason := "Save slot must be between 1 and %d." % MAX_SAVE_SLOTS
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": reason}
		GameEvents.save_failed.emit(slot, reason)
		return
	GameEvents.save_started.emit(slot)
	if not _save_dir_ready and not _ensure_save_dir():
		var directory_reason := "Unable to create the save directory."
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": directory_reason}
		GameEvents.save_failed.emit(slot, directory_reason)
		return
	_save_dir_ready = true
	var missing_runtime_classes := _get_missing_runtime_classes()
	if not missing_runtime_classes.is_empty():
		var registry_reason := "SaveManager is missing required A2J registrations: %s." % ", ".join(missing_runtime_classes)
		last_operation_summary = {
			"kind": "save",
			"slot": slot,
			"status": "failed",
			"reason": registry_reason,
			"missing_runtime_classes": missing_runtime_classes.duplicate(),
		}
		GameEvents.save_failed.emit(slot, registry_reason)
		return
	var runtime_issues := GameState.validate_runtime_state()
	if not runtime_issues.is_empty():
		var runtime_reason := "Refusing to save invalid runtime state: %s" % runtime_issues[0]
		last_operation_summary = {
			"kind": "save",
			"slot": slot,
			"status": "failed",
			"reason": runtime_reason,
			"validation_issues": runtime_issues.duplicate(),
		}
		GameEvents.save_failed.emit(slot, runtime_reason)
		return
	_sync_timekeeper_from_game_state()
	var path := _slot_path(slot)
	var existing_payload := _read_raw_payload(path)
	var payload := _build_save_payload(existing_payload)
	var payload_error := _validate_raw_payload(payload)
	if not payload_error.is_empty():
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": payload_error}
		GameEvents.save_failed.emit(slot, payload_error)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Unable to open save file for writing."
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": reason}
		GameEvents.save_failed.emit(slot, reason)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	var write_error := file.get_error()
	file.flush()
	file.close()
	if write_error != OK:
		var write_reason := "Unable to write the save file."
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": write_reason}
		GameEvents.save_failed.emit(slot, write_reason)
		return
	last_operation_summary = {
		"kind": "save",
		"slot": slot,
		"status": "ok",
		"schema_version": SCHEMA_VERSION,
		"updated_at": str(payload.get("updated_at", "")),
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
	}
	GameEvents.save_completed.emit(slot)


## Builds the full save payload dictionary from GameState.
func _build_save_payload(previous_payload: Dictionary = {}) -> Dictionary:
	var state_payload: Variant = GameState.to_dict()
	state_payload = A2J.to_json(state_payload)
	var created_at := str(previous_payload.get("created_at", ""))
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(true, true)
	return {
		"save_schema_version": SCHEMA_VERSION,
		"engine_version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"created_at": created_at,
		"updated_at": Time.get_datetime_string_from_system(true, true),
		"slot_metadata": {
			"display_name": "Day %d" % GameState.current_day,
			"day": GameState.current_day,
			"tick": GameState.current_tick,
			"playtime_seconds": 0,
		},
		"game_state": state_payload,
	}


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

## Loads a save from the given slot into GameState.
## Emits GameEvents.load_started / load_completed / load_failed.
## Returns true on success.
func load_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		var invalid_reason := "Save slot must be between 1 and %d." % MAX_SAVE_SLOTS
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": invalid_reason}
		GameEvents.load_failed.emit(slot, invalid_reason)
		return false
	GameEvents.load_started.emit(slot)
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		var missing_reason := "Save slot is empty."
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": missing_reason}
		GameEvents.load_failed.emit(slot, missing_reason)
		return false
	var missing_runtime_classes := _get_missing_runtime_classes()
	if not missing_runtime_classes.is_empty():
		var registry_reason := "SaveManager is missing required A2J registrations: %s." % ", ".join(missing_runtime_classes)
		last_operation_summary = {
			"kind": "load",
			"slot": slot,
			"status": "failed",
			"reason": registry_reason,
			"missing_runtime_classes": missing_runtime_classes.duplicate(),
		}
		GameEvents.load_failed.emit(slot, registry_reason)
		return false

	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw_data is Dictionary:
		var json_reason := "Save file is invalid JSON."
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": json_reason}
		GameEvents.load_failed.emit(slot, json_reason)
		return false

	var raw_payload: Dictionary = raw_data
	var payload_error := _validate_raw_payload(raw_payload)
	if not payload_error.is_empty():
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": payload_error}
		GameEvents.load_failed.emit(slot, payload_error)
		return false

	var migrated := _migrate_if_needed(raw_payload.duplicate(true))
	var state_data: Variant = migrated.get("game_state", {})
	state_data = A2J.from_json(state_data)
	if not state_data is Dictionary:
		var deserialize_reason := "Save file could not be deserialized."
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": deserialize_reason}
		GameEvents.load_failed.emit(slot, deserialize_reason)
		return false

	_sync_timekeeper_from_game_state()
	var previous_state_snapshot := GameState.to_dict()
	var game_state_payload: Dictionary = state_data
	GameState.from_dict(game_state_payload)
	var runtime_issues := GameState.validate_runtime_state()
	if not runtime_issues.is_empty():
		_restore_game_state(previous_state_snapshot)
		var runtime_reason := "Save file failed runtime validation: %s" % runtime_issues[0]
		last_operation_summary = {
			"kind": "load",
			"slot": slot,
			"status": "failed",
			"reason": runtime_reason,
			"validation_issues": runtime_issues.duplicate(),
		}
		GameEvents.load_failed.emit(slot, runtime_reason)
		return false
	_sync_timekeeper_from_game_state()
	last_operation_summary = {
		"kind": "load",
		"slot": slot,
		"status": "ok",
		"schema_version": int(migrated.get("save_schema_version", SCHEMA_VERSION)),
		"updated_at": str(migrated.get("updated_at", "")),
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
	}
	GameEvents.load_completed.emit(slot)
	return true


## Returns slot metadata (playtime, save date, etc.) without full deserialize.
## Returns empty dict if slot is empty or unreadable.
func get_slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not raw_data is Dictionary:
		return {}
	var raw_payload: Dictionary = raw_data
	var slot_metadata_value: Variant = raw_payload.get("slot_metadata", {})
	if slot_metadata_value is Dictionary:
		var slot_metadata: Dictionary = slot_metadata_value
		return slot_metadata
	return {}


## Returns true if the given slot contains a valid save file.
func slot_exists(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var payload := _read_raw_payload(_slot_path(slot))
	if payload.is_empty():
		return false
	return _validate_raw_payload(payload).is_empty()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _slot_path(slot: int) -> String:
	return SAVE_FILE_TEMPLATE % slot


## Checks schema version and runs any needed migrations before loading.
func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_schema_version", 0))
	if version > SCHEMA_VERSION:
		return data
	if version <= 0:
		data["save_schema_version"] = SCHEMA_VERSION
	for field_name in OPTIONAL_SAVE_FIELDS:
		if data.has(field_name):
			continue
		match field_name:
			"created_at", "updated_at":
				data[field_name] = Time.get_datetime_string_from_system(true, true)
			"slot_metadata":
				data[field_name] = {}
	return data


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SAVE_SLOTS


func _read_raw_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw_data is Dictionary:
		var payload: Dictionary = raw_data
		return payload
	return {}


func _validate_raw_payload(data: Dictionary) -> String:
	for field_name in REQUIRED_SAVE_FIELDS:
		if not data.has(field_name):
			return "Save file is missing required field '%s'." % field_name
	var schema_version := int(data.get("save_schema_version", 0))
	if schema_version > SCHEMA_VERSION:
		return "Save file schema version %d is newer than supported version %d." % [schema_version, SCHEMA_VERSION]
	var state_data: Variant = data.get("game_state", null)
	if not state_data is Dictionary:
		return "Save file field 'game_state' must be a dictionary."
	return ""


func _restore_game_state(snapshot: Dictionary) -> void:
	GameState.from_dict(snapshot)
	_sync_timekeeper_from_game_state()


func _sync_timekeeper_from_game_state() -> void:
	if TimeKeeper != null and TimeKeeper.has_method("sync_from_game_state"):
		TimeKeeper.sync_from_game_state()


func _get_missing_runtime_classes() -> Array[String]:
	var missing: Array[String] = []
	for class_name_value in REQUIRED_RUNTIME_CLASSES:
		var runtime_class_name := str(class_name_value)
		if not A2J.object_registry.has(runtime_class_name):
			missing.append(runtime_class_name)
	return missing


func get_debug_snapshot() -> Dictionary:
	var snapshot := last_operation_summary.duplicate(true)
	snapshot["save_dir_ready"] = _save_dir_ready
	snapshot["registered_runtime_classes"] = _registered_runtime_classes.duplicate()
	snapshot["missing_runtime_classes"] = _get_missing_runtime_classes()
	return snapshot
