extends "res://ui/screens/backends/backend_base.gd"

class_name OmniWorldMapBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const DEFAULT_FACTION_COLOR := "#7d8fa3"
const CURRENT_LOCATION_COLOR := "#ffd166"

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("WorldMapBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"show_travel_costs",
			"discovered_only",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"show_travel_costs": TYPE_BOOL,
			"discovered_only": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var locations := _build_location_rows()
	var edges := _build_edge_rows(locations)
	var empty_label := _get_string_param(_params, "empty_label", "No locations are available.")
	return {
		"title": _get_string_param(_params, "screen_title", "World Map"),
		"description": _get_string_param(_params, "screen_description", "Review the location graph and travel by selecting a destination."),
		"locations": locations,
		"edges": edges,
		"current_location_id": GameState.current_location_id,
		"show_travel_costs": _get_bool_param(_params, "show_travel_costs", true),
		"status_text": empty_label if locations.is_empty() else "%s locations, %s routes." % [str(locations.size()), str(edges.size())],
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}


func travel_to(location_id: String) -> Dictionary:
	if location_id.is_empty():
		return {"status": "error", "message": "No destination was selected."}
	if not DataManager.has_location(location_id):
		return {"status": "error", "message": "Location '%s' does not exist." % location_id}
	if location_id == GameState.current_location_id:
		return {"status": "ok", "message": "Already at %s." % _get_location_display_name(location_id)}
	GameState.travel_to(location_id, _get_travel_cost_to(location_id))
	return {"status": "ok", "message": "Traveled to %s." % _get_location_display_name(location_id)}


func _build_location_rows() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []
	var raw_locations: Array = LocationGraph.get_all_locations()
	for location_value in raw_locations:
		if not location_value is Dictionary:
			continue
		var location: Dictionary = location_value
		var location_id := str(location.get("location_id", ""))
		if location_id.is_empty():
			continue
		if _get_bool_param(_params, "discovered_only", false) and not _is_location_discovered(location_id):
			continue
		locations.append(location.duplicate(true))

	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", a.get("location_id", ""))).naturalnocasecmp_to(
			str(b.get("display_name", b.get("location_id", "")))
		) < 0
	locations.sort_custom(sort_callable)

	var rows: Array[Dictionary] = []
	var total := maxi(locations.size(), 1)
	for index in range(locations.size()):
		var location: Dictionary = locations[index]
		var location_id := str(location.get("location_id", ""))
		var faction_id := _resolve_location_faction_id(location_id, location)
		var faction := DataManager.get_faction(faction_id) if not faction_id.is_empty() else {}
		var faction_color := _resolve_faction_color(faction, location_id)
		rows.append({
			"location_id": location_id,
			"display_name": str(location.get("display_name", BACKEND_HELPERS.humanize_id(location_id))),
			"description": str(location.get("description", "")),
			"faction_id": faction_id,
			"faction_name": str(faction.get("display_name", BACKEND_HELPERS.humanize_id(faction_id))) if not faction_id.is_empty() else "",
			"faction_color": faction_color,
			"is_current": location_id == GameState.current_location_id,
			"is_discovered": _is_location_discovered(location_id),
			"connection_count": LocationGraph.get_connections(location_id).size(),
			"position": _resolve_location_position(location, index, total),
		})
	return rows


func _build_edge_rows(locations: Array[Dictionary]) -> Array[Dictionary]:
	var allowed_ids: Dictionary = {}
	for location in locations:
		var location_id := str(location.get("location_id", ""))
		if not location_id.is_empty():
			allowed_ids[location_id] = true

	var rows: Array[Dictionary] = []
	var seen_edges: Dictionary = {}
	for location in locations:
		var from_id := str(location.get("location_id", ""))
		if from_id.is_empty():
			continue
		var connections := LocationGraph.get_connections(from_id)
		for to_id_value in connections.keys():
			var to_id := str(to_id_value)
			if to_id.is_empty() or not allowed_ids.has(to_id):
				continue
			var edge_key := _build_edge_key(from_id, to_id)
			if seen_edges.has(edge_key):
				continue
			seen_edges[edge_key] = true
			rows.append({
				"from_id": from_id,
				"to_id": to_id,
				"travel_cost": int(connections[to_id_value]),
				"is_current_exit": from_id == GameState.current_location_id or to_id == GameState.current_location_id,
			})
	return rows


func _build_edge_key(first_id: String, second_id: String) -> String:
	if first_id.naturalnocasecmp_to(second_id) <= 0:
		return "%s|%s" % [first_id, second_id]
	return "%s|%s" % [second_id, first_id]


func _get_travel_cost_to(location_id: String) -> int:
	var connections := LocationGraph.get_connections(GameState.current_location_id)
	if not connections.has(location_id):
		return 0
	return maxi(int(connections.get(location_id, 0)), 0)


func _resolve_location_position(location: Dictionary, index: int, total: int) -> Dictionary:
	var map_position_value: Variant = location.get("map_position", {})
	if map_position_value is Dictionary:
		var map_position: Dictionary = map_position_value
		if map_position.has("x") and map_position.has("y"):
			var x_value: Variant = map_position.get("x", 0.5)
			var y_value: Variant = map_position.get("y", 0.5)
			if (x_value is int or x_value is float) and (y_value is int or y_value is float):
				return {
					"x": clampf(float(x_value), 0.05, 0.95),
					"y": clampf(float(y_value), 0.05, 0.95),
				}
	if map_position_value is Array:
		var map_position_array: Array = map_position_value
		if map_position_array.size() >= 2:
			var x_array_value: Variant = map_position_array[0]
			var y_array_value: Variant = map_position_array[1]
			if (x_array_value is int or x_array_value is float) and (y_array_value is int or y_array_value is float):
				return {
					"x": clampf(float(x_array_value), 0.05, 0.95),
					"y": clampf(float(y_array_value), 0.05, 0.95),
				}

	var angle := (TAU * float(index) / float(total)) - (PI * 0.5)
	return {
		"x": 0.5 + cos(angle) * 0.38,
		"y": 0.5 + sin(angle) * 0.38,
	}


func _resolve_location_faction_id(location_id: String, location: Dictionary) -> String:
	var explicit_faction_id := str(location.get("faction_id", ""))
	if not explicit_faction_id.is_empty():
		return explicit_faction_id
	for faction_id_value in DataManager.factions.keys():
		var faction_id := str(faction_id_value)
		var faction: Dictionary = DataManager.get_faction(faction_id)
		var territory_value: Variant = faction.get("territory", faction.get("territories", []))
		if territory_value is Array:
			var territories: Array = territory_value
			for territory_value_entry in territories:
				if str(territory_value_entry) == location_id:
					return faction_id
		elif str(territory_value) == location_id:
			return faction_id
	return ""


func _resolve_faction_color(faction: Dictionary, location_id: String) -> String:
	if location_id == GameState.current_location_id:
		return CURRENT_LOCATION_COLOR
	var color_value: Variant = faction.get("faction_color", faction.get("color", DEFAULT_FACTION_COLOR))
	var color_text := str(color_value)
	return DEFAULT_FACTION_COLOR if color_text.is_empty() else color_text


func _is_location_discovered(location_id: String) -> bool:
	var player := GameState.player as EntityInstance
	if player == null:
		return false
	return player.has_discovered_location(location_id)


func _get_location_display_name(location_id: String) -> String:
	var location := DataManager.get_location(location_id)
	return str(location.get("display_name", BACKEND_HELPERS.humanize_id(location_id)))
