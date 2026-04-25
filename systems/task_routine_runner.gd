## TaskRoutineRunner — Starts task templates from daily time windows.
##
## This autoload intentionally orchestrates TaskRunner instead of moving entities
## directly. TRAVEL durations can be resolved from LocationGraph so routine JSON
## does not need hard-coded travel costs.
extends Node

class_name OmniTaskRoutineRunner

const CONFIG_KEY := "task_routines"
const NESTED_CONFIG_KEY := "routines.task_routines"
const DEFAULT_ROUTINE_LOOP := "daily"

var _started_entry_keys: Dictionary = {}
var _last_seen_day: int = -1
var _last_evaluation_snapshot: Dictionary = {}


func _ready() -> void:
	_connect_runtime_signals()
	reset_runtime_cache()


func reset_runtime_cache() -> void:
	_started_entry_keys.clear()
	_last_seen_day = GameState.current_day
	_last_evaluation_snapshot = {}


func evaluate_current_tick() -> Array[Dictionary]:
	var routines := get_configured_routines()
	var current_day := GameState.current_day
	if current_day != _last_seen_day:
		_started_entry_keys.clear()
		_last_seen_day = current_day

	var tick_into_day := _get_ticks_into_day()
	var started_tasks: Array[Dictionary] = []
	for routine_value in routines:
		if not routine_value is Dictionary:
			continue
		var routine: Dictionary = routine_value
		if not _routine_is_enabled(routine):
			continue
		var entity_id := str(routine.get("entity_id", ""))
		if entity_id.is_empty():
			push_warning("TaskRoutineRunner: routine is missing entity_id.")
			continue
		var entity := GameState.get_entity_instance(entity_id)
		if entity == null:
			continue
		var entries_value: Variant = routine.get("entries", [])
		if not entries_value is Array:
			push_warning("TaskRoutineRunner: routine entries must be an array.")
			continue
		var entries: Array = entries_value
		for entry_index in range(entries.size()):
			var entry_value: Variant = entries[entry_index]
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			if not _entry_matches_tick(entry, tick_into_day):
				continue
			var start_key := _build_started_key(current_day, routine, entry, entry_index)
			if _started_entry_keys.has(start_key):
				continue
			var runtime_id := _start_entry_task(entity, entry)
			_started_entry_keys[start_key] = true
			if runtime_id.is_empty():
				continue
			started_tasks.append({
				"runtime_id": runtime_id,
				"entity_id": entity.entity_id,
				"routine_id": str(routine.get("routine_id", "")),
				"task_template_id": str(entry.get("task_template_id", entry.get("template_id", ""))),
				"target": _resolve_entry_target(entry),
				"tick_into_day": tick_into_day,
				"day": current_day,
			})

	_last_evaluation_snapshot = {
		"day": current_day,
		"tick_into_day": tick_into_day,
		"routine_count": routines.size(),
		"started_task_count": started_tasks.size(),
		"started_tasks": started_tasks.duplicate(true),
	}
	return started_tasks


func get_configured_routines() -> Array:
	var routines_value: Variant = DataManager.get_config_value(CONFIG_KEY, null)
	if routines_value == null:
		routines_value = DataManager.get_config_value(NESTED_CONFIG_KEY, [])
	if routines_value is Array:
		var routines: Array = routines_value
		return routines
	if routines_value is Dictionary:
		var routines_dict: Dictionary = routines_value
		return routines_dict.values()
	return []


func get_debug_snapshot() -> Dictionary:
	return {
		"day": GameState.current_day,
		"tick_into_day": _get_ticks_into_day(),
		"started_entry_key_count": _started_entry_keys.size(),
		"last_evaluation": _last_evaluation_snapshot.duplicate(true),
		"configured_routine_count": get_configured_routines().size(),
	}


func _connect_runtime_signals() -> void:
	var on_tick := Callable(self, "_on_tick_advanced")
	if GameEvents.has_signal("tick_advanced") and not GameEvents.is_connected("tick_advanced", on_tick):
		GameEvents.tick_advanced.connect(on_tick)

	var on_game_started := Callable(self, "_on_game_started")
	if GameEvents.has_signal("game_started") and not GameEvents.is_connected("game_started", on_game_started):
		GameEvents.game_started.connect(on_game_started)

	var on_load_completed := Callable(self, "_on_load_completed")
	if GameEvents.has_signal("load_completed") and not GameEvents.is_connected("load_completed", on_load_completed):
		GameEvents.load_completed.connect(on_load_completed)


