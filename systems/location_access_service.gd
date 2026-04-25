## LocationAccessService — Shared travel/entry gate checks.
##
## Supports optional location fields:
##
## entry_condition: Dictionary
##   A single ConditionEvaluator block. Must pass.
##
## entry_conditions: Array[Dictionary]
##   OR logic. At least one condition block must pass.
##
## locked_message: String
##   Message shown when travel is blocked.
extends RefCounted

class_name LocationAccessService


static func can_enter_location(location_id: String) -> bool:
	return get_entry_status(location_id).get("can_enter", false)


static func get_entry_status(location_id: String) -> Dictionary:
	if location_id.is_empty():
		return {
			"can_enter": false,
			"message": "No destination was selected.",
			"location_id": location_id,
		}
	if not DataManager.has_location(location_id):
		return {
			"can_enter": false,
			"message": "Location '%s' does not exist." % location_id,
			"location_id": location_id,
		}

	var location := DataManager.get_location(location_id)
	var locked_message := str(location.get("locked_message", "You cannot enter this location right now."))

	var single_condition_value: Variant = location.get("entry_condition", {})
	if single_condition_value is Dictionary:
		var single_condition: Dictionary = single_condition_value
		if not single_condition.is_empty() and not ConditionEvaluator.evaluate(single_condition):
			return {
				"can_enter": false,
				"message": locked_message,
				"location_id": location_id,
			}

	var condition_list_value: Variant = location.get("entry_conditions", [])
	if condition_list_value is Array:
		var condition_list: Array = condition_list_value
		if not condition_list.is_empty() and not ConditionEvaluator.evaluate_any(condition_list):
			return {
				"can_enter": false,
				"message": locked_message,
				"location_id": location_id,
			}

	return {
		"can_enter": true,
		"message": "",
		"location_id": location_id,
	}
