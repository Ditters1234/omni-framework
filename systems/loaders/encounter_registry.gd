## EncounterRegistry -- Loads encounters.json into DataManager.encounters.
## Key field: "encounter_id" (namespaced, e.g. "base:tutorial_brawl")
extends RefCounted

class_name EncounterRegistry


static func load_additions(data: Array) -> void:
	for encounter_value in data:
		if not encounter_value is Dictionary:
			continue
		var encounter: Dictionary = encounter_value
		var encounter_id := str(encounter.get("encounter_id", "")).strip_edges()
		if encounter_id.is_empty():
			continue
		DataManager.encounters[encounter_id] = encounter.duplicate(true)


static func apply_patch(patches: Array) -> void:
	for patch_value in patches:
		if not patch_value is Dictionary:
			continue
		var patch: Dictionary = patch_value
		var target := str(patch.get("target", "")).strip_edges()
		if target.is_empty() or not DataManager.encounters.has(target):
			continue
		var entry: Dictionary = DataManager.encounters[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch)
		_apply_action_patch(entry, "player", patch.get("add_player_actions", []), patch.get("remove_player_action_ids", []))
		_apply_action_patch(entry, "opponent", patch.get("add_opponent_actions", []), patch.get("remove_opponent_action_ids", []))
		_apply_outcome_patch(entry, patch.get("add_outcomes", []), patch.get("remove_outcome_ids", []))
		DataManager.encounters[target] = entry


static func get_encounter(encounter_id: String) -> Dictionary:
	var encounter_value: Variant = DataManager.encounters.get(encounter_id, {})
	if encounter_value is Dictionary:
		var encounter: Dictionary = encounter_value
		return encounter.duplicate(true)
	return {}


static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for encounter_value in DataManager.encounters.values():
		if encounter_value is Dictionary:
			var encounter: Dictionary = encounter_value
			result.append(encounter.duplicate(true))
	return result


static func has_encounter(encounter_id: String) -> bool:
	return DataManager.encounters.has(encounter_id)


static func _apply_action_patch(entry: Dictionary, role: String, additions_value: Variant, removals_value: Variant) -> void:
	var actions_value: Variant = entry.get("actions", {})
	var actions: Dictionary = actions_value if actions_value is Dictionary else {}
	var role_actions_value: Variant = actions.get(role, [])
	var role_actions: Array = role_actions_value if role_actions_value is Array else []
	var remove_ids := _to_string_array(removals_value)
	if not remove_ids.is_empty():
		var filtered: Array = []
		for action_value in role_actions:
			if action_value is Dictionary and str((action_value as Dictionary).get("action_id", "")) in remove_ids:
				continue
			filtered.append(action_value)
		role_actions = filtered
	if additions_value is Array:
		var additions: Array = additions_value
		for action_value in additions:
			if action_value is Dictionary:
				role_actions.append((action_value as Dictionary).duplicate(true))
	actions[role] = role_actions
	entry["actions"] = actions


static func _apply_outcome_patch(entry: Dictionary, additions_value: Variant, removals_value: Variant) -> void:
	var resolution_value: Variant = entry.get("resolution", {})
	var resolution: Dictionary = resolution_value if resolution_value is Dictionary else {}
	var outcomes_value: Variant = resolution.get("outcomes", [])
	var outcomes: Array = outcomes_value if outcomes_value is Array else []
	var remove_ids := _to_string_array(removals_value)
	if not remove_ids.is_empty():
		var filtered: Array = []
		for outcome_value in outcomes:
			if outcome_value is Dictionary and str((outcome_value as Dictionary).get("outcome_id", "")) in remove_ids:
				continue
			filtered.append(outcome_value)
		outcomes = filtered
	if additions_value is Array:
		var additions: Array = additions_value
		for outcome_value in additions:
			if outcome_value is Dictionary:
				outcomes.append((outcome_value as Dictionary).duplicate(true))
	resolution["outcomes"] = outcomes
	entry["resolution"] = resolution


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for item_value in values:
		var item := str(item_value).strip_edges()
		if not item.is_empty():
			result.append(item)
	return result
