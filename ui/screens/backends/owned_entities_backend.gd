extends "res://ui/screens/backends/backend_base.gd"

class_name OmniOwnedEntitiesBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const DEFAULT_ASSIGNMENT_TASK_ID := "base:goto_location"
const DEFAULT_SUMMARY_STAT_LIMIT := 4
const FILTER_ALL := "all"
const FILTER_IDLE := "idle"
const FILTER_ACTIVE := "active"
const FILTER_CURRENT_LOCATION := "current_location"
const FILTER_AWAY := "away"
const SORT_NAME := "name"
const SORT_LOCATION := "location"
const SORT_TASK := "task"
const START_MODE_REPLACE := "replace"
const START_MODE_QUEUE := "queue"
const START_MODE_PARALLEL := "parallel"

var _params: Dictionary = {}
var _selected_entity_id: String = ""
var _status_text: String = ""
var _suggested_location_id: String = ""
var _search_text: String = ""
var _status_filter: String = FILTER_ALL
var _sort_mode: String = SORT_NAME


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("OwnedEntitiesBackend", {
		"required": [],
		"optional": [
			"owner_entity_id",
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"assignment_task_template_id",
			"assignment_faction_id",
			"assignment_provider_entity_id",
			"show_discovered_locations_only",
			"replace_existing_task",
			"assignment_start_mode",
			"selected_entity_id",
			"suggested_location_id",
			"initial_status_text",
			"initial_search_text",
			"initial_filter",
			"initial_sort",
			"summary_stat_ids",
			"summary_stat_limit",
		],
		"field_types": {
			"owner_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"assignment_task_template_id": TYPE_STRING,
			"assignment_faction_id": TYPE_STRING,
			"assignment_provider_entity_id": TYPE_STRING,
			"show_discovered_locations_only": TYPE_BOOL,
			"replace_existing_task": TYPE_BOOL,
			"assignment_start_mode": TYPE_STRING,
			"selected_entity_id": TYPE_STRING,
			"suggested_location_id": TYPE_STRING,
			"initial_status_text": TYPE_STRING,
			"initial_search_text": TYPE_STRING,
			"initial_filter": TYPE_STRING,
			"initial_sort": TYPE_STRING,
			"summary_stat_ids": TYPE_ARRAY,
			"summary_stat_limit": TYPE_INT,
		},
		"array_element_types": {
			"summary_stat_ids": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_entity_id = _get_string_param(_params, "selected_entity_id", "")
	_suggested_location_id = _get_string_param(_params, "suggested_location_id", "")
	_status_text = _get_string_param(_params, "initial_status_text", "")
	_search_text = _get_string_param(_params, "initial_search_text", "")
	_status_filter = _normalize_filter(_get_string_param(_params, "initial_filter", FILTER_ALL))
	_sort_mode = _normalize_sort(_get_string_param(_params, "initial_sort", SORT_NAME))


func build_view_model() -> Dictionary:
	var owner := _resolve_owner()
	var rows := _build_rows(owner)
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	var locations := _build_location_rows(owner, selected_row)
	var empty_label := _get_string_param(_params, "empty_label", "No owned entities are available.")
	return {
		"title": _get_string_param(_params, "screen_title", "Owned Entities"),
		"description": _get_string_param(_params, "screen_description", "Inspect owned entities, send them to known locations, or assign available work."),
		"rows": rows,
		"selected_entity": selected_row,
		"locations": locations,
		"status_text": _status_text if not _status_text.is_empty() else _build_status_text(rows, selected_row, empty_label),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
		"has_selection": not selected_row.is_empty(),
		"can_assign_contract": not _get_string_param(_params, "assignment_faction_id", "").is_empty() and not selected_row.is_empty(),
		"has_assignable_destination": _has_enabled_location(locations),
		"suggested_location_id": _suggested_location_id,
		"assignment_task_template_id": _get_string_param(_params, "assignment_task_template_id", DEFAULT_ASSIGNMENT_TASK_ID),
		"assignment_faction_id": _get_string_param(_params, "assignment_faction_id", ""),
		"assignment_provider_entity_id": _get_string_param(_params, "assignment_provider_entity_id", ""),
		"owner_entity_id": _get_string_param(_params, "owner_entity_id", "player"),
		"search_text": _search_text,
		"status_filter": _status_filter,
		"sort_mode": _sort_mode,
		"filter_options": _build_filter_options(),
		"sort_options": _build_sort_options(),
	}


func select_entity(entity_id: String) -> void:
	_selected_entity_id = entity_id
	_suggested_location_id = ""
	_status_text = ""


func set_roster_controls(search_text: String, status_filter: String, sort_mode: String) -> void:
	_search_text = search_text.strip_edges()
	_status_filter = _normalize_filter(status_filter)
	_sort_mode = _normalize_sort(sort_mode)
	_status_text = ""


func assign_selected_to_location(location_id: String) -> void:
	var entity := _resolve_selected_entity()
	if entity == null:
		_status_text = "Select an owned entity first."
		return
	if location_id.is_empty() or not DataManager.has_location(location_id):
		_status_text = "Select a valid destination."
		return
	if entity.location_id == location_id:
		_status_text = "%s is already there." % BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id)
		return
	var route_cost := LocationGraph.get_route_travel_cost(entity.location_id, location_id)
	if route_cost < 0:
		_status_text = "No route is available from this entity's current location."
		return
	var task_id := _get_string_param(_params, "assignment_task_template_id", DEFAULT_ASSIGNMENT_TASK_ID)
	if not DataManager.has_task(task_id):
		_status_text = "Assignment task template '%s' is not registered." % task_id
		return
	var start_mode := _get_assignment_start_mode()
	if start_mode == START_MODE_REPLACE:
		_abandon_active_tasks_for_entity(entity.entity_id)
	var task_params: Dictionary = {
		"entity_id": entity.entity_id,
		"target": location_id,
		"task_type": "TRAVEL",
		"allow_duplicate": true,
		"queue_if_busy": start_mode == START_MODE_QUEUE,
	}
	if start_mode != START_MODE_QUEUE:
		task_params["duration"] = maxi(route_cost, 1)
	var runtime_id := TimeKeeper.accept_task(task_id, task_params)
	if runtime_id.is_empty():
		_status_text = "Unable to start that assignment."
		return
	var task_instance: Dictionary = {}
	var task_value: Variant = GameState.active_tasks.get(runtime_id, {})
	if task_value is Dictionary:
		task_instance = task_value
	var verb := "Queued" if str(task_instance.get("status", "active")) == "queued" else "Assigned"
	_status_text = "%s %s to travel to %s." % [
		verb,
		BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
		_get_location_display_name(location_id),
	]
	if GameEvents:
		GameEvents.ui_notification_requested.emit(_status_text, "info")


func recall_selected() -> void:
	var owner := _resolve_owner()
	if owner == null:
		_status_text = "The owner could not be resolved."
		return
	assign_selected_to_location(owner.location_id)


func _resolve_owner() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(_get_string_param(_params, "owner_entity_id", "player"))


func _resolve_selected_entity() -> EntityInstance:
	if _selected_entity_id.is_empty():
		return null
	return GameState.get_entity_instance(_selected_entity_id)


func _build_rows(owner: EntityInstance) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if owner == null:
		return rows
	for entity_id in owner.owned_entity_ids:
		var entity := GameState.get_entity_instance(entity_id)
		if entity == null:
			continue
		var active_task := _find_active_task(entity.entity_id)
		var queued_task_count := _count_queued_tasks(entity.entity_id)
		rows.append({
			"entity_id": entity.entity_id,
			"template_id": entity.template_id,
			"display_name": BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
			"description": str(entity.get_template().get("description", "")),
			"location_id": entity.location_id,
			"location_label": _get_location_display_name(entity.location_id),
			"active_task": active_task,
			"active_task_text": _build_task_text(active_task),
			"queued_task_count": queued_task_count,
			"queue_text": _build_queue_text(queued_task_count),
			"stat_preview_text": _build_stat_preview_text(entity),
			"inventory_count": _count_loose_inventory(entity),
			"equipped_count": entity.equipped.size(),
			"selected": entity.entity_id == _selected_entity_id,
		})
	rows = _filter_rows(rows, owner)
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return _compare_rows(a, b)
	rows.sort_custom(sort_callable)
	return rows


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_entity_id = ""
		return
	for row in rows:
		if str(row.get("entity_id", "")) == _selected_entity_id:
			return
	_selected_entity_id = str(rows[0].get("entity_id", ""))
	for index in range(rows.size()):
		rows[index]["selected"] = str(rows[index].get("entity_id", "")) == _selected_entity_id


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("entity_id", "")) == _selected_entity_id:
			return row.duplicate(true)
	return {}


func _build_location_rows(owner: EntityInstance, selected_row: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if owner == null or selected_row.is_empty():
		return rows
	var selected_location_id := str(selected_row.get("location_id", ""))
	var location_ids := _get_assignable_location_ids(owner)
	for location_id in location_ids:
		var route_cost := LocationGraph.get_route_travel_cost(selected_location_id, location_id)
		rows.append({
			"location_id": location_id,
			"display_name": _get_location_display_name(location_id),
			"route_cost": route_cost,
			"enabled": route_cost >= 0 and selected_location_id != location_id,
			"is_current": selected_location_id == location_id,
			"is_suggested": not _suggested_location_id.is_empty() and location_id == _suggested_location_id,
		})
	return rows


func _has_enabled_location(rows: Array[Dictionary]) -> bool:
	for row in rows:
		if bool(row.get("enabled", false)):
			return true
	return false


func _get_assignable_location_ids(owner: EntityInstance) -> Array[String]:
	var ids: Array[String] = []
	if _get_bool_param(_params, "show_discovered_locations_only", true):
		for location_id in owner.discovered_locations:
			if not location_id.is_empty() and DataManager.has_location(location_id) and not ids.has(location_id):
				ids.append(location_id)
	else:
		for location_id_value in DataManager.locations.keys():
			var location_id := str(location_id_value)
			if not location_id.is_empty():
				ids.append(location_id)
	ids.sort()
	return ids


func _find_active_task(entity_id: String) -> Dictionary:
	var best: Dictionary = {}
	for task_value in GameState.active_tasks.values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if str(task.get("entity_id", "")) != entity_id:
			continue
		if str(task.get("status", "active")) == "queued":
			continue
		if best.is_empty() or int(task.get("remaining_ticks", 0)) < int(best.get("remaining_ticks", 0)):
			best = task.duplicate(true)
	return best


func _count_queued_tasks(entity_id: String) -> int:
	var count := 0
	for task_value in GameState.active_tasks.values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if str(task.get("entity_id", "")) == entity_id and str(task.get("status", "active")) == "queued":
			count += 1
	return count


func _abandon_active_tasks_for_entity(entity_id: String) -> void:
	var runtime_ids: Array[String] = []
	for runtime_id_value in GameState.active_tasks.keys():
		var runtime_id := str(runtime_id_value)
		var task_value: Variant = GameState.active_tasks.get(runtime_id_value, {})
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		if str(task.get("entity_id", "")) == entity_id:
			runtime_ids.append(runtime_id)
	for runtime_id in runtime_ids:
		TimeKeeper.abandon_task(runtime_id)


func _build_task_text(task: Dictionary) -> String:
	if task.is_empty():
		return "Idle"
	var template_id := str(task.get("template_id", ""))
	var template := DataManager.get_task(template_id)
	var label := str(template.get("display_name", BACKEND_HELPERS.humanize_id(template_id)))
	var target := str(task.get("target", ""))
	if not target.is_empty():
		label = "%s to %s" % [label, _get_location_display_name(target)]
	return "%s, %s ticks remaining" % [label, str(int(task.get("remaining_ticks", 0)))]


func _build_queue_text(queued_task_count: int) -> String:
	if queued_task_count <= 0:
		return ""
	return "%d queued" % queued_task_count


func _get_assignment_start_mode() -> String:
	var mode := _get_string_param(_params, "assignment_start_mode", "").strip_edges()
	if [START_MODE_REPLACE, START_MODE_QUEUE, START_MODE_PARALLEL].has(mode):
		return mode
	if _get_bool_param(_params, "replace_existing_task", true):
		return START_MODE_REPLACE
	return START_MODE_QUEUE


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, empty_label: String) -> String:
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "%s owned entities." % str(rows.size())
	return "%s selected." % str(selected_row.get("display_name", "Entity"))


func _build_stat_preview_text(entity: EntityInstance) -> String:
	var preview: Array[String] = []
	for stat_id in _get_summary_stat_ids(entity):
		if not entity.has_stat(stat_id):
			continue
		preview.append("%s %s" % [BACKEND_HELPERS.humanize_id(stat_id), _format_number(entity.get_stat(stat_id))])
	if preview.is_empty():
		return "No tracked stats."
	return ", ".join(preview)


func _get_summary_stat_ids(entity: EntityInstance) -> Array[String]:
	var ids: Array[String] = _read_string_array(_params.get("summary_stat_ids", []))
	if ids.is_empty():
		ids = _get_entity_defined_stat_ids(entity)
	var limit := _get_int_param(_params, "summary_stat_limit", DEFAULT_SUMMARY_STAT_LIMIT, 1)
	if ids.size() <= limit:
		return ids
	return ids.slice(0, limit)


func _get_entity_defined_stat_ids(entity: EntityInstance) -> Array[String]:
	var ids: Array[String] = []
	var stat_definitions := DataManager.get_definitions("stats")
	for stat_def_value in stat_definitions:
		var stat_id := ""
		if stat_def_value is Dictionary:
			var stat_def: Dictionary = stat_def_value
			if str(stat_def.get("kind", "flat")) == "capacity":
				continue
			stat_id = str(stat_def.get("id", "")).strip_edges()
		else:
			stat_id = str(stat_def_value).strip_edges()
		if not stat_id.is_empty() and entity.has_stat(stat_id) and not ids.has(stat_id):
			ids.append(stat_id)
	for stat_key_value in entity.stats.keys():
		var stat_id := str(stat_key_value).strip_edges()
		if not stat_id.is_empty() and not ids.has(stat_id) and not stat_id.ends_with("_max"):
			ids.append(stat_id)
	return ids


func _filter_rows(rows: Array[Dictionary], owner: EntityInstance) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var query := _search_text.to_lower()
	for row in rows:
		if not _row_matches_filter(row, owner):
			continue
		if not query.is_empty() and not _row_matches_search(row, query):
			continue
		result.append(row)
	return result


func _row_matches_filter(row: Dictionary, owner: EntityInstance) -> bool:
	var active_task_value: Variant = row.get("active_task", {})
	var has_active_task := false
	if active_task_value is Dictionary:
		var active_task: Dictionary = active_task_value
		has_active_task = not active_task.is_empty()
	match _status_filter:
		FILTER_IDLE:
			return not has_active_task
		FILTER_ACTIVE:
			return has_active_task
		FILTER_CURRENT_LOCATION:
			return owner != null and str(row.get("location_id", "")) == owner.location_id
		FILTER_AWAY:
			return owner != null and str(row.get("location_id", "")) != owner.location_id
		_:
			return true


func _row_matches_search(row: Dictionary, query: String) -> bool:
	for field_name in ["display_name", "entity_id", "template_id", "location_label", "active_task_text"]:
		if str(row.get(field_name, "")).to_lower().contains(query):
			return true
	return false


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	match _sort_mode:
		SORT_LOCATION:
			var location_compare := str(a.get("location_label", "")).naturalnocasecmp_to(str(b.get("location_label", "")))
			if location_compare != 0:
				return location_compare < 0
		SORT_TASK:
			var task_compare := str(a.get("active_task_text", "")).naturalnocasecmp_to(str(b.get("active_task_text", "")))
			if task_compare != 0:
				return task_compare < 0
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0


func _build_filter_options() -> Array[Dictionary]:
	return [
		{"id": FILTER_ALL, "label": "All"},
		{"id": FILTER_IDLE, "label": "Idle"},
		{"id": FILTER_ACTIVE, "label": "Working"},
		{"id": FILTER_CURRENT_LOCATION, "label": "Here"},
		{"id": FILTER_AWAY, "label": "Away"},
	]


func _build_sort_options() -> Array[Dictionary]:
	return [
		{"id": SORT_NAME, "label": "Name"},
		{"id": SORT_LOCATION, "label": "Location"},
		{"id": SORT_TASK, "label": "Task"},
	]


func _normalize_filter(value: String) -> String:
	var normalized := value.strip_edges()
	if [FILTER_ALL, FILTER_IDLE, FILTER_ACTIVE, FILTER_CURRENT_LOCATION, FILTER_AWAY].has(normalized):
		return normalized
	return FILTER_ALL


func _normalize_sort(value: String) -> String:
	var normalized := value.strip_edges()
	if [SORT_NAME, SORT_LOCATION, SORT_TASK].has(normalized):
		return normalized
	return SORT_NAME


func _read_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry_value in values:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


func _count_loose_inventory(entity: EntityInstance) -> int:
	var count := 0
	for part_value in entity.inventory:
		var part := part_value as PartInstance
		if part != null and not part.is_equipped:
			count += 1
	return count


func _get_location_display_name(location_id: String) -> String:
	if location_id.is_empty():
		return "Unknown"
	var location := DataManager.get_location(location_id)
	return str(location.get("display_name", BACKEND_HELPERS.humanize_id(location_id)))


func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount
