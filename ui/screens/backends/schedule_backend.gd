extends "res://ui/screens/backends/backend_base.gd"

class_name OmniScheduleBackend

const ACTIVITY_SCHEDULE_SERVICE := preload("res://systems/activity_schedule_service.gd")
const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const TIME_MODEL := preload("res://systems/time_model.gd")

const STATUS_ELAPSED := "elapsed"
const STATUS_ACTIVE := "active"
const STATUS_UPCOMING := "upcoming"
const STATUS_LOCKED := "locked"
const STATUS_HIDDEN := "hidden"

const VIEW_DAY := "day"
const VIEW_RANGE := "range"
const VIEW_WEEK := "week"
const VIEW_MONTH := "month"

var _params: Dictionary = {}
var _selected_slot_id: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ScheduleBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"view_mode",
			"day_range",
			"categories",
			"tags",
			"tags_all",
			"location_filter",
			"show_past",
			"group_by",
			"empty_label",
			"cancel_label",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"view_mode": TYPE_STRING,
			"day_range": TYPE_INT,
			"categories": TYPE_ARRAY,
			"tags": TYPE_ARRAY,
			"tags_all": TYPE_ARRAY,
			"location_filter": TYPE_STRING,
			"show_past": TYPE_BOOL,
			"group_by": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
		},
		"array_element_types": {
			"categories": TYPE_STRING,
			"tags": TYPE_STRING,
			"tags_all": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_slot_id = ""


func build_view_model() -> Dictionary:
	var day_span := _resolve_range()
	var slots := _build_slots(int(day_span.get("from_day", TIME_MODEL.get_display_day())), int(day_span.get("to_day", TIME_MODEL.get_display_day())))
	_select_first_slot_if_needed(slots)
	_apply_selected_flags(slots)
	var selected_slot := _get_selected_slot(slots)
	var empty_label := _get_string_param(_params, "empty_label", "No scheduled activities are visible for this view.")
	return {
		"title": _get_string_param(_params, "screen_title", "Schedule"),
		"view_mode": _get_view_mode(),
		"datetime_text": TIME_MODEL.format_datetime(),
		"range_text": _build_range_text(day_span),
		"from_day": int(day_span.get("from_day", 1)),
		"to_day": int(day_span.get("to_day", 1)),
		"group_by": _get_group_by(),
		"groups": _build_groups(slots),
		"slots": slots,
		"selected_slot_id": _selected_slot_id,
		"selected_slot": selected_slot.duplicate(true),
		"status_text": _build_status_text(slots, selected_slot, empty_label),
		"empty_label": empty_label,
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
	}


func select_slot(slot_id: String) -> void:
	_selected_slot_id = slot_id.strip_edges()


func _build_slots(from_day: int, to_day: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var show_past := _get_bool_param(_params, "show_past", false)
	var query_filters := _build_query_filters()
	for activity in DataManager.query_activities(query_filters):
		var expanded_slots := ACTIVITY_SCHEDULE_SERVICE.expand_slots(activity, from_day, to_day)
		for slot_value in expanded_slots:
			var slot := _build_slot(activity, slot_value)
			if slot.is_empty():
				continue
			var slot_status := str(slot.get("status", ""))
			if slot_status == STATUS_HIDDEN:
				continue
			if slot_status == STATUS_ELAPSED and not show_past:
				continue
			slots.append(slot)
	slots.sort_custom(_sort_slots)
	return slots


func _build_query_filters() -> Dictionary:
	var filters: Dictionary = {}
	var categories := _string_array(_params.get("categories", []))
	if not categories.is_empty():
		filters["categories"] = categories
	var tags := _string_array(_params.get("tags", []))
	if not tags.is_empty():
		filters["tags"] = tags
	var tags_all := _string_array(_params.get("tags_all", []))
	if not tags_all.is_empty():
		filters["tags_all"] = tags_all
	var location_filter := _resolve_location_filter()
	if not location_filter.is_empty():
		filters["location_id"] = location_filter
	return filters


func _build_slot(activity: Dictionary, slot: Dictionary) -> Dictionary:
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	if activity_id.is_empty():
		return {}
	var schedule := _read_dictionary(activity.get("schedule", {}))
	var schedule_is_empty := schedule.is_empty()
	var raw_day := _int_value(slot.get("day", TIME_MODEL.get_display_day()), TIME_MODEL.get_display_day())
	var display_day := _int_value(slot.get("display_day", raw_day), raw_day)
	var start_tick := -1 if schedule_is_empty else _int_value(slot.get("tick_of_day", -1), -1)
	var status_tick := 0 if start_tick < 0 else start_tick
	var absolute_tick := TIME_MODEL.get_absolute_tick(raw_day, status_tick)
	var end_tick := _resolve_end_tick(activity, schedule, start_tick)
	var end_absolute_tick := _resolve_end_absolute_tick(activity, schedule, raw_day, start_tick, end_tick, absolute_tick)
	var status: Dictionary = ACTIVITY_SERVICE.get_activity_status(activity, {
		"absolute_tick": absolute_tick,
		"raw_day": raw_day,
		"day": display_day,
		"tick_of_day": status_tick,
	})
	var slot_status := _resolve_slot_status(status, display_day, absolute_tick, end_absolute_tick, schedule_is_empty)
	var date := TIME_MODEL.absolute_day_to_date(display_day)
	return {
		"slot_id": _build_slot_id(activity_id, display_day, start_tick),
		"activity_id": activity_id,
		"display_name": str(activity.get("display_name", BACKEND_HELPERS.humanize_id(activity_id))),
		"description": str(activity.get("description", "")),
		"category": str(activity.get("category", "")),
		"category_label": _get_category_label(str(activity.get("category", ""))),
		"kind": str(activity.get("kind", "standard")),
		"location_id": str(activity.get("location_id", "")).strip_edges(),
		"location_name": _get_location_name(str(activity.get("location_id", "")).strip_edges()),
		"provider_entity_id": str(activity.get("provider_entity_id", "")).strip_edges(),
		"provider_name": _get_provider_name(str(activity.get("provider_entity_id", "")).strip_edges()),
		"absolute_day": display_day,
		"raw_day": raw_day,
		"date_text": TIME_MODEL.format_date(display_day),
		"weekday": str(date.get("weekday", "")),
		"month_id": str(date.get("month_id", "")),
		"month_name": str(date.get("month_name", "")),
		"day_of_month": int(date.get("day_of_month", 0)),
		"start_tick": start_tick,
		"end_tick": end_tick,
		"absolute_tick": absolute_tick,
		"end_absolute_tick": end_absolute_tick,
		"time_text": _build_time_text(start_tick, end_tick),
		"duration_ticks": maxi(_int_value(activity.get("duration_ticks", 0), 0), 0),
		"duration_text": _format_duration(maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)),
		"status": slot_status,
		"reason": _build_slot_reason(slot_status, status),
		"selected": false,
		"raw_activity": activity.duplicate(true),
	}


func _resolve_slot_status(status: Dictionary, display_day: int, absolute_tick: int, end_absolute_tick: int, schedule_is_empty: bool) -> String:
	if not bool(status.get("visible", false)):
		return STATUS_HIDDEN
	var current_absolute_tick := TIME_MODEL.get_current_absolute_tick()
	if schedule_is_empty:
		var current_display_day := TIME_MODEL.get_display_day()
		if display_day < current_display_day:
			return STATUS_ELAPSED
		if not bool(status.get("can_start", false)):
			return STATUS_LOCKED
		if display_day == current_display_day:
			return STATUS_ACTIVE
		return STATUS_UPCOMING
	if current_absolute_tick > end_absolute_tick:
		return STATUS_ELAPSED
	if not bool(status.get("can_start", false)):
		return STATUS_LOCKED
	if current_absolute_tick >= absolute_tick and current_absolute_tick <= end_absolute_tick:
		return STATUS_ACTIVE
	return STATUS_UPCOMING


func _resolve_end_tick(activity: Dictionary, schedule: Dictionary, start_tick: int) -> int:
	var end_tick := _int_value(schedule.get("end_tick", -1), -1)
	if end_tick >= 0:
		return end_tick
	if start_tick < 0:
		return -1
	var duration_ticks := maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)
	if duration_ticks <= 0:
		return start_tick
	return posmod(start_tick + duration_ticks, TIME_MODEL.get_ticks_per_day())


