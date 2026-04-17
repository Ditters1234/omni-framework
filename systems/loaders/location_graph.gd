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


## Returns the connections map for a location: {direction: location_id}.
static func get_connections(location_id: String) -> Dictionary:
	var loc: Dictionary = get_location(location_id)
	var connections: Variant = loc.get("connections", {})
	if connections is Dictionary:
		return connections
	return {}


## Returns all location templates as an Array.
static func get_all_locations() -> Array:
	return DataManager.locations.values()


## Applies add/remove operations to the connections dict within a location entry.
static func _apply_connection_patch(entry: Dictionary, patch_entry: Dictionary) -> void:
	var add_connections: Variant = patch_entry.get("add_connections", {})
	var remove_connections: Variant = patch_entry.get("remove_connections", [])
	if not entry.has("connections"):
		entry["connections"] = {}
	if add_connections is Dictionary:
		for direction in add_connections.keys():
			entry["connections"][direction] = add_connections[direction]
	if remove_connections is Array:
		for direction in remove_connections:
			entry["connections"].erase(direction)