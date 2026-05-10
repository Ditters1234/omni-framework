extends "res://ui/screens/backends/backend_base.gd"

class_name OmniActivityBoardBackend

const ACTIVITY_SCHEDULE_SERVICE := preload("res://systems/activity_schedule_service.gd")
const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const TIME_MODEL := preload("res://systems/time_model.gd")

const STATUS_AVAILABLE := "available"
const STATUS_LOCKED := "locked"
const STATUS_HIDDEN := "hidden"
const STATUS_UPCOMING := "upcoming"

var _params: Dictionary = {}
var _selected_activity_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ActivityBoardBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"categories",
			"tags",
			"tags_all",
			"location_filter",
			"show_locked",
			"show_hidden",
			"show_upcoming",
			"max_upcoming_days",
			"max_upcoming_slots",
			"allow_auto_travel",
			"empty_label",
			"confirm_label",
			"cancel_label",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"categories": TYPE_ARRAY,
			"tags": TYPE_ARRAY,
			"tags_all": TYPE_ARRAY,
			"location_filter": TYPE_STRING,
			"show_locked": TYPE_BOOL,
			"show_hidden": TYPE_BOOL,
			"show_upcoming": TYPE_BOOL,
			"max_upcoming_days": TYPE_INT,
			"max_upcoming_slots": TYPE_INT,
			"allow_auto_travel": TYPE_BOOL,
			"empty_label": TYPE_STRING,
			"confirm_label": TYPE_STRING,
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
	_selected_activity_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	_select_first_row_if_needed(rows)
	_apply_selected_flags(rows)
	var selected_row := _get_selected_row(rows)
	var empty_label := _get_string_param(_params, "empty_label", "No activities are available right now.")
	return {
		"title": _get_string_param(_params, "screen_title", "Activities"),
		"description": _get_string_param(_params, "screen_description", "Choose an available activity or review what opens later."),
		"datetime_text": TIME_MODEL.format_datetime(),
		"rows": rows,
		"selected_activity_id": _selected_activity_id,
		"selected_row": selected_row.duplicate(true),
		"status_text": _build_status_text(rows, selected_row, empty_label),
		"confirm_label": _get_string_param(_params, "confirm_label", "Start"),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"confirm_enabled": _is_row_startable(selected_row),
		"empty_label": empty_label,
	}


func select_row(activity_id: String) -> void:
	_selected_activity_id = activity_id.strip_edges()
	_status_text = ""


func confirm() -> Dictionary:
	var rows := _build_rows()
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	if selected_row.is_empty():
		_status_text = "Select an activity before starting."
		return {}
	if not _is_row_startable(selected_row):
		_status_text = str(selected_row.get("reason", "That activity is not available right now."))
		return {}

	var activity_id := str(selected_row.get("activity_id", "")).strip_edges()
	var result := ACTIVITY_SERVICE.execute_activity(activity_id)
	if not bool(result.get("success", false)):
		_status_text = str(result.get("reason", "That activity could not start."))
		return {}

	var activity_name := str(result.get("display_name", selected_row.get("display_name", activity_id)))
	var result_message := str(result.get("message", "")).strip_edges()
	_status_text = result_message if not result_message.is_empty() else "Completed %s." % activity_name
	if GameEvents != null:
		GameEvents.ui_notification_requested.emit(_status_text, "info")
	return _read_dictionary(result.get("post_action", {}))


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var show_locked := _get_bool_param(_params, "show_locked", false)
	var show_hidden := _get_bool_param(_params, "show_hidden", false)
	var show_upcoming := _get_bool_param(_params, "show_upcoming", false)
	var upcoming_count := 0
	var max_upcoming_slots := _get_int_param(_params, "max_upcoming_slots", 10, 0)
	var query_filters := _build_query_filters()
	for activity in DataManager.query_activities(query_filters):
		var status: Dictionary = ACTIVITY_SERVICE.get_activity_status(activity)
		var visible := bool(status.get("visible", false))
		if not visible:
			if show_hidden:
				rows.append(_build_row(activity, status, STATUS_HIDDEN, "Activity is hidden.", {}))
			continue

		var travel_block_reason := _get_auto_travel_block_reason(status)
		if not travel_block_reason.is_empty():
			if show_locked:
				rows.append(_build_row(activity, status, STATUS_LOCKED, travel_block_reason, {}))
			continue

		if bool(status.get("can_start", false)):
			rows.append(_build_row(activity, status, STATUS_AVAILABLE, "", {}))
			continue

		var failure_code := str(status.get("failure_code", ""))
		if failure_code == ACTIVITY_SERVICE.FAILURE_NOT_SCHEDULED:
			if show_upcoming and upcoming_count < max_upcoming_slots:
				var slot := _get_next_slot(activity)
				if not slot.is_empty():
					rows.append(_build_row(activity, status, STATUS_UPCOMING, _build_upcoming_reason(slot), slot))
					upcoming_count += 1
			continue

		if show_locked:
			rows.append(_build_row(activity, status, STATUS_LOCKED, str(status.get("reason", "")), {}))

	rows.sort_custom(_sort_rows)
	return rows


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


