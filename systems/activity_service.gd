## ActivityService -- Coordinates activity availability and execution.
## Gameplay mutation remains delegated to ActionDispatcher, GameState, and TimeKeeper.
extends RefCounted

class_name ActivityService

const ACTIVITY_SCHEDULE_SERVICE := preload("res://systems/activity_schedule_service.gd")
const TIME_MODEL := preload("res://systems/time_model.gd")
const WEIGHTED_CHOICE_SERVICE := preload("res://systems/weighted_choice_service.gd")

const FAILURE_MISSING_ACTIVITY := "missing_activity"
const FAILURE_HIDDEN := "hidden"
const FAILURE_NOT_SCHEDULED := "not_scheduled"
const FAILURE_REQUIREMENTS := "requirements_failed"
const FAILURE_REPEAT := "repeat_blocked"
const FAILURE_COOLDOWN := "cooldown_active"
const FAILURE_WRONG_LOCATION := "wrong_location"
const FAILURE_LOCATION_LOCKED := "location_locked"
const FAILURE_ROUTE_UNAVAILABLE := "route_unavailable"
const FAILURE_INVALID_TEMPLATE := "invalid_template"
const FAILURE_EXECUTION := "execution_error"


static func get_activity_status(activity: Dictionary, context: Dictionary = {}) -> Dictionary:
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	var execution_context := _build_context(activity, context)
	var schedule_status := _get_schedule_status(activity, execution_context)
	var repeat_status := get_repeat_status(activity)
	var cooldown_status := get_cooldown_status(activity)
	var location_status := resolve_location_policy(activity, execution_context)
	var visible := is_visible(activity, execution_context)
	var requirements_passed := _conditions_pass_all(_array_value(activity.get("requirements", [])), execution_context)

	var status := {
		"activity_id": activity_id,
		"can_start": true,
		"visible": visible,
		"is_scheduled": bool(schedule_status.get("is_scheduled", false)),
		"requirements_passed": requirements_passed,
		"repeat_allowed": bool(repeat_status.get("allowed", false)),
		"cooldown_allowed": bool(cooldown_status.get("allowed", true)),
		"location_allowed": bool(location_status.get("allowed", false)),
		"failure_code": "",
		"reason": "",
		"schedule_status": schedule_status.duplicate(true),
		"repeat_status": repeat_status.duplicate(true),
		"cooldown_status": cooldown_status.duplicate(true),
		"location_status": location_status.duplicate(true),
	}

	if activity_id.is_empty():
		return _blocked_status(status, FAILURE_INVALID_TEMPLATE, "Activity template is missing activity_id.")
	if not visible:
		return _blocked_status(status, FAILURE_HIDDEN, "Activity is hidden.")
	if not bool(schedule_status.get("is_scheduled", false)):
		return _blocked_status(status, FAILURE_NOT_SCHEDULED, _schedule_reason(schedule_status))
	if not requirements_passed:
		return _blocked_status(status, FAILURE_REQUIREMENTS, "Activity requirements are not met.")
	if not bool(repeat_status.get("allowed", false)):
		return _blocked_status(status, FAILURE_REPEAT, str(repeat_status.get("reason", "Activity repeat limit has been reached.")))
	if not bool(cooldown_status.get("allowed", true)):
		return _blocked_status(status, FAILURE_COOLDOWN, str(cooldown_status.get("reason", "Activity cooldown is active.")))
	if not bool(location_status.get("allowed", false)):
		return _blocked_status(status, str(location_status.get("failure_code", FAILURE_WRONG_LOCATION)), str(location_status.get("reason", "Activity is not available at this location.")))
	return status


static func is_visible(activity: Dictionary, context: Dictionary = {}) -> bool:
	return _conditions_pass_all(_array_value(activity.get("visible_if", [])), _build_context(activity, context))


static func can_start(activity: Dictionary, context: Dictionary = {}) -> bool:
	return bool(get_activity_status(activity, context).get("can_start", false))


static func get_unavailable_reason(activity: Dictionary, context: Dictionary = {}) -> String:
	return str(get_activity_status(activity, context).get("reason", ""))


