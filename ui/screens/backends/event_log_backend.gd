extends "res://ui/screens/backends/backend_base.gd"

class_name OmniEventLogBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("EventLogBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"limit",
			"domain",
			"signal_name",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"limit": TYPE_INT,
			"domain": TYPE_STRING,
			"signal_name": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := str(_params.get("empty_label", "No events have been recorded."))
	return {
		"title": str(_params.get("screen_title", "Event Log")),
		"description": str(_params.get("screen_description", "Review recent engine events recorded by GameEvents.")),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s recent events." % str(rows.size()),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
	}


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var history := GameEvents.get_event_history(
		_read_limit(),
		str(_params.get("domain", "")),
		str(_params.get("signal_name", ""))
	)
	for event_value in history:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		rows.append({
			"sequence": int(event.get("sequence", 0)),
			"signal_name": str(event.get("signal_name", "")),
			"domain": str(event.get("domain", "")),
			"timestamp": str(event.get("timestamp", "")),
			"args_text": _format_args(event.get("args", [])),
			"deprecated": bool(event.get("deprecated", false)),
		})
	rows.reverse()
	return rows


func _format_args(args_value: Variant) -> String:
	if not args_value is Array:
		return ""
	var args: Array = args_value
	if args.is_empty():
		return ""
	var parts: Array[String] = []
	for arg in args:
		parts.append(str(arg))
	return ", ".join(parts)


func _read_limit() -> int:
	var limit_value: Variant = _params.get("limit", 50)
	if limit_value is int:
		return maxi(int(limit_value), 0)
	return 50
