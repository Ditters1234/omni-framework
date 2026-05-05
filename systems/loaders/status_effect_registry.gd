## StatusEffectRegistry -- Loads status_effects.json into DataManager.status_effects.
## Key field: "status_effect_id" (namespaced, e.g. "base:fatigued")
extends RefCounted

class_name StatusEffectRegistry


static func load_additions(data: Array) -> void:
	for effect_value in data:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		var effect_id := str(effect.get("status_effect_id", ""))
		if effect_id.is_empty():
			continue
		DataManager.status_effects[effect_id] = effect.duplicate(true)


static func apply_patch(patch: Array) -> void:
	for patch_value in patch:
		if not patch_value is Dictionary:
			continue
		var patch_entry: Dictionary = patch_value
		var target := str(patch_entry.get("target", ""))
		if not DataManager.status_effects.has(target):
			continue
		var entry: Dictionary = DataManager.status_effects[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._append_array_field(entry, "tags", patch_entry.get("add_tags", []))
		DataManager._remove_array_values(entry, "tags", patch_entry.get("remove_tags", []))
		DataManager.status_effects[target] = entry


static func get_status_effect(effect_id: String) -> Dictionary:
	var effect_value: Variant = DataManager.status_effects.get(effect_id, {})
	if effect_value is Dictionary:
		var effect: Dictionary = effect_value
		return effect.duplicate(true)
	return {}


static func has_status_effect(effect_id: String) -> bool:
	return DataManager.status_effects.has(effect_id)