func _build_row(activity: Dictionary, status: Dictionary, row_status: String, reason: String, slot: Dictionary) -> Dictionary:
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	var category := str(activity.get("category", ""))
	var location_id := str(activity.get("location_id", "")).strip_edges()
	var provider_entity_id := str(activity.get("provider_entity_id", "")).strip_edges()
	var schedule := _read_dictionary(activity.get("schedule", {}))
	var start_tick := _resolve_start_tick(schedule, slot)
	var end_tick := _resolve_end_tick(schedule, start_tick)
	var display_day := _resolve_display_day(slot)
	var ai_flavor_text := ScriptHookService.request_activity_flavor(activity, {
		"status": row_status,
		"day": display_day,
		"start_tick": start_tick,
	})
	return {
		"activity_id": activity_id,
		"display_name": str(activity.get("display_name", BACKEND_HELPERS.humanize_id(activity_id))),
		"description": str(activity.get("description", "")),
		"category": category,
		"category_label": _get_category_label(category),
		"category_color": _get_category_color(category),
		"kind": str(activity.get("kind", "standard")),
		"location_id": location_id,
		"location_name": _get_location_name(location_id),
		"provider_entity_id": provider_entity_id,
		"provider_name": _get_provider_name(provider_entity_id),
		"start_tick": start_tick,
		"end_tick": end_tick,
		"time_text": _build_time_text(row_status, display_day, start_tick, end_tick),
		"duration_ticks": maxi(_int_value(activity.get("duration_ticks", 0), 0), 0),
		"duration_text": _format_duration(maxi(_int_value(activity.get("duration_ticks", 0), 0), 0)),
		"status": row_status,
		"reason": reason if not reason.is_empty() else str(status.get("reason", "")),
		"button_label": _get_button_label(row_status),
		"preview_effects": _read_preview_effects(activity),
		"ai_flavor_text": ai_flavor_text,
		"can_start": row_status == STATUS_AVAILABLE,
		"selected": false,
		"raw_activity": activity.duplicate(true),
	}


func _get_next_slot(activity: Dictionary) -> Dictionary:
	var current_day := TIME_MODEL.get_day_for_absolute_tick(TIME_MODEL.get_current_absolute_tick())
	var current_tick := TIME_MODEL.get_tick_of_day()
	var max_days := _get_int_param(_params, "max_upcoming_days", 14, 0)
	return ACTIVITY_SCHEDULE_SERVICE.get_next_slot(activity, current_day, current_tick, max_days)


func _resolve_start_tick(schedule: Dictionary, slot: Dictionary) -> int:
	if not slot.is_empty():
		return _int_value(slot.get("tick_of_day", -1), -1)
	return _int_value(schedule.get("start_tick", -1), -1)


func _resolve_end_tick(schedule: Dictionary, start_tick: int) -> int:
	var end_tick := _int_value(schedule.get("end_tick", -1), -1)
	if end_tick >= 0:
		return end_tick
	return start_tick


func _resolve_display_day(slot: Dictionary) -> int:
	if slot.is_empty():
		return TIME_MODEL.get_display_day()
	return _int_value(slot.get("display_day", slot.get("day", TIME_MODEL.get_display_day())), TIME_MODEL.get_display_day())