static func resolve_location_policy(activity: Dictionary, context: Dictionary = {}) -> Dictionary:
	var destination_id := str(activity.get("location_id", "")).strip_edges()
	var policy := str(activity.get("travel_policy", "")).strip_edges()
	if policy.is_empty():
		policy = "must_be_present" if not destination_id.is_empty() else "current_or_none"
	var current_location_id := str(context.get("current_location_id", GameState.current_location_id)).strip_edges()

	var base_status := {
		"allowed": true,
		"policy": policy,
		"current_location_id": current_location_id,
		"destination_location_id": destination_id,
		"travel_ticks": 0,
		"failure_code": "",
		"reason": "",
	}

	match policy:
		"ignore_location":
			return base_status
		"current_or_none":
			if destination_id.is_empty() or current_location_id == destination_id:
				return base_status
			return _blocked_location_status(base_status, FAILURE_WRONG_LOCATION, "Activity is only available at '%s'." % destination_id)
		"must_be_present":
			if destination_id.is_empty() or current_location_id == destination_id:
				return base_status
			return _blocked_location_status(base_status, FAILURE_WRONG_LOCATION, "Player must be at '%s'." % destination_id)
		"auto_travel":
			if destination_id.is_empty() or current_location_id == destination_id:
				return base_status
			var entry_status := LocationAccessService.get_entry_status(destination_id)
			if not bool(entry_status.get("can_enter", false)):
				return _blocked_location_status(base_status, FAILURE_LOCATION_LOCKED, str(entry_status.get("message", "Destination is locked.")))
			var travel_ticks := LocationGraph.get_route_travel_cost(current_location_id, destination_id)
			if travel_ticks < 0:
				return _blocked_location_status(base_status, FAILURE_ROUTE_UNAVAILABLE, "No route is available to '%s'." % destination_id)
			base_status["travel_ticks"] = travel_ticks
			return base_status
		_:
			return _blocked_location_status(base_status, FAILURE_INVALID_TEMPLATE, "Unsupported travel_policy '%s'." % policy)


static func get_repeat_status(activity: Dictionary) -> Dictionary:
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	var repeat := _dictionary_value(activity.get("repeat", {}))
	var rule := str(repeat.get("rule", "always")).strip_edges()
	var history := GameState.get_activity_history(activity_id)
	var completion_count := int(history.get("completion_count", 0))
	var completed_by_day := _dictionary_value(history.get("completed_by_day", {}))
	var today_key := str(TIME_MODEL.get_display_day())
	var completed_today := int(completed_by_day.get(today_key, 0))
	var status := {
		"allowed": true,
		"rule": rule,
		"reason": "",
		"completion_count": completion_count,
		"completed_today": completed_today,
		"max_completions": _int_value(repeat.get("max_completions", -1), -1),
		"max_completions_per_day": _int_value(repeat.get("max_completions_per_day", -1), -1),
	}

	match rule:
		"", "always", "cooldown":
			return status
		"once":
			if completion_count > 0:
				return _blocked_repeat_status(status, "Activity can only be completed once.")
		"once_per_day":
			if completed_today > 0:
				return _blocked_repeat_status(status, "Activity can only be completed once per day.")
		"limited":
			var max_completions := int(status.get("max_completions", -1))
			if max_completions >= 0 and completion_count >= max_completions:
				return _blocked_repeat_status(status, "Activity completion limit has been reached.")
		"limited_per_day":
			var max_per_day := int(status.get("max_completions_per_day", -1))
			if max_per_day >= 0 and completed_today >= max_per_day:
				return _blocked_repeat_status(status, "Activity daily completion limit has been reached.")
		_:
			return _blocked_repeat_status(status, "Unsupported repeat rule '%s'." % rule)
	return status


static func get_cooldown_status(activity: Dictionary) -> Dictionary:
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	var repeat := _dictionary_value(activity.get("repeat", {}))
	var rule := str(repeat.get("rule", "always")).strip_edges()
	var cooldown_ticks := maxi(_int_value(repeat.get("cooldown_ticks", 0), 0), 0)
	var cooldown_days := maxi(_int_value(repeat.get("cooldown_days", 0), 0), 0)
	var status := {
		"allowed": true,
		"active": false,
		"rule": rule,
		"cooldown_ticks": cooldown_ticks,
		"cooldown_days": cooldown_days,
		"remaining_ticks": 0,
		"remaining_days": 0,
		"reason": "",
	}

	if rule != "cooldown" or (cooldown_ticks <= 0 and cooldown_days <= 0):
		return status

	var history := GameState.get_activity_history(activity_id)
	var last_completed_absolute_tick := int(history.get("last_completed_absolute_tick", -1))
	var last_completed_day := int(history.get("last_completed_day", -1))
	var remaining_ticks := 0
	var remaining_days := 0
	if cooldown_ticks > 0 and last_completed_absolute_tick >= 0:
		remaining_ticks = maxi((last_completed_absolute_tick + cooldown_ticks) - TIME_MODEL.get_current_absolute_tick(), 0)
	if cooldown_days > 0 and last_completed_day >= 1:
		remaining_days = maxi((last_completed_day + cooldown_days) - TIME_MODEL.get_display_day(), 0)
	status["remaining_ticks"] = remaining_ticks
	status["remaining_days"] = remaining_days
	if remaining_ticks > 0 or remaining_days > 0:
		status["allowed"] = false
		status["active"] = true
		status["reason"] = "Activity cooldown is active."
	return status


