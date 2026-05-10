## ActivityRegistry -- Loads activities.json into DataManager.activities.
## Key field: "activity_id" (namespaced, e.g. "base:study_at_library")
extends RefCounted

class_name ActivityRegistry

const REPEAT_RULES: Array[String] = [
	"always",
	"once",
	"once_per_day",
	"limited",
	"limited_per_day",
	"cooldown",
]


static func load_additions(entries: Array) -> void:
	for activity_value in entries:
		if not activity_value is Dictionary:
			continue
		var activity: Dictionary = activity_value
		var normalized := normalize_activity(activity)
		var activity_id := str(normalized.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			continue
		DataManager.activities[activity_id] = normalized


static func apply_patch(patches: Array) -> void:
	for patch_value in patches:
		if not patch_value is Dictionary:
			continue
		var patch: Dictionary = patch_value
		var target := str(patch.get("target", "")).strip_edges()
		if target.is_empty() or not DataManager.activities.has(target):
			continue
		var entry_value: Variant = DataManager.activities.get(target, {})
		if not entry_value is Dictionary:
			continue
		var entry_source: Dictionary = entry_value
		var entry: Dictionary = entry_source.duplicate(true)
		DataManager._apply_set_operations(entry, patch)
		if patch.has("set_schedule"):
			entry["schedule"] = _duplicate_dictionary_value(patch.get("set_schedule", {}))
		if patch.has("set_repeat"):
			entry["repeat"] = _duplicate_dictionary_value(patch.get("set_repeat", {}))
		DataManager._append_array_field(entry, "tags", _array_value(patch.get("add_tags", [])))
		DataManager._remove_array_values(entry, "tags", _array_value(patch.get("remove_tags", [])))
		_apply_array_patch(entry, "requirements", patch.get("add_requirements", []), patch.get("set_requirements", null), patch.has("set_requirements"))
		_apply_array_patch(entry, "visible_if", patch.get("add_visible_if", []), patch.get("set_visible_if", null), patch.has("set_visible_if"))
		_apply_array_patch(entry, "start_actions", patch.get("add_start_actions", []), patch.get("set_start_actions", null), patch.has("set_start_actions"))
		_apply_array_patch(entry, "completion_actions", patch.get("add_completion_actions", []), patch.get("set_completion_actions", null), patch.has("set_completion_actions"))
		_apply_array_patch(entry, "failure_actions", patch.get("add_failure_actions", []), patch.get("set_failure_actions", null), patch.has("set_failure_actions"))
		_apply_array_patch(entry, "outcomes", patch.get("add_outcomes", []), patch.get("set_outcomes", null), patch.has("set_outcomes"))
		DataManager.activities[target] = normalize_activity(entry)


static func get_activity(activity_id: String) -> Dictionary:
	var activity_value: Variant = DataManager.activities.get(activity_id, {})
	if activity_value is Dictionary:
		var activity: Dictionary = activity_value
		return activity.duplicate(true)
	return {}


static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for activity_value in DataManager.activities.values():
		if activity_value is Dictionary:
			var activity: Dictionary = activity_value
			result.append(activity.duplicate(true))
	return result


static func has_activity(activity_id: String) -> bool:
	return DataManager.activities.has(activity_id)


static func validate_activity(activity: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var activity_id := str(activity.get("activity_id", "")).strip_edges()
	if activity_id.is_empty():
		issues.append("missing activity_id")
	var display_name_value: Variant = activity.get("display_name", null)
	if not (display_name_value is String) or str(display_name_value).strip_edges().is_empty():
		issues.append("missing display_name")
	var category_value: Variant = activity.get("category", null)
	if not (category_value is String) or str(category_value).strip_edges().is_empty():
		issues.append("missing category")
	var duration_value: Variant = activity.get("duration_ticks", null)
	if duration_value == null or not _is_integral_number(duration_value) or int(duration_value) < 0:
		issues.append("duration_ticks must be an integer greater than or equal to 0")
	_validate_string_field(activity, "kind", issues)
	_validate_string_field(activity, "location_id", issues, true)
	_validate_string_field(activity, "provider_entity_id", issues, true)
	_validate_string_field(activity, "travel_policy", issues)
	_validate_string_field(activity, "script_path", issues, true)
	_validate_array_field(activity, "visible_if", issues)
	_validate_array_field(activity, "requirements", issues)
	_validate_array_field(activity, "start_actions", issues)
	_validate_array_field(activity, "completion_actions", issues)
	_validate_array_field(activity, "failure_actions", issues)
	_validate_array_field(activity, "outcomes", issues)
	_validate_array_field(activity, "tags", issues)
	_validate_dictionary_field(activity, "schedule", issues)
	_validate_dictionary_field(activity, "repeat", issues)
	_validate_dictionary_field(activity, "ui", issues)
	_validate_dictionary_field(activity, "ai", issues)
	var schedule_value: Variant = activity.get("schedule", {})
	if schedule_value is Dictionary:
		var schedule: Dictionary = schedule_value
		_validate_schedule(schedule, issues)
	var repeat_value: Variant = activity.get("repeat", {})
	if repeat_value is Dictionary:
		var repeat: Dictionary = repeat_value
		_validate_repeat(repeat, issues)
	var outcomes_value: Variant = activity.get("outcomes", [])
	if outcomes_value is Array:
		var outcomes: Array = outcomes_value
		_validate_outcomes(outcomes, issues)
	return issues


static func normalize_activity(activity: Dictionary) -> Dictionary:
	var normalized := activity.duplicate(true)
	if not normalized.has("description"):
		normalized["description"] = ""
	if not normalized.has("kind"):
		normalized["kind"] = "standard"
	if not normalized.has("schedule"):
		normalized["schedule"] = {}
	if not normalized.has("visible_if"):
		normalized["visible_if"] = []
	if not normalized.has("requirements"):
		normalized["requirements"] = []
	var location_id := str(normalized.get("location_id", "")).strip_edges()
	if not normalized.has("travel_policy"):
		normalized["travel_policy"] = "must_be_present" if not location_id.is_empty() else "current_or_none"
	if not normalized.has("start_actions"):
		normalized["start_actions"] = []
	if not normalized.has("completion_actions"):
		var actions_value: Variant = normalized.get("actions", [])
		if actions_value is Array:
			var actions: Array = actions_value
			normalized["completion_actions"] = actions.duplicate(true)
		else:
			normalized["completion_actions"] = []
	if not normalized.has("failure_actions"):
		normalized["failure_actions"] = []
	if not normalized.has("outcomes"):
		normalized["outcomes"] = []
	_normalize_repeat(normalized)
	if not normalized.has("tags"):
		normalized["tags"] = []
	if not normalized.has("ui"):
		normalized["ui"] = {}
	if not normalized.has("ai"):
		normalized["ai"] = {}
	if not normalized.has("script_path") or str(normalized.get("script_path", "")).strip_edges().is_empty():
		normalized["script_path"] = str(normalized.get("script_hook", "")).strip_edges()
	return normalized


static func _normalize_repeat(activity: Dictionary) -> void:
	var repeat_value: Variant = activity.get("repeat", {})
	var repeat: Dictionary = {}
	if repeat_value is Dictionary:
		var repeat_source: Dictionary = repeat_value
		repeat = repeat_source.duplicate(true)
	if not repeat.has("rule"):
		repeat["rule"] = "always"
	if not repeat.has("max_completions"):
		repeat["max_completions"] = -1
	if not repeat.has("max_completions_per_day"):
		repeat["max_completions_per_day"] = -1
	if not repeat.has("cooldown_ticks"):
		repeat["cooldown_ticks"] = 0
	if not repeat.has("cooldown_days"):
		repeat["cooldown_days"] = 0
	activity["repeat"] = repeat


static func _apply_array_patch(entry: Dictionary, field_name: String, additions_value: Variant, set_value: Variant, has_set: bool) -> void:
	if has_set:
		entry[field_name] = _duplicate_variant(set_value)
		return
	var additions := _array_value(additions_value)
	if additions.is_empty():
		return
	if not entry.has(field_name) or not (entry[field_name] is Array):
		entry[field_name] = []
	var target_array: Array = entry[field_name]
	for addition in additions:
		target_array.append(_duplicate_variant(addition))
	entry[field_name] = target_array


static func _validate_schedule(schedule: Dictionary, issues: Array[String]) -> void:
	for array_field in ["weekdays", "days", "months", "month_tags", "day_of_month"]:
		if schedule.has(array_field) and not (schedule.get(array_field, []) is Array):
			issues.append("schedule.%s must be an array" % array_field)
	for int_field in ["start_tick", "end_tick", "start_grace_ticks", "available_after_day", "available_until_day"]:
		if schedule.has(int_field) and not _is_integral_number(schedule.get(int_field, 0)):
			issues.append("schedule.%s must be an integer" % int_field)
	if schedule.has("crosses_midnight") and not (schedule.get("crosses_midnight", false) is bool):
		issues.append("schedule.crosses_midnight must be a bool")
	if schedule.has("must_fit_window") and not (schedule.get("must_fit_window", false) is bool):
		issues.append("schedule.must_fit_window must be a bool")
	var start_value: Variant = schedule.get("start_tick", -1)
	var end_value: Variant = schedule.get("end_tick", -1)
	var has_start := schedule.has("start_tick") and _is_integral_number(start_value)
	var has_end := schedule.has("end_tick") and _is_integral_number(end_value)
	var crosses_midnight := false
	var crosses_midnight_value: Variant = schedule.get("crosses_midnight", false)
	if crosses_midnight_value is bool:
		crosses_midnight = crosses_midnight_value
	if has_start and has_end and int(end_value) < int(start_value) and not crosses_midnight:
		issues.append("schedule.end_tick cannot be less than start_tick without crosses_midnight")
	var must_fit_window := false
	var must_fit_window_value: Variant = schedule.get("must_fit_window", false)
	if must_fit_window_value is bool:
		must_fit_window = must_fit_window_value
	if must_fit_window and (not has_start or not has_end):
		issues.append("schedule.must_fit_window requires start_tick and end_tick")


static func _validate_repeat(repeat: Dictionary, issues: Array[String]) -> void:
	var rule := str(repeat.get("rule", "always")).strip_edges()
	if not REPEAT_RULES.has(rule):
		issues.append("repeat.rule has unsupported value '%s'" % rule)
	for int_field in ["max_completions", "max_completions_per_day", "cooldown_ticks", "cooldown_days"]:
		if repeat.has(int_field) and not _is_integral_number(repeat.get(int_field, 0)):
			issues.append("repeat.%s must be an integer" % int_field)


static func _validate_outcomes(outcomes: Array, issues: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	for index in range(outcomes.size()):
		var outcome_value: Variant = outcomes[index]
		var field_path := "outcomes[%d]" % index
		if not outcome_value is Dictionary:
			issues.append("%s must be an object" % field_path)
			continue
		var outcome: Dictionary = outcome_value
		var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
		if outcome_id.is_empty():
			issues.append("%s.outcome_id must be non-empty" % field_path)
		elif seen_ids.has(outcome_id):
			issues.append("%s duplicates outcome_id '%s'" % [field_path, outcome_id])
		seen_ids[outcome_id] = true
		if outcome.has("weight"):
			var weight_value: Variant = outcome.get("weight", 0.0)
			if not (weight_value is int or weight_value is float) or float(weight_value) < 0.0:
				issues.append("%s.weight must be a number greater than or equal to 0" % field_path)
		for array_field in ["conditions", "actions", "tags"]:
			if outcome.has(array_field) and not (outcome.get(array_field, []) is Array):
				issues.append("%s.%s must be an array" % [field_path, array_field])


static func _validate_string_field(activity: Dictionary, field_name: String, issues: Array[String], allow_empty: bool = false) -> void:
	if not activity.has(field_name):
		return
	var value: Variant = activity.get(field_name, "")
	if not (value is String):
		issues.append("%s must be a string" % field_name)
		return
	if not allow_empty and str(value).strip_edges().is_empty():
		issues.append("%s must be a non-empty string" % field_name)


static func _validate_array_field(activity: Dictionary, field_name: String, issues: Array[String]) -> void:
	if activity.has(field_name) and not (activity.get(field_name, []) is Array):
		issues.append("%s must be an array" % field_name)


static func _validate_dictionary_field(activity: Dictionary, field_name: String, issues: Array[String]) -> void:
	if activity.has(field_name) and not (activity.get(field_name, {}) is Dictionary):
		issues.append("%s must be an object" % field_name)


static func _array_value(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _duplicate_dictionary_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	return value


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	return value


static func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value := float(value)
		return is_equal_approx(numeric_value, roundf(numeric_value))
	return false
