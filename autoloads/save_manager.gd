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
	GameEvents.save_started.emit(slot)
	var path := _slot_path(slot)
	var payload := _build_save_payload()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GameEvents.save_failed.emit(slot, "Unable to open save file for writing.")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	GameEvents.save_completed.emit(slot)


## Builds the full save payload dictionary from GameState.
func _build_save_payload() -> Dictionary:
	var state_payload: Variant = GameState.to_dict()
	state_payload = A2J.to_json(state_payload)
	return {
		"save_schema_version": SCHEMA_VERSION,
		"engine_version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"created_at": Time.get_datetime_string_from_system(true, true),
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
	GameEvents.load_started.emit(slot)
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		GameEvents.load_failed.emit(slot, "Save slot is empty.")
		return false

	var raw_data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw_data is Dictionary:
		GameEvents.load_failed.emit(slot, "Save file is invalid JSON.")
		return false

	var migrated := _migrate_if_needed(raw_data)
	var state_data: Variant = migrated.get("game_state", {})
	state_data = A2J.from_json(state_data)
	if not state_data is Dictionary:
		GameEvents.load_failed.emit(slot, "Save file could not be deserialized.")
		return false

	GameState.from_dict(state_data)
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
	return FileAccess.file_exists(_slot_path(slot))


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
	return data