static func build_board_rows(filters: Dictionary = {}) -> Array[Dictionary]:
	var context := _dictionary_value(filters.get("context", {}))
	var include_locked := bool(filters.get("include_locked", false))
	var include_hidden := bool(filters.get("include_hidden", false))
	var activity_filters := filters.duplicate(true)
	activity_filters.erase("context")
	activity_filters.erase("include_locked")
	activity_filters.erase("include_hidden")

	var rows: Array[Dictionary] = []
	for activity in DataManager.query_activities(activity_filters):
		var status := get_activity_status(activity, context)
		var visible := bool(status.get("visible", false))
		var can_start_activity := bool(status.get("can_start", false))
		if not visible and not include_hidden:
			continue
		if not can_start_activity and not include_locked:
			continue
		rows.append({
			"activity_id": str(activity.get("activity_id", "")),
			"display_name": str(activity.get("display_name", "")),
			"description": str(activity.get("description", "")),
			"category": str(activity.get("category", "")),
			"kind": str(activity.get("kind", "standard")),
			"location_id": str(activity.get("location_id", "")),
			"provider_entity_id": str(activity.get("provider_entity_id", "")),
			"duration_ticks": maxi(_int_value(activity.get("duration_ticks", 0), 0), 0),
			"tags": _array_value(activity.get("tags", [])).duplicate(true),
			"visible": visible,
			"can_start": can_start_activity,
			"failure_code": str(status.get("failure_code", "")),
			"reason": str(status.get("reason", "")),
			"status": status.duplicate(true),
		})
	return rows


static func execute_activity(activity_id: String, context: Dictionary = {}) -> Dictionary:
	var normalized_activity_id := activity_id.strip_edges()
	var activity := DataManager.get_activity(normalized_activity_id)
	if activity.is_empty():
		return _failure_result(normalized_activity_id, FAILURE_MISSING_ACTIVITY, "Activity '%s' does not exist." % normalized_activity_id)

	var execution_context := _build_context(activity, context)
	var status := get_activity_status(activity, execution_context)
	if not bool(status.get("can_start", false)):
		return _failure_result(normalized_activity_id, str(status.get("failure_code", FAILURE_EXECUTION)), str(status.get("reason", "Activity cannot start.")))

	var location_status := _dictionary_value(status.get("location_status", {}))
	var travel_ticks := maxi(_int_value(location_status.get("travel_ticks", 0), 0), 0)
	var destination_id := str(location_status.get("destination_location_id", "")).strip_edges()
	if str(location_status.get("policy", "")) == "auto_travel" and not destination_id.is_empty() and GameState.current_location_id != destination_id:
		GameState.travel_to(destination_id, travel_ticks)
		execution_context = _build_context(activity, context)

	var start_timing := _current_timing()
	var start_payload := _build_start_payload(activity, execution_context, start_timing, travel_ticks)
	GameState.record_activity_started(normalized_activity_id, start_payload)
	_emit_activity_event("activity_started", start_payload)
	ScriptHookService.invoke_template_hook(activity, "on_activity_start", [activity.duplicate(true), execution_context.duplicate(true)])
	ActionDispatcher.dispatch_all(_array_value(activity.get("start_actions", [])))

	var duration_ticks := maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)
	if duration_ticks > 0:
		TimeKeeper.advance_ticks(duration_ticks)

	var completion_context := _build_context(activity, context)
	var selected_outcome := _select_outcome(activity, completion_context)
	if selected_outcome.is_empty():
		ActionDispatcher.dispatch_all(_array_value(activity.get("completion_actions", [])))
	else:
		ActionDispatcher.dispatch_all(_array_value(selected_outcome.get("actions", [])))

	var completion_timing := _current_timing()
	var result := _build_success_result(activity, start_timing, completion_timing, travel_ticks, selected_outcome)
	GameState.record_activity_completed(normalized_activity_id, result)
	GameState.record_event("activity_completed", result)
	_emit_activity_event("activity_completed", result)
	ScriptHookService.invoke_template_hook(activity, "on_activity_complete", [activity.duplicate(true), result.duplicate(true)])
	ScriptHookService.request_activity_flavor(activity, result.duplicate(true))
	ScriptHookService.invoke_world_event_narration("activity_completed", [result.duplicate(true)])
	return result