func _resolve_end_absolute_tick(activity: Dictionary, schedule: Dictionary, raw_day: int, start_tick: int, end_tick: int, absolute_tick: int) -> int:
	if start_tick < 0:
		return TIME_MODEL.get_absolute_tick(raw_day, TIME_MODEL.get_ticks_per_day() - 1)
	if schedule.has("end_tick") and end_tick >= 0:
		var end_day := raw_day
		if _get_bool_value(schedule.get("crosses_midnight", false), false) and end_tick < start_tick:
			end_day += 1
		return TIME_MODEL.get_absolute_tick(end_day, end_tick)
	var duration_ticks := maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)
	return absolute_tick + duration_ticks


func _build_groups(slots: Array[Dictionary]) -> Array[Dictionary]:
	var group_by := _get_group_by()
	var groups_by_id: Dictionary = {}
	var group_order: Array[String] = []
	for slot in slots:
		var group_id := _get_group_id(slot, group_by)
		if not groups_by_id.has(group_id):
			groups_by_id[group_id] = {
				"group_id": group_id,
				"label": _get_group_label(slot, group_by),
				"slots": [],
			}
			group_order.append(group_id)
		var group_value: Variant = groups_by_id.get(group_id, {})
		if group_value is Dictionary:
			var group: Dictionary = group_value
			var slot_values: Array = group.get("slots", [])
			slot_values.append(slot.duplicate(true))
			group["slots"] = slot_values
	var groups: Array[Dictionary] = []
	for group_id in group_order:
		var group_value: Variant = groups_by_id.get(group_id, {})
		if group_value is Dictionary:
			var group: Dictionary = group_value
			groups.append(group.duplicate(true))
	return groups


