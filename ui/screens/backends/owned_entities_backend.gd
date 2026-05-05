extends "res://ui/screens/backends/backend_base.gd"

class_name OmniOwnedEntitiesBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const DEFAULT_ASSIGNMENT_TASK_ID := "base:goto_location"

var _params: Dictionary = {}
var _selected_entity_id: String = ""
var _status_text: String = ""


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
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_entity_id = ""
	_status_text = ""


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
		"assignment_faction_id": _get_string_param(_params, "assignment_faction_id", ""),
		"assignment_provider_entity_id": _get_string_param(_params, "assignment_provider_entity_id", ""),
	}


func select_entity(entity_id: String) -> void:
	_selected_entity_id = entity_id
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
	var runtime_id := TimeKeeper.accept_task(task_id, {
		"entity_id": entity.entity_id,
		"target": location_id,
		"task_type": "TRAVEL",
		"duration": maxi(route_cost, 1),
		"allow_duplicate": true,
	})
	if runtime_id.is_empty():
		_status_text = "Unable to start that assignment."
		return
	_status_text = "Assigned %s to travel to %s." % [
		BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
		_get_location_display_name(location_id),
	]


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
		rows.append({
			"entity_id": entity.entity_id,
			"template_id": entity.template_id,
			"display_name": BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id),
			"description": str(entity.get_template().get("description", "")),
			"location_id": entity.location_id,
			"location_label": _get_location_display_name(entity.location_id),
			"active_task": active_task,
			"active_task_text": _build_task_text(active_task),
			"stat_preview_text": _build_stat_preview_text(entity),
			"inventory_count": _count_loose_inventory(entity),
			"equipped_count": entity.equipped.size(),
			"selected": entity.entity_id == _selected_entity_id,
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
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
		})
	return rows


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
		if best.is_empty() or int(task.get("remaining_ticks", 0)) < int(best.get("remaining_ticks", 0)):
			best = task.duplicate(true)
	return best


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


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, empty_label: String) -> String:
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "%s owned entities." % str(rows.size())
	return "%s selected." % str(selected_row.get("display_name", "Entity"))


func _build_stat_preview_text(entity: EntityInstance) -> String:
	var preview: Array[String] = []
	for stat_id in ["health", "stamina", "power", "armor"]:
		if not entity.has_stat(stat_id):
			continue
		preview.append("%s %s" % [BACKEND_HELPERS.humanize_id(stat_id), _format_number(entity.get_stat(stat_id))])
	if preview.is_empty():
		return "No tracked stats."
	return ", ".join(preview)


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