static func _build_context(activity: Dictionary, context: Dictionary = {}) -> Dictionary:
	var resolved := context.duplicate(true)
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		resolved["activity_id"] = activity_id
	resolved["activity"] = activity.duplicate(true)
	resolved["category"] = str(activity.get("category", ""))
	resolved["activity_location_id"] = str(activity.get("location_id", "")).strip_edges()
	resolved["provider_entity_id"] = str(activity.get("provider_entity_id", "")).strip_edges()
	resolved["current_location_id"] = GameState.current_location_id

	var entity_id := str(resolved.get("entity_id", "player")).strip_edges()
	if entity_id.is_empty():
		entity_id = "player"
	resolved["entity_id"] = entity_id
	if not resolved.has("entity"):
		var entity := GameState.get_entity_instance(entity_id)
		if entity == null and entity_id == "player":
			entity = GameState.player as EntityInstance
		if entity != null:
			resolved["entity"] = entity

	var has_absolute_tick := resolved.has("absolute_tick")
	var has_raw_day := resolved.has("raw_day")
	var has_day := resolved.has("day")
	var absolute_tick := _int_value(resolved.get("absolute_tick", TIME_MODEL.get_current_absolute_tick()), TIME_MODEL.get_current_absolute_tick())
	var tick_of_day := _int_value(resolved.get("tick_of_day", TIME_MODEL.get_tick_of_day(absolute_tick)), TIME_MODEL.get_tick_of_day(absolute_tick))
	var raw_day := TIME_MODEL.get_day_for_absolute_tick(absolute_tick)
	if has_raw_day:
		raw_day = _int_value(resolved.get("raw_day", raw_day), raw_day)
	elif has_day and not has_absolute_tick:
		raw_day = _int_value(resolved.get("day", raw_day), raw_day)
	var display_day := TIME_MODEL.get_display_day(raw_day, tick_of_day)
	if has_day:
		display_day = _int_value(resolved.get("day", display_day), display_day)
	resolved["absolute_tick"] = absolute_tick
	resolved["tick_of_day"] = tick_of_day
	resolved["raw_day"] = raw_day
	resolved["day"] = display_day
	return resolved


static func _get_schedule_status(activity: Dictionary, context: Dictionary) -> Dictionary:
	var fallback_day := TIME_MODEL.get_day_for_absolute_tick(TIME_MODEL.get_current_absolute_tick())
	var day := _int_value(context.get("raw_day", fallback_day), fallback_day)
	var tick_of_day := _int_value(context.get("tick_of_day", TIME_MODEL.get_tick_of_day()), TIME_MODEL.get_tick_of_day())
	return ACTIVITY_SCHEDULE_SERVICE.get_schedule_status(activity, day, tick_of_day)


static func _select_outcome(activity: Dictionary, context: Dictionary = {}) -> Dictionary:
	var outcomes := _array_value(activity.get("outcomes", []))
	if outcomes.is_empty():
		return {}
	var rng_value: Variant = context.get("rng", null)
	var rng := rng_value as RandomNumberGenerator
	return WEIGHTED_CHOICE_SERVICE.pick_weighted(outcomes, context, rng)


