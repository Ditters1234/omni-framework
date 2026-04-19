extends "res://ui/screens/backends/backend_base.gd"

class_name OmniFactionReputationBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("FactionReputationBackend", {
		"required": [],
		"optional": [
			"target_entity_id",
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"known_only",
		],
		"field_types": {
			"target_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"known_only": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := str(_params.get("empty_label", "No factions are available."))
	return {
		"title": str(_params.get("screen_title", "Faction Reputation")),
		"description": str(_params.get("screen_description", "Review known factions and current standing.")),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s factions listed." % str(rows.size()),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
	}


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entity := BACKEND_HELPERS.resolve_entity_lookup(str(_params.get("target_entity_id", "player")))
	var faction_ids := _resolve_faction_ids(entity)
	for faction_id in faction_ids:
		var faction := DataManager.get_faction(faction_id)
		if faction.is_empty():
			continue
		rows.append({
			"faction_id": faction_id,
			"display_name": str(faction.get("display_name", BACKEND_HELPERS.humanize_id(faction_id))),
			"description": str(faction.get("description", "")),
			"territory_summary": _build_territory_summary(faction),
			"badge": BACKEND_HELPERS.build_faction_badge_view_model(entity, faction_id),
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _resolve_faction_ids(entity: EntityInstance) -> Array[String]:
	var known_only := _read_bool("known_only", false)
	var faction_ids: Array[String] = []
	if known_only and entity != null:
		for faction_id_value in entity.reputation.keys():
			var faction_id := str(faction_id_value)
			if not faction_id.is_empty():
				faction_ids.append(faction_id)
	else:
		for faction_id_value in DataManager.factions.keys():
			var faction_id := str(faction_id_value)
			if not faction_id.is_empty():
				faction_ids.append(faction_id)
	faction_ids.sort()
	return faction_ids


func _build_territory_summary(faction: Dictionary) -> String:
	var territory_value: Variant = faction.get("territory", faction.get("territories", []))
	if territory_value is Array:
		var territories: Array = territory_value
		if territories.is_empty():
			return ""
		var names: Array[String] = []
		for territory in territories:
			names.append(BACKEND_HELPERS.humanize_id(str(territory)))
		return "Territory: %s" % ", ".join(names)
	var territory_text := str(territory_value)
	return "" if territory_text.is_empty() else "Territory: %s" % BACKEND_HELPERS.humanize_id(territory_text)


func _read_bool(field_name: String, default_value: bool) -> bool:
	var value: Variant = _params.get(field_name, default_value)
	if value is bool:
		return bool(value)
	return default_value
