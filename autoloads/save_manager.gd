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

var last_operation_summary: Dictionary = {}

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_save_dir()
	_register_runtime_classes()


## Creates the save directory if it doesn't exist.
func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


## Registers all runtime classes with A2J.object_registry so A2J can
## serialize and deserialize typed objects. Add new classes here as they
## are created (EntityInstance, PartInstance, QuestInstance, etc.).
func _register_runtime_classes() -> void:
	A2J.object_registry["EntityInstance"] = EntityInstance
	A2J.object_registry["PartInstance"] = PartInstance


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
	var path := _slot_path(slot)
	var existing_payload := _read_raw_payload(path)
	var payload := _build_save_payload(existing_payload)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Unable to open save file for writing."
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": reason}
		GameEvents.save_failed.emit(slot, reason)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	last_operation_summary = {
		"kind": "save",
		"slot": slot,
		"status": "ok",
		"schema_version": SCHEMA_VERSION,
		"updated_at": str(payload.get("updated_at", "")),
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

	var raw_data = JSON.parse_string(FileAccess.get_file_as_string(path))
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

	var game_state_payload: Dictionary = state_data
	GameState.from_dict(game_state_payload)
	var runtime_issues := GameState.validate_runtime_state()
	if not runtime_issues.is_empty():
		GameState.reset()
		var runtime_reason := "Save file failed runtime validation: %s" % runtime_issues[0]
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": runtime_reason}
		GameEvents.load_failed.emit(slot, runtime_reason)
		return false
	if TimeKeeper != null and TimeKeeper.has_method("sync_from_game_state"):
		TimeKeeper.sync_from_game_state()
	last_operation_summary = {
		"kind": "load",
		"slot": slot,
		"status": "ok",
		"schema_version": int(migrated.get("save_schema_version", SCHEMA_VERSION)),
		"updated_at": str(migrated.get("updated_at", "")),
	}
	GameEvents.load_completed.emit(slot)
	return true


## Returns slot metadata (playtime, save date, etc.) without full deserialize.
## Returns empty dict if slot is empty or unreadable.
func get_slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var raw_data = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not raw_data is Dictionary:
		return {}
	return raw_data.get("slot_metadata", {})


## Returns true if the given slot contains a valid save file.
func slot_exists(slot: int) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(_slot_path(slot))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _slot_path(slot: int) -> String:
	return SAVE_FILE_TEMPLATE % slot


## Checks schema version and runs any needed migrations before loading.
func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_schema_version", 0))
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
	var raw_data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw_data is Dictionary:
		var payload: Dictionary = raw_data
		return payload
	return {}


func _validate_raw_payload(data: Dictionary) -> String:
	for field_name in REQUIRED_SAVE_FIELDS:
		if not data.has(field_name):
			return "Save file is missing required field '%s'." % field_name
	return ""


func get_debug_snapshot() -> Dictionary:
	return last_operation_summary.duplicate(true)
