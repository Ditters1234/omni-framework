## SaveManager — JSON save/load using A2J for typed, lossless round-trips.
## Saves written to user://saves/slot_N.json
## All runtime classes that need serialization must be registered
## in A2J.object_registry during _ready().
extends Node

class_name OmniSaveManager

const DEFAULT_SAVE_DIR := "user://saves/"
const TEST_SAVE_DIR_PREFIX := "user://test_saves/"
const TEST_RUN_MARKERS := ["gut_cmdln.gd", "-gexit", "-gdir=", "--test", "res://tests"]
const AUTOSAVE_SLOT := 0
const MAX_SAVE_SLOTS := 5
const SCHEMA_VERSION := 2
const REQUIRED_SAVE_FIELDS := ["game_state"]
const OPTIONAL_SAVE_FIELDS := ["save_schema_version", "created_at", "updated_at", "slot_metadata"]
const REQUIRED_RUNTIME_CLASSES := ["EntityInstance", "PartInstance"]
const REQUIRED_GAME_STATE_FIELDS := [
	"player_id",
	"entity_instances",
	"current_location_id",
	"current_tick",
	"current_day",
	"active_quests",
	"active_tasks",
	"completed_quests",
	"completed_task_templates",
	"unlocked_achievements",
	"flags",
	"achievement_stats",
	"faction_reputations",
	"discovered_recipes",
	"ai_lore_cache",
	"event_history",
	"runtime_state_buckets",
]
const SLOT_KIND_AUTOSAVE := "autosave"
const SLOT_KIND_MANUAL := "manual"

var last_operation_summary: Dictionary = {}
var _registered_runtime_classes: Array[String] = []
var _save_dir: String = DEFAULT_SAVE_DIR
var _save_dir_ready: bool = false
var _simulate_invalid_load: bool = false
var _is_test_environment: bool = false
var _test_session_save_dir: String = ""

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_is_test_environment = _detect_test_environment()
	if _is_test_environment:
		_save_dir = _get_or_create_test_session_save_dir()
	_save_dir_ready = _ensure_save_dir()
	_register_runtime_classes()
	last_operation_summary = {
		"kind": "boot",
		"status": "ok" if _save_dir_ready else "failed",
		"save_dir": get_save_directory(),
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
		"missing_runtime_classes": _get_missing_runtime_classes(),
		"is_test_environment": _is_test_environment,
	}


## Creates the save directory if it doesn't exist.
func _ensure_save_dir() -> bool:
	var make_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	return make_result == OK


func get_save_directory() -> String:
	_enforce_test_save_isolation()
	return _save_dir


func get_slot_path(slot: int) -> String:
	_enforce_test_save_isolation()
	return _slot_path(slot)


func set_save_directory_for_testing(path: String) -> bool:
	if not OS.is_debug_build():
		last_operation_summary = {
			"kind": "config",
			"status": "failed",
			"reason": "Save directory overrides are only available in debug builds.",
			"save_dir": get_save_directory(),
		}
		return false
	var normalized_path := _normalize_save_dir(path)
	if not normalized_path.begins_with(TEST_SAVE_DIR_PREFIX):
		last_operation_summary = {
			"kind": "config",
			"status": "failed",
			"reason": "Test save directories must live under %s." % TEST_SAVE_DIR_PREFIX,
			"save_dir": get_save_directory(),
		}
		return false
	_test_session_save_dir = normalized_path
	_save_dir = normalized_path
	_save_dir_ready = _ensure_save_dir()
	last_operation_summary = {
		"kind": "config",
		"status": "ok" if _save_dir_ready else "failed",
		"save_dir": get_save_directory(),
	}
	return _save_dir_ready


func reset_save_directory_for_testing() -> void:
	if _is_test_environment:
		_save_dir = _get_or_create_test_session_save_dir()
	else:
		_test_session_save_dir = ""
		_save_dir = DEFAULT_SAVE_DIR
	_save_dir_ready = _ensure_save_dir()


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
	_enforce_test_save_isolation()
	if not _is_valid_slot(slot):
		var reason := _get_invalid_slot_reason()
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": reason}
		GameEvents.save_failed.emit(slot, reason)
		return
	GameEvents.save_started.emit(slot)
	if not _save_dir_ready:
		_save_dir_ready = _ensure_save_dir()
		if not _save_dir_ready:
			var directory_reason := "Unable to create the save directory."
			last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": directory_reason}
			GameEvents.save_failed.emit(slot, directory_reason)
			return
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
	var payload := _build_save_payload(existing_payload, slot)
	var round_trip_error := _validate_save_round_trip(payload)
	if not round_trip_error.is_empty():
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": round_trip_error}
		GameEvents.save_failed.emit(slot, round_trip_error)
		return
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
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		var write_reason := "Unable to write the save file."
		last_operation_summary = {"kind": "save", "slot": slot, "status": "failed", "reason": write_reason}
		GameEvents.save_failed.emit(slot, write_reason)
		return
	last_operation_summary = {
		"kind": "save",
		"slot": slot,
		"slot_label": get_slot_label(slot),
		"status": "ok",
		"schema_version": SCHEMA_VERSION,
		"updated_at": str(payload.get("updated_at", "")),
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
	}
	GameEvents.save_completed.emit(slot)