func _get_group_id(slot: Dictionary, group_by: String) -> String:
	match group_by:
		"category":
			return str(slot.get("category", "uncategorized"))
		"location":
			var location_id := str(slot.get("location_id", "")).strip_edges()
			return location_id if not location_id.is_empty() else "anywhere"
		"status":
			return str(slot.get("status", "unknown"))
		"none":
			return "all"
	return str(slot.get("absolute_day", 1))


func _get_group_label(slot: Dictionary, group_by: String) -> String:
	match group_by:
		"category":
			return str(slot.get("category_label", "Uncategorized"))
		"location":
			var location_name := str(slot.get("location_name", "")).strip_edges()
			return location_name if not location_name.is_empty() else "Anywhere"
		"status":
			return BACKEND_HELPERS.humanize_id(str(slot.get("status", "unknown")))
		"none":
			return "All Slots"
	return str(slot.get("date_text", "Day %s" % str(slot.get("absolute_day", 1))))


func _resolve_range() -> Dictionary:
	var view_mode := _get_view_mode()
	var current_day := TIME_MODEL.get_display_day()
	match view_mode:
		VIEW_RANGE:
			var day_range := _get_int_param(_params, "day_range", 7, 1)
			return {"from_day": current_day, "to_day": current_day + day_range - 1}
		VIEW_WEEK:
			var weekdays := TIME_MODEL.get_weekdays()
			var weekday := TIME_MODEL.get_weekday_for_day(current_day)
			var weekday_index := weekdays.find(weekday)
			if weekday_index < 0:
				weekday_index = 0
			var from_day := maxi(current_day - weekday_index, 1)
			return {"from_day": from_day, "to_day": from_day + weekdays.size() - 1}
		VIEW_MONTH:
			var date := TIME_MODEL.absolute_day_to_date(current_day)
			var month_id := str(date.get("month_id", ""))
			var year := int(date.get("year", 1))
			var from_day := TIME_MODEL.date_to_absolute_day(year, month_id, 1)
			var to_day := from_day + TIME_MODEL.get_month_days(month_id) - 1
			return {"from_day": from_day, "to_day": to_day}
	return {"from_day": current_day, "to_day": current_day}


func _get_view_mode() -> String:
	var view_mode := str(_params.get("view_mode", VIEW_DAY)).strip_edges()
	if [VIEW_DAY, VIEW_RANGE, VIEW_WEEK, VIEW_MONTH].has(view_mode):
		return view_mode
	return VIEW_DAY


func _get_group_by() -> String:
	var group_by := str(_params.get("group_by", "day")).strip_edges()
	if ["day", "category", "location", "status", "none"].has(group_by):
		return group_by
	return "day"


func _build_range_text(day_span: Dictionary) -> String:
	var from_day := int(day_span.get("from_day", TIME_MODEL.get_display_day()))
	var to_day := int(day_span.get("to_day", from_day))
	if from_day == to_day:
		return TIME_MODEL.format_date(from_day)
	return "%s - %s" % [TIME_MODEL.format_date(from_day), TIME_MODEL.format_date(to_day)]


func _build_time_text(start_tick: int, end_tick: int) -> String:
	if start_tick < 0:
		return "Any time"
	if end_tick >= 0 and end_tick != start_tick:
		return "%s - %s" % [TIME_MODEL.format_time(start_tick), TIME_MODEL.format_time(end_tick)]
	return TIME_MODEL.format_time(start_tick)