func _build_time_text(row_status: String, display_day: int, start_tick: int, end_tick: int) -> String:
	if row_status == STATUS_UPCOMING and start_tick >= 0:
		return TIME_MODEL.format_datetime(display_day, start_tick)
	if start_tick < 0:
		return "Any time"
	if end_tick >= 0 and end_tick != start_tick:
		return "%s - %s" % [TIME_MODEL.format_time(start_tick), TIME_MODEL.format_time(end_tick)]
	return TIME_MODEL.format_time(start_tick)


func _build_upcoming_reason(slot: Dictionary) -> String:
	var display_day := _int_value(slot.get("display_day", slot.get("day", TIME_MODEL.get_display_day())), TIME_MODEL.get_display_day())
	var tick_of_day := _int_value(slot.get("tick_of_day", -1), -1)
	if tick_of_day < 0:
		return "Available later."
	return "Available %s." % TIME_MODEL.format_datetime(display_day, tick_of_day)


func _get_auto_travel_block_reason(status: Dictionary) -> String:
	if _get_bool_param(_params, "allow_auto_travel", true):
		return ""
	var location_status := _read_dictionary(status.get("location_status", {}))
	if str(location_status.get("policy", "")) != "auto_travel":
		return ""
	if _int_value(location_status.get("travel_ticks", 0), 0) <= 0:
		return ""
	return "Travel is required."


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_activity_id = ""
		return
	for row in rows:
		if str(row.get("activity_id", "")) == _selected_activity_id:
			return
	for row in rows:
		if _is_row_startable(row):
			_selected_activity_id = str(row.get("activity_id", ""))
			return
	_selected_activity_id = str(rows[0].get("activity_id", ""))


func _apply_selected_flags(rows: Array[Dictionary]) -> void:
	for row in rows:
		row["selected"] = str(row.get("activity_id", "")) == _selected_activity_id


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("activity_id", "")) == _selected_activity_id:
			return row
	return {}


func _is_row_startable(row: Dictionary) -> bool:
	return not row.is_empty() and str(row.get("status", "")) == STATUS_AVAILABLE and bool(row.get("can_start", false))


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, empty_label: String) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select an activity to inspect it."
	var status := str(selected_row.get("status", ""))
	match status:
		STATUS_AVAILABLE:
			return "Ready to start %s." % str(selected_row.get("display_name", "the selected activity"))
		STATUS_UPCOMING:
			return str(selected_row.get("reason", "That activity opens later."))
		STATUS_HIDDEN:
			return "This activity is hidden by its visibility conditions."
	return str(selected_row.get("reason", "That activity is locked."))


func _get_button_label(row_status: String) -> String:
	match row_status:
		STATUS_AVAILABLE:
			return _get_string_param(_params, "confirm_label", "Start")
		STATUS_UPCOMING:
			return "Upcoming"
		STATUS_HIDDEN:
			return "Hidden"
	return "Locked"


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


func _get_category_color(category: String) -> String:
	var colors := _read_dictionary(DataManager.get_config_value("ui.activity_category_colors", {}))
	var color_value: Variant = colors.get(category, "")
	if color_value is String:
		return str(color_value)
	return ""


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


func _read_preview_effects(activity: Dictionary) -> Array:
	var ui_data := _read_dictionary(activity.get("ui", {}))
	var preview_value: Variant = ui_data.get("preview_effects", activity.get("preview_effects", []))
	if preview_value is Array:
		var preview: Array = preview_value
		return preview.duplicate(true)
	return []


func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var rank_a := _status_rank(str(a.get("status", "")))
	var rank_b := _status_rank(str(b.get("status", "")))
	if rank_a != rank_b:
		return rank_a < rank_b
	var tick_a := _int_value(a.get("start_tick", 999999), 999999)
	var tick_b := _int_value(b.get("start_tick", 999999), 999999)
	if tick_a != tick_b:
		return tick_a < tick_b
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0


func _status_rank(status: String) -> int:
	match status:
		STATUS_AVAILABLE:
			return 0
		STATUS_LOCKED:
			return 1
		STATUS_UPCOMING:
			return 2
		STATUS_HIDDEN:
			return 3
	return 4


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
