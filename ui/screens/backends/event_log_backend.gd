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
			"newest_first",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"limit": TYPE_INT,
			"domain": TYPE_STRING,
			"signal_name": TYPE_STRING,
			"newest_first": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var rows := _build_rows()
	var empty_label := _get_string_param(_params, "empty_label", "No events have been recorded.")
	return {
		"title": _get_string_param(_params, "screen_title", "Event Log"),
		"description": _get_string_param(_params, "screen_description", "Review recent engine events recorded by GameEvents."),
		"rows": rows,
		"status_text": empty_label if rows.is_empty() else "%s recent events." % str(rows.size()),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var history := GameEvents.get_event_history(
		_read_limit(),
		_get_string_param(_params, "domain", ""),
		_get_string_param(_params, "signal_name", "")
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
	if _get_bool_param(_params, "newest_first", true):
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
		parts.append(_format_arg_value(arg))
	return ", ".join(parts)


func _format_arg_value(value: Variant, depth: int = 0) -> String:
	if depth >= 2:
		return "…"

	if value is String:
		var text := str(value)
		return text if text.length() <= 80 else "%s…" % text.substr(0, 80)

	if value is int or value is float or value is bool:
		return str(value)

	if value == null:
		return "null"

	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var keys: Array = dictionary_value.keys()
		keys.sort()
		var entries: Array[String] = []
		var shown := 0
		for key in keys:
			entries.append("%s=%s" % [str(key), _format_arg_value(dictionary_value.get(key), depth + 1)])
			shown += 1
			if shown >= 4:
				break
		if keys.size() > shown:
			entries.append("…")
		return "{%s}" % ", ".join(entries)

	if value is Array:
		var array_value: Array = value
		var entries: Array[String] = []
		var shown := mini(array_value.size(), 4)
		for index in range(shown):
			entries.append(_format_arg_value(array_value[index], depth + 1))
		if array_value.size() > shown:
			entries.append("…")
		return "[%s]" % ", ".join(entries)

	if value is Object:
		var object_value: Object = value
		return "<%s>" % object_value.get_class()

	return str(value)


func _read_limit() -> int:
	return _get_int_param(_params, "limit", 50, 0)
