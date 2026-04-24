## LocationGraph — Loads locations.json into DataManager.locations.
## Key field: "location_id" (namespaced, e.g. "base:town_square")
## Tracks connections between locations for travel logic.
extends RefCounted

class_name LocationGraph


## Parses locations.json content and adds entries to DataManager.locations.
static func load_additions(data: Array) -> void:
	for location in data:
		if not location is Dictionary:
			continue
		var location_id := str(location.get("location_id", ""))
		if location_id.is_empty():
			continue
		DataManager.locations[location_id] = location.duplicate(true)


## Applies patch operations to existing location entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.locations.has(target):
			continue
		var entry: Dictionary = DataManager.locations[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		_apply_connection_patch(entry, patch_entry)
		DataManager._append_array_field(entry, "screens", patch_entry.get("add_screens", []))
		DataManager._remove_objects_by_key(entry, "screens", "tab_id", patch_entry.get("remove_screens", []))
		DataManager._modify_objects_by_key(entry, "screens", "tab_id", patch_entry.get("modify_screen", []))
		DataManager.locations[target] = entry


## Returns a location template by id, or empty Dictionary if not found.
static func get_location(location_id: String) -> Dictionary:
	return DataManager.locations.get(location_id, {})


## Returns the connections map for a location: {target_location_id: travel_cost}.
static func get_connections(location_id: String) -> Dictionary:
	var loc: Dictionary = get_location(location_id)
	var connections: Variant = loc.get("connections", {})
	if connections is Dictionary:
		return connections
	return {}


## Returns the cheapest routed travel cost between two locations.
## Returns -1 when no route exists or either location is invalid.
static func get_route_travel_cost(from_location_id: String, to_location_id: String) -> int:
	if from_location_id.is_empty() or to_location_id.is_empty():
		return -1
	if from_location_id == to_location_id:
		return 0
	if not DataManager.locations.has(from_location_id) or not DataManager.locations.has(to_location_id):
		return -1

	var frontier: Array[String] = [from_location_id]
	var best_costs: Dictionary = {
		from_location_id: 0,
	}

	while not frontier.is_empty():
		var current_location_id := _pop_lowest_cost_location(frontier, best_costs)
		if current_location_id.is_empty():
			break
		if current_location_id == to_location_id:
			return int(best_costs.get(current_location_id, -1))

		var current_cost := int(best_costs.get(current_location_id, 0))
		var connections := get_connections(current_location_id)
		for neighbor_id_value in connections.keys():
			var neighbor_id := str(neighbor_id_value)
			if neighbor_id.is_empty():
				continue
			var connection_cost := maxi(int(connections.get(neighbor_id_value, 0)), 0)
			var candidate_cost := current_cost + connection_cost
			var known_cost := int(best_costs.get(neighbor_id, -1))
			if known_cost >= 0 and candidate_cost >= known_cost:
				continue
			best_costs[neighbor_id] = candidate_cost
			if not frontier.has(neighbor_id):
				frontier.append(neighbor_id)

	return -1


## Returns all location templates as an Array.
static func get_all_locations() -> Array:
	return DataManager.locations.values()


static func _pop_lowest_cost_location(frontier: Array[String], best_costs: Dictionary) -> String:
	if frontier.is_empty():
		return ""

	var best_index := 0
	var best_location_id := frontier[0]
	var best_cost := int(best_costs.get(best_location_id, 0))
	for index in range(1, frontier.size()):
		var candidate_location_id := frontier[index]
		var candidate_cost := int(best_costs.get(candidate_location_id, 0))
		if candidate_cost < best_cost:
			best_index = index
			best_location_id = candidate_location_id
			best_cost = candidate_cost

	frontier.remove_at(best_index)
	return best_location_id


## Applies add/remove operations to the connections dict within a location entry.
static func _apply_connection_patch(entry: Dictionary, patch_entry: Dictionary) -> void:
	var add_connections: Variant = patch_entry.get("add_connections", {})
	var remove_connections: Variant = patch_entry.get("remove_connections", [])
	if not entry.has("connections"):
		entry["connections"] = {}
	if add_connections is Dictionary:
		for target_location_id in add_connections.keys():
			entry["connections"][target_location_id] = add_connections[target_location_id]
	if remove_connections is Array:
		for direction in remove_connections:
			entry["connections"].erase(direction)
