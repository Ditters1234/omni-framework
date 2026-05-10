## ActivityScheduleService -- Pure schedule projection for activity templates.
## This service never executes activities and never mutates runtime state.
extends RefCounted

class_name ActivityScheduleService

const TIME_MODEL := preload("res://systems/time_model.gd")

const STATUS_SCHEDULED := "scheduled"
const STATUS_UNSCHEDULED := "unscheduled"


static func is_scheduled(activity: Dictionary, day: int, tick_of_day: int) -> bool:
	return bool(get_schedule_status(activity, day, tick_of_day).get("is_scheduled", false))


static func get_schedule_status(activity: Dictionary, day: int, tick_of_day: int) -> Dictionary:
	var resolved := _resolve_day_tick(day, tick_of_day)
	var resolved_day := int(resolved.get("day", 1))
	var resolved_tick := int(resolved.get("tick_of_day", 0))
	var display_day := TIME_MODEL.get_display_day(resolved_day, resolved_tick)
	var date := TIME_MODEL.absolute_day_to_date(display_day)
	var base_status := {
		"is_scheduled": true,
		"status": STATUS_SCHEDULED,
		"reason": "",
		"day": resolved_day,
		"display_day": display_day,
		"tick_of_day": resolved_tick,
		"absolute_tick": TIME_MODEL.get_absolute_tick(resolved_day, resolved_tick),
		"weekday": str(date.get("weekday", "")),
		"date": date.duplicate(true),
	}

	var schedule := _schedule_dictionary(activity)
	if schedule.is_empty():
		return base_status

	var day_reason := _get_day_filter_failure(schedule, display_day, date)
	if not day_reason.is_empty():
		return _blocked_status(base_status, day_reason)

	var window_reason := _get_window_failure(schedule, activity, resolved_tick)
	if not window_reason.is_empty():
		return _blocked_status(base_status, window_reason)

	return base_status


static func expand_slots(activity: Dictionary, from_day: int, to_day: int) -> Array[Dictionary]:
	var start_day := maxi(from_day, 1)
	var slots: Array[Dictionary] = []
	var end_day := maxi(to_day, 1)
	if end_day < start_day:
		return slots
	for day in range(start_day, end_day + 1):
		for tick_of_day in _candidate_ticks(activity):
			var status := get_schedule_status(activity, day, tick_of_day)
			if not bool(status.get("is_scheduled", false)):
				continue
			slots.append(_slot_from_status(activity, status))
	return slots


static func get_next_slot(activity: Dictionary, from_day: int = -1, from_tick: int = -1, max_days: int = 14) -> Dictionary:
	var resolved := _resolve_day_tick(from_day, from_tick)
	var start_day := int(resolved.get("day", 1))
	var start_tick := int(resolved.get("tick_of_day", 0))
	var safe_max_days := maxi(max_days, 0)
	var slots := expand_slots(activity, start_day, start_day + safe_max_days)
	var minimum_absolute_tick := TIME_MODEL.get_absolute_tick(start_day, start_tick)
	for slot in slots:
		if int(slot.get("absolute_tick", 0)) >= minimum_absolute_tick:
			return slot.duplicate(true)
	return {}


static func _slot_from_status(activity: Dictionary, status: Dictionary) -> Dictionary:
	var duration_ticks := _int_value(activity.get("duration_ticks", 0), 0)
	var tick_of_day := int(status.get("tick_of_day", 0))
	var day := int(status.get("day", 1))
	var absolute_tick := int(status.get("absolute_tick", TIME_MODEL.get_absolute_tick(day, tick_of_day)))
	return {
		"activity_id": str(activity.get("activity_id", "")),
		"category": str(activity.get("category", "")),
		"day": day,
		"display_day": int(status.get("display_day", day)),
		"tick_of_day": tick_of_day,
		"absolute_tick": absolute_tick,
		"duration_ticks": duration_ticks,
		"end_absolute_tick": absolute_tick + maxi(duration_ticks, 0),
		"weekday": str(status.get("weekday", "")),
		"date": _dictionary_value(status.get("date", {})),
		"schedule_status": status.duplicate(true),
	}