func _build_slot_reason(slot_status: String, status: Dictionary) -> String:
	match slot_status:
		STATUS_ELAPSED:
			return "This slot has ended."
		STATUS_LOCKED:
			return str(status.get("reason", "Activity requirements are not met."))
		STATUS_HIDDEN:
			return "Activity is hidden."
	return ""


func _build_status_text(slots: Array[Dictionary], selected_slot: Dictionary, empty_label: String) -> String:
	if slots.is_empty():
		return empty_label
	if selected_slot.is_empty():
		return "Select a schedule slot to inspect it."
	var slot_status := str(selected_slot.get("status", ""))
	match slot_status:
		STATUS_ACTIVE:
			return "%s is active now." % str(selected_slot.get("display_name", "The selected activity"))
		STATUS_UPCOMING:
			return "%s opens at %s." % [str(selected_slot.get("display_name", "The selected activity")), str(selected_slot.get("time_text", ""))]
		STATUS_LOCKED:
			return str(selected_slot.get("reason", "That slot is locked."))
		STATUS_ELAPSED:
			return "This slot has ended."
	return ""


func _select_first_slot_if_needed(slots: Array[Dictionary]) -> void:
	if slots.is_empty():
		_selected_slot_id = ""
		return
	for slot in slots:
		if str(slot.get("slot_id", "")) == _selected_slot_id:
			return
	_selected_slot_id = str(slots[0].get("slot_id", ""))


func _apply_selected_flags(slots: Array[Dictionary]) -> void:
	for slot in slots:
		slot["selected"] = str(slot.get("slot_id", "")) == _selected_slot_id


func _get_selected_slot(slots: Array[Dictionary]) -> Dictionary:
	for slot in slots:
		if str(slot.get("slot_id", "")) == _selected_slot_id:
			return slot
	return {}


func _build_slot_id(activity_id: String, day: int, start_tick: int) -> String:
	return "%s@%d:%d" % [activity_id, day, start_tick]


func _format_duration(duration_ticks: int) -> String:
	if duration_ticks <= 0:
		return "Instant"
	if duration_ticks == 1:
		return "1 tick"
	return "%d ticks" % duration_ticks


func _get_category_label(category: String) -> String:
	var labels := _read_dictionary(DataManager.get_config_value("ui.activity_category_labels", {}))
	var label_value: Variant = labels.get(category, "")
	if label_value is String and not str(label_value).strip_edges().is_empty():
		return str(label_value)
	return BACKEND_HELPERS.humanize_id(category)


func _get_location_name(location_id: String) -> String:
	if location_id.is_empty():
		return ""
	var location := DataManager.get_location(location_id)
	return str(location.get("display_name", BACKEND_HELPERS.humanize_id(location_id)))


func _get_provider_name(provider_entity_id: String) -> String:
	if provider_entity_id.is_empty():
		return ""
	var entity_template := DataManager.get_entity(provider_entity_id)
	if not entity_template.is_empty():
		return str(entity_template.get("display_name", BACKEND_HELPERS.humanize_id(provider_entity_id)))
	var entity := GameState.get_entity_instance(provider_entity_id)
	if entity != null:
		return BACKEND_HELPERS.get_entity_display_name(entity, provider_entity_id)
	return BACKEND_HELPERS.humanize_id(provider_entity_id)


func _resolve_location_filter() -> String:
	var location_filter := str(_params.get("location_filter", "")).strip_edges()
	if location_filter == "current":
		return GameState.current_location_id
	if location_filter == "all" or location_filter == "any":
		return ""
	return location_filter


func _sort_slots(a: Dictionary, b: Dictionary) -> bool:
	var day_a := _int_value(a.get("absolute_day", 0), 0)
	var day_b := _int_value(b.get("absolute_day", 0), 0)
	if day_a != day_b:
		return day_a < day_b
	var tick_a := _sort_tick_value(_int_value(a.get("start_tick", -1), -1))
	var tick_b := _sort_tick_value(_int_value(b.get("start_tick", -1), -1))
	if tick_a != tick_b:
		return tick_a < tick_b
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0


func _sort_tick_value(tick_value: int) -> int:
	return 0 if tick_value < 0 else tick_value + 1


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for item_value in values:
		var item := str(item_value).strip_edges()
		if not item.is_empty():
			result.append(item)
	return result


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}


func _int_value(value: Variant, default_value: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(str(value))
	return default_value


func _get_bool_value(value: Variant, default_value: bool) -> bool:
	if value is bool:
		return value
	return default_value