static func _build_start_payload(activity: Dictionary, context: Dictionary, timing: Dictionary, travel_ticks: int) -> Dictionary:
	return {
		"success": true,
		"activity_id": str(activity.get("activity_id", "")),
		"display_name": str(activity.get("display_name", "")),
		"category": str(activity.get("category", "")),
		"location_id": str(activity.get("location_id", "")),
		"provider_entity_id": str(activity.get("provider_entity_id", "")),
		"entity_id": str(context.get("entity_id", "player")),
		"started_day": int(timing.get("day", 1)),
		"started_tick": int(timing.get("tick_of_day", 0)),
		"started_absolute_tick": int(timing.get("absolute_tick", 0)),
		"day": int(timing.get("day", 1)),
		"tick_of_day": int(timing.get("tick_of_day", 0)),
		"absolute_tick": int(timing.get("absolute_tick", 0)),
		"duration_ticks": maxi(_int_value(activity.get("duration_ticks", 0), 0), 0),
		"travel_ticks": travel_ticks,
	}


static func _build_success_result(activity: Dictionary, started_timing: Dictionary, completed_timing: Dictionary, travel_ticks: int, outcome: Dictionary) -> Dictionary:
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	var post_action := _dictionary_value(activity.get("post_action", {}))
	return {
		"success": true,
		"activity_id": str(activity.get("activity_id", "")),
		"display_name": str(activity.get("display_name", "")),
		"category": str(activity.get("category", "")),
		"location_id": str(activity.get("location_id", "")),
		"provider_entity_id": str(activity.get("provider_entity_id", "")),
		"outcome_id": outcome_id,
		"outcome": outcome.duplicate(true),
		"started_day": int(started_timing.get("day", 1)),
		"started_tick": int(started_timing.get("tick_of_day", 0)),
		"started_absolute_tick": int(started_timing.get("absolute_tick", 0)),
		"completed_day": int(completed_timing.get("day", 1)),
		"completed_tick": int(completed_timing.get("tick_of_day", 0)),
		"completed_absolute_tick": int(completed_timing.get("absolute_tick", 0)),
		"day": int(completed_timing.get("day", 1)),
		"tick_of_day": int(completed_timing.get("tick_of_day", 0)),
		"absolute_tick": int(completed_timing.get("absolute_tick", 0)),
		"duration_ticks": maxi(_int_value(activity.get("duration_ticks", 0), 0), 0),
		"travel_ticks": travel_ticks,
		"message": str(outcome.get("text", "")),
		"post_action": post_action,
	}


static func _current_timing() -> Dictionary:
	var absolute_tick := TIME_MODEL.get_current_absolute_tick()
	var tick_of_day := TIME_MODEL.get_tick_of_day(absolute_tick)
	var raw_day := TIME_MODEL.get_day_for_absolute_tick(absolute_tick)
	var display_day := TIME_MODEL.get_display_day(raw_day, tick_of_day)
	return {
		"absolute_tick": absolute_tick,
		"tick_of_day": tick_of_day,
		"day": display_day,
		"raw_day": raw_day,
	}


static func _blocked_status(status: Dictionary, failure_code: String, reason: String) -> Dictionary:
	var blocked := status.duplicate(true)
	blocked["can_start"] = false
	blocked["failure_code"] = failure_code
	blocked["reason"] = reason
	return blocked


static func _blocked_location_status(status: Dictionary, failure_code: String, reason: String) -> Dictionary:
	var blocked := status.duplicate(true)
	blocked["allowed"] = false
	blocked["failure_code"] = failure_code
	blocked["reason"] = reason
	return blocked


static func _blocked_repeat_status(status: Dictionary, reason: String) -> Dictionary:
	var blocked := status.duplicate(true)
	blocked["allowed"] = false
	blocked["reason"] = reason
	return blocked


static func _failure_result(activity_id: String, failure_code: String, reason: String) -> Dictionary:
	return {
		"success": false,
		"activity_id": activity_id,
		"failure_code": failure_code,
		"reason": reason,
	}


static func _schedule_reason(schedule_status: Dictionary) -> String:
	var reason := str(schedule_status.get("reason", "")).strip_edges()
	if reason.is_empty():
		return "Activity is not scheduled now."
	return "Activity is not scheduled now: %s." % reason


static func _emit_activity_event(signal_name: String, payload: Dictionary) -> void:
	if GameEvents == null:
		return
	GameEvents.emit_dynamic(signal_name, [payload.duplicate(true)])


static func _conditions_pass_all(conditions: Array, context: Dictionary = {}) -> bool:
	for condition_value in conditions:
		if not condition_value is Dictionary:
			return false
		var condition: Dictionary = condition_value
		if not ConditionEvaluator.evaluate(condition, context):
			return false
	return true


static func _array_value(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


static func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


static func _int_value(value: Variant, default_value: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(str(value))
	return default_value