static func _get_day_filter_failure(schedule: Dictionary, display_day: int, date: Dictionary) -> String:
	var days := _int_array(schedule.get("days", []))
	if not days.is_empty() and not days.has(display_day):
		return "day"

	var after_day_value: Variant = schedule.get("available_after_day", -1)
	if _is_integral_number(after_day_value) and int(after_day_value) >= 1 and display_day < int(after_day_value):
		return "available_after_day"

	var until_day_value: Variant = schedule.get("available_until_day", -1)
	if _is_integral_number(until_day_value) and int(until_day_value) >= 1 and display_day > int(until_day_value):
		return "available_until_day"

	var weekdays := _string_array(schedule.get("weekdays", []))
	if not weekdays.is_empty() and not weekdays.has(str(date.get("weekday", ""))):
		return "weekday"

	var months := _string_array(schedule.get("months", []))
	if not months.is_empty() and not months.has(str(date.get("month_id", ""))):
		return "month"

	var month_tags := _string_array(schedule.get("month_tags", []))
	if not month_tags.is_empty() and not _contains_any_string(_string_array(date.get("month_tags", [])), month_tags):
		return "month_tag"

	var days_of_month := _int_array(schedule.get("day_of_month", []))
	if not days_of_month.is_empty() and not days_of_month.has(int(date.get("day_of_month", 0))):
		return "day_of_month"

	return ""


static func _get_window_failure(schedule: Dictionary, activity: Dictionary, tick_of_day: int) -> String:
	var start_tick := _optional_tick(schedule.get("start_tick", -1))
	var end_tick := _optional_tick(schedule.get("end_tick", -1))
	if start_tick < 0 and end_tick < 0:
		return ""

	var crosses_midnight := _bool_value(schedule.get("crosses_midnight", false), false)
	if not _is_inside_window(tick_of_day, start_tick, end_tick, crosses_midnight):
		return "time_window"

	if not _bool_value(schedule.get("must_fit_window", false), false):
		return ""

	if start_tick < 0 or end_tick < 0:
		return "must_fit_window"

	var duration_ticks := maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)
	if duration_ticks == 0:
		return ""

	if crosses_midnight:
		var ticks_per_day := TIME_MODEL.get_ticks_per_day()
		var normalized_end := end_tick + ticks_per_day
		var normalized_tick := tick_of_day
		if normalized_tick < start_tick:
			normalized_tick += ticks_per_day
		if normalized_tick + duration_ticks > normalized_end:
			return "must_fit_window"
		return ""

	if tick_of_day + duration_ticks > end_tick:
		return "must_fit_window"
	return ""


static func _is_inside_window(tick_of_day: int, start_tick: int, end_tick: int, crosses_midnight: bool) -> bool:
	if start_tick >= 0 and end_tick >= 0:
		if crosses_midnight:
			return tick_of_day >= start_tick or tick_of_day <= end_tick
		return tick_of_day >= start_tick and tick_of_day <= end_tick
	if start_tick >= 0:
		return tick_of_day >= start_tick
	return tick_of_day <= end_tick


static func _candidate_ticks(activity: Dictionary) -> Array[int]:
	var schedule := _schedule_dictionary(activity)
	var tick := _optional_tick(schedule.get("start_tick", -1))
	if tick < 0:
		tick = 0
	return [tick]


static func _blocked_status(base_status: Dictionary, reason: String) -> Dictionary:
	var blocked := base_status.duplicate(true)
	blocked["is_scheduled"] = false
	blocked["status"] = STATUS_UNSCHEDULED
	blocked["reason"] = reason
	return blocked


static func _resolve_day_tick(day: int, tick_of_day: int) -> Dictionary:
	var resolved_day := day
	var resolved_tick := tick_of_day
	if resolved_day < 1:
		resolved_day = TIME_MODEL.get_day_for_absolute_tick(TIME_MODEL.get_current_absolute_tick())
	if resolved_tick < 0:
		resolved_tick = TIME_MODEL.get_tick_of_day()
	resolved_tick = clampi(resolved_tick, 0, TIME_MODEL.get_ticks_per_day() - 1)
	return {
		"day": resolved_day,
		"tick_of_day": resolved_tick,
	}


static func _schedule_dictionary(activity: Dictionary) -> Dictionary:
	var schedule_value: Variant = activity.get("schedule", {})
	if schedule_value is Dictionary:
		var schedule: Dictionary = schedule_value
		return schedule.duplicate(true)
	return {}


static func _optional_tick(value: Variant) -> int:
	if not _is_integral_number(value):
		return -1
	var tick := int(value)
	if tick < 0:
		return -1
	return clampi(tick, 0, TIME_MODEL.get_ticks_per_day() - 1)


static func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		if _is_integral_number(entry):
			result.append(int(entry))
		elif entry is String and str(entry).is_valid_int():
			result.append(int(str(entry)))
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		var normalized := str(entry).strip_edges()
		if not normalized.is_empty():
			result.append(normalized)
	return result


static func _contains_any_string(values: Array[String], candidate_values: Array[String]) -> bool:
	for candidate_value in candidate_values:
		if values.has(candidate_value):
			return true
	return false


static func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


static func _bool_value(value: Variant, default_value: bool) -> bool:
	if value is bool:
		return value
	return default_value


static func _int_value(value: Variant, default_value: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(str(value))
	return default_value


static func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value := float(value)
		return is_equal_approx(numeric_value, roundf(numeric_value))
	return false