## Builds the full save payload dictionary from GameState.
func _build_save_payload(previous_payload: Dictionary = {}, slot: int = 1) -> Dictionary:
	var state_payload: Variant = GameState.to_dict()
	state_payload = A2J.to_json(state_payload)
	var created_at := str(previous_payload.get("created_at", ""))
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(true, true)
	var location_id := GameState.current_location_id
	var location_name := _get_current_location_display_name(location_id)
	var slot_label := get_slot_label(slot)
	return {
		"save_schema_version": SCHEMA_VERSION,
		"engine_version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"created_at": created_at,
		"updated_at": Time.get_datetime_string_from_system(true, true),
		"slot_metadata": {
			"display_name": _get_default_display_name(slot),
			"day": GameState.current_day,
			"tick": GameState.current_tick,
			"playtime_seconds": _estimate_playtime_seconds(),
			"slot_kind": SLOT_KIND_AUTOSAVE if slot == AUTOSAVE_SLOT else SLOT_KIND_MANUAL,
			"slot_label": slot_label,
			"location_id": location_id,
			"location_name": location_name,
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
	_enforce_test_save_isolation()
	if not _is_valid_slot(slot):
		var invalid_reason := _get_invalid_slot_reason()
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": invalid_reason}
		GameEvents.load_failed.emit(slot, invalid_reason)
		return false
	GameEvents.load_started.emit(slot)
	if _simulate_invalid_load:
		_simulate_invalid_load = false
		var simulated_reason := "Simulated invalid load failure."
		last_operation_summary = {"kind": "load", "slot": slot, "status": "failed", "reason": simulated_reason}
		GameEvents.load_failed.emit(slot, simulated_reason)
		return false
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

	var game_state_payload: Dictionary = state_data
	
	var temp_state := OmniGameState.new()
	temp_state.from_dict(game_state_payload)
	var runtime_issues := temp_state.validate_runtime_state()
	temp_state.free()
	
	if not runtime_issues.is_empty():
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
		
	GameState.from_dict(game_state_payload)
	_sync_timekeeper_from_game_state()
	last_operation_summary = {
		"kind": "load",
		"slot": slot,
		"slot_label": get_slot_label(slot),
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
	_enforce_test_save_isolation()
	if not slot_exists(slot):
		return {}
	var raw_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not raw_data is Dictionary:
		return {}
	var raw_payload: Dictionary = raw_data
	var slot_metadata_value: Variant = raw_payload.get("slot_metadata", {})
	if slot_metadata_value is Dictionary:
		var slot_metadata: Dictionary = slot_metadata_value
		var result := slot_metadata.duplicate(true)
		result["slot"] = slot
		result["slot_label"] = str(result.get("slot_label", get_slot_label(slot)))
		result["slot_kind"] = str(result.get("slot_kind", SLOT_KIND_AUTOSAVE if slot == AUTOSAVE_SLOT else SLOT_KIND_MANUAL))
		result["created_at"] = str(raw_payload.get("created_at", ""))
		result["updated_at"] = str(raw_payload.get("updated_at", ""))
		result["save_schema_version"] = int(raw_payload.get("save_schema_version", SCHEMA_VERSION))
		return result
	return {}


## Returns true if the given slot contains a valid save file.
func slot_exists(slot: int) -> bool:
	_enforce_test_save_isolation()
	if not _is_valid_slot(slot):
		return false
	var payload := _read_raw_payload(_slot_path(slot))
	if payload.is_empty():
		return false
	return _validate_raw_payload(payload).is_empty()


func delete_game(slot: int) -> bool:
	_enforce_test_save_isolation()
	if not _is_valid_slot(slot):
		var invalid_reason := _get_invalid_slot_reason()
		last_operation_summary = {"kind": "delete", "slot": slot, "status": "failed", "reason": invalid_reason}
		return false
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		var missing_reason := "Save slot is already empty."
		last_operation_summary = {"kind": "delete", "slot": slot, "status": "failed", "reason": missing_reason}
		return false
	var delete_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if delete_error != OK:
		var delete_reason := "Unable to delete save slot %d: %s" % [slot, error_string(delete_error)]
		last_operation_summary = {"kind": "delete", "slot": slot, "status": "failed", "reason": delete_reason}
		return false
	last_operation_summary = {
		"kind": "delete",
		"slot": slot,
		"slot_label": get_slot_label(slot),
		"status": "ok",
	}
	return true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _slot_path(slot: int) -> String:
	var normalized_save_dir := _save_dir.trim_suffix("/")
	if slot == AUTOSAVE_SLOT:
		return "%s/autosave.json" % normalized_save_dir
	return "%s/slot_%d.json" % [normalized_save_dir, slot]


func _normalize_save_dir(path: String) -> String:
	var normalized_path := path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return DEFAULT_SAVE_DIR
	if not normalized_path.ends_with("/"):
		normalized_path += "/"
	return normalized_path


func _detect_test_environment() -> bool:
	for raw_arg in OS.get_cmdline_args():
		var arg := str(raw_arg)
		for marker in TEST_RUN_MARKERS:
			if arg.contains(marker):
				return true
	var stack := get_stack()
	for frame_value in stack:
		if not frame_value is Dictionary:
			continue
		var frame: Dictionary = frame_value
		var source := str(frame.get("source", ""))
		if source.begins_with("res://tests/") or source.begins_with("res://addons/gut/"):
			return true
	if get_tree() != null and get_tree().root != null:
		if get_tree().root.get_node_or_null("Gut") != null:
			return true
		if get_tree().root.find_child("*Gut*", true, false) != null:
			return true
	return false


func _get_or_create_test_session_save_dir() -> String:
	if _test_session_save_dir.is_empty():
		var timestamp := str(Time.get_unix_time_from_system()).replace(".", "_")
		_test_session_save_dir = "%sgut_%s_%s/" % [TEST_SAVE_DIR_PREFIX, OS.get_process_id(), timestamp]
	return _test_session_save_dir


func _enforce_test_save_isolation() -> void:
	if not _is_test_environment:
		_is_test_environment = _detect_test_environment()
		if not _is_test_environment:
			return
	var isolated_save_dir := _get_or_create_test_session_save_dir()
	if _save_dir == isolated_save_dir:
		return
	_save_dir = isolated_save_dir
	_save_dir_ready = _ensure_save_dir()


## Checks schema version and runs any needed migrations before loading.
func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_schema_version", 0))
	if data.has("game_state") and data["game_state"] is Dictionary:
		_migrate_game_state_defaults(data["game_state"])
	# Run any future migration steps here, keyed on version, e.g.:
	# if version < 2:
	#     _migrate_v1_to_v2(data)
	# Stamp the schema version AFTER migrations so future bumps can still detect
	# which path a save came from.
	if version != SCHEMA_VERSION:
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


func _migrate_game_state_defaults(game_state_data: Dictionary) -> void:
	if not game_state_data.has("faction_reputations"):
		game_state_data["faction_reputations"] = {}
	if not game_state_data.has("discovered_recipes"):
		game_state_data["discovered_recipes"] = []
	if not game_state_data.has("ai_lore_cache"):
		game_state_data["ai_lore_cache"] = {}
	if not game_state_data.has("event_history"):
		game_state_data["event_history"] = []
	if not game_state_data.has("runtime_state_buckets"):
		game_state_data["runtime_state_buckets"] = {}


func _is_valid_slot(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT or (slot >= 1 and slot <= MAX_SAVE_SLOTS)


func get_visible_slots() -> Array[int]:
	var slots: Array[int] = []
	slots.append(AUTOSAVE_SLOT)
	for slot in range(1, MAX_SAVE_SLOTS + 1):
		slots.append(slot)
	return slots


func get_most_recent_loadable_slot() -> int:
	var candidates := get_loadable_slots_sorted_by_recency()
	if candidates.is_empty():
		return -1
	return candidates[0]


func get_loadable_slots_sorted_by_recency() -> Array[int]:
	var slots: Array[int] = []
	for slot in get_visible_slots():
		if slot_exists(slot):
			slots.append(slot)
	slots.sort_custom(Callable(self, "_compare_slots_by_recency"))
	return slots


func _compare_slots_by_recency(left_slot: int, right_slot: int) -> bool:
	var left_updated_at := _get_slot_updated_at(left_slot)
	var right_updated_at := _get_slot_updated_at(right_slot)
	if left_updated_at == right_updated_at:
		return left_slot < right_slot
	return left_updated_at > right_updated_at


func _get_slot_updated_at(slot: int) -> String:
	var slot_info := get_slot_info(slot)
	return str(slot_info.get("updated_at", ""))


func _get_default_display_name(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return "Autosave"
	return "Day %d" % GameState.current_day


func get_slot_label(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return "Autosave"
	return "Slot %d" % slot


func _get_invalid_slot_reason() -> String:
	return "Save slot must be Autosave or between 1 and %d." % MAX_SAVE_SLOTS


func _get_current_location_display_name(location_id: String) -> String:
	if location_id.is_empty():
		return ""
	var location_template := DataManager.get_location(location_id)
	if location_template.is_empty():
		return location_id
	return str(location_template.get("display_name", location_id))


func _estimate_playtime_seconds() -> int:
	var ticks_per_day := 24
	if TimeKeeper != null and TimeKeeper.has_method("get_ticks_per_day"):
		ticks_per_day = maxi(int(TimeKeeper.get_ticks_per_day()), 1)
	return int(round(float(GameState.current_tick) * (86400.0 / float(ticks_per_day))))


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
	for state_field in REQUIRED_GAME_STATE_FIELDS:
		if not (state_data as Dictionary).has(state_field):
			return "Save file field 'game_state' is missing required field '%s'." % state_field
	return ""


func _sync_timekeeper_from_game_state() -> void:
	if TimeKeeper != null and TimeKeeper.has_method("sync_from_game_state"):
		TimeKeeper.sync_from_game_state()


func _validate_save_round_trip(payload: Dictionary) -> String:
	var encoded: Variant = A2J.to_json(payload.duplicate(true))
	var decoded: Variant = A2J.from_json(encoded)
	if not decoded is Dictionary:
		return "Save payload failed A2J round-trip validation."
	var decoded_payload: Dictionary = decoded
	var original_state: Variant = payload.get("game_state", {})
	var decoded_state: Variant = decoded_payload.get("game_state", {})
	if not original_state is Dictionary or not decoded_state is Dictionary:
		return "Save payload lost game_state during A2J round-trip validation."
	for field_name in REQUIRED_GAME_STATE_FIELDS:
		if not (decoded_state as Dictionary).has(field_name):
			return "Save payload lost game_state.%s during A2J round-trip validation." % field_name
	return ""


func get_runtime_round_trip_audit() -> Dictionary:
	var payload := _build_save_payload({}, 1)
	var encoded: Variant = A2J.to_json(payload.duplicate(true))
	var decoded: Variant = A2J.from_json(encoded)
	var missing_fields: Array[String] = []
	var original_state: Dictionary = payload.get("game_state", {})
	var decoded_state: Dictionary = decoded.get("game_state", {}) if decoded is Dictionary else {}
	for field_name in REQUIRED_GAME_STATE_FIELDS:
		if not decoded_state.has(field_name):
			missing_fields.append(field_name)
	return {
		"status": "ok" if missing_fields.is_empty() else "failed",
		"schema_version": SCHEMA_VERSION,
		"missing_fields_after_round_trip": missing_fields,
		"saved_game_state_fields": original_state.keys(),
		"registered_runtime_classes": _registered_runtime_classes.duplicate(),
		"missing_runtime_classes": _get_missing_runtime_classes(),
	}


func _get_missing_runtime_classes() -> Array[String]:
	var missing: Array[String] = []
	for class_name_value in REQUIRED_RUNTIME_CLASSES:
		var runtime_class_name := str(class_name_value)
		if not A2J.object_registry.has(runtime_class_name):
			missing.append(runtime_class_name)
	return missing


func get_debug_snapshot() -> Dictionary:
	var snapshot := last_operation_summary.duplicate(true)
	snapshot["save_dir"] = get_save_directory()
	snapshot["default_save_dir"] = DEFAULT_SAVE_DIR
	snapshot["save_dir_ready"] = _save_dir_ready
	snapshot["is_test_environment"] = _is_test_environment
	snapshot["test_session_save_dir"] = _test_session_save_dir
	snapshot["registered_runtime_classes"] = _registered_runtime_classes.duplicate()
	snapshot["missing_runtime_classes"] = _get_missing_runtime_classes()
	return snapshot