func _on_tick_advanced(_tick: int) -> void:
	evaluate_current_tick()


func _on_game_started() -> void:
	reset_runtime_cache()
	evaluate_current_tick()


func _on_load_completed(_slot: int) -> void:
	reset_runtime_cache()
	evaluate_current_tick()


func _routine_is_enabled(routine: Dictionary) -> bool:
	if not bool(routine.get("enabled", true)):
		return false
	var loop_mode := str(routine.get("loop", DEFAULT_ROUTINE_LOOP))
	if loop_mode != DEFAULT_ROUTINE_LOOP:
		push_warning("TaskRoutineRunner: unsupported loop '%s'; only 'daily' is currently supported." % loop_mode)
		return false
	return true


func _entry_matches_tick(entry: Dictionary, tick_into_day: int) -> bool:
	var scheduled_tick := _read_entry_tick(entry)
	return scheduled_tick >= 0 and scheduled_tick == tick_into_day


func _read_entry_tick(entry: Dictionary) -> int:
	for field_name in ["tick", "at_tick", "tick_into_day"]:
		if entry.has(field_name):
			return int(entry.get(field_name, -1))
	return -1


func _start_entry_task(entity: EntityInstance, entry: Dictionary) -> String:
	if entity == null:
		return ""
	var template_id := str(entry.get("task_template_id", entry.get("template_id", ""))).strip_edges()
	if template_id.is_empty():
		push_warning("TaskRoutineRunner: routine entry is missing task_template_id/template_id.")
		return ""

	var params := _read_entry_task_params(entity, entry)
	params["entity_id"] = entity.entity_id
	params["allow_duplicate"] = bool(entry.get("allow_duplicate", true))
	return TimeKeeper.accept_task(template_id, params)


func _read_entry_task_params(entity: EntityInstance, entry: Dictionary) -> Dictionary:
	var params: Dictionary = {}
	var params_value: Variant = entry.get("params", {})
	if params_value is Dictionary:
		params = (params_value as Dictionary).duplicate(true)

	var resolved_target := _resolve_entry_target(entry)
	if not resolved_target.is_empty():
		params["target"] = resolved_target

	if entry.has("duration"):
		params["duration"] = int(entry.get("duration", 1))
	elif entry.has("remaining_ticks"):
		params["remaining_ticks"] = int(entry.get("remaining_ticks", 1))
	else:
		var route_cost := _resolve_world_map_route_cost(entity.location_id, resolved_target)
		if route_cost >= 0:
			params["duration"] = route_cost
			params["remaining_ticks"] = route_cost

	if entry.has("task_type"):
		params["task_type"] = str(entry.get("task_type", ""))
	if entry.has("reward"):
		params["reward"] = entry.get("reward", {})
	if entry.has("complete_sound"):
		params["complete_sound"] = str(entry.get("complete_sound", ""))

	return params


func _resolve_entry_target(entry: Dictionary) -> String:
	var explicit_target := str(entry.get("target", "")).strip_edges()
	if not explicit_target.is_empty():
		return explicit_target
	var template_id := str(entry.get("task_template_id", entry.get("template_id", ""))).strip_edges()
	if template_id.is_empty():
		return ""
	var template := DataManager.get_task(template_id)
	if template.is_empty():
		return ""
	return str(template.get("target", "")).strip_edges()


func _resolve_world_map_route_cost(from_location_id: String, to_location_id: String) -> int:
	if from_location_id.is_empty() or to_location_id.is_empty():
		return -1
	if from_location_id == to_location_id:
		return 0
	return LocationGraph.get_route_travel_cost(from_location_id, to_location_id)


func _build_started_key(day: int, routine: Dictionary, entry: Dictionary, entry_index: int) -> String:
	var routine_id := str(routine.get("routine_id", routine.get("id", routine.get("entity_id", ""))))
	var template_id := str(entry.get("task_template_id", entry.get("template_id", "")))
	var tick := _read_entry_tick(entry)
	return "%d:%s:%d:%s:%d" % [day, routine_id, entry_index, template_id, tick]


func _get_ticks_into_day() -> int:
	if TimeKeeper != null and TimeKeeper.has_method("get_ticks_into_day"):
		return int(TimeKeeper.call("get_ticks_into_day"))
	var ticks_per_day := maxi(int(DataManager.get_config_value("game.ticks_per_day", 24)), 1)
	return posmod(GameState.current_tick, ticks_per_day)
