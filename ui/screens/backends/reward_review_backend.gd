extends "res://ui/screens/backends/backend_base.gd"

class_name OmniRewardReviewBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const DEFAULT_EVENT_TYPES: Array[String] = ["quest_completed", "encounter_resolved"]

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("RewardReviewBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"limit",
			"event_types",
			"newest_first",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"limit": TYPE_INT,
			"event_types": TYPE_ARRAY,
			"newest_first": TYPE_BOOL,
		},
		"array_element_types": {
			"event_types": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := _get_string_param(_params, "empty_label", "No completed rewards have been recorded.")
	return {
		"title": _get_string_param(_params, "screen_title", "Reward Review"),
		"description": _get_string_param(_params, "screen_description", "Review recent quest and encounter rewards."),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s reward entries." % str(rows.size()),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var event_types := _read_event_types()
	var history: Array = GameState.event_history
	var limit := _get_int_param(_params, "limit", 25, 0)
	for index in range(history.size()):
		var event_value: Variant = history[index]
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type := str(event.get("event_type", ""))
		if not event_types.has(event_type):
			continue
		var payload := _read_dictionary(event.get("payload", {}))
		rows.append(_build_row(event, payload, index + 1))
	if _get_bool_param(_params, "newest_first", true):
		rows.reverse()
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows


func _build_row(event: Dictionary, payload: Dictionary, sequence: int) -> Dictionary:
	var event_type := str(event.get("event_type", ""))
	var display_name := str(payload.get("display_name", BACKEND_HELPERS.humanize_id(event_type)))
	var reward_summary := str(payload.get("reward_summary", "No rewards"))
	var description := str(payload.get("description", ""))
	return {
		"sequence": sequence,
		"event_type": event_type,
		"title": display_name,
		"reward_summary": reward_summary,
		"description": description,
		"day": int(event.get("day", 1)),
		"tick": int(event.get("tick", 0)),
		"payload": payload,
	}


func _read_event_types() -> Array[String]:
	var configured := _read_string_array(_params.get("event_types", []))
	if not configured.is_empty():
		return configured
	return DEFAULT_EVENT_TYPES.duplicate()


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


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
