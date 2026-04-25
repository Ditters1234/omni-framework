## AITemplateRegistry -- Loads ai_templates.json into DataManager.ai_templates.
## Key field: "template_id" (namespaced, e.g. "base:task_flavor")
extends RefCounted

class_name AITemplateRegistry


## Parses ai_templates.json content and adds entries to DataManager.ai_templates.
static func load_additions(data: Array) -> void:
	for template_value in data:
		if not template_value is Dictionary:
			continue
		var template: Dictionary = template_value
		var template_id := str(template.get("template_id", ""))
		if template_id.is_empty():
			continue
		DataManager.ai_templates[template_id] = template.duplicate(true)


## Applies patch operations to existing AI template entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry_value in patch:
		if not patch_entry_value is Dictionary:
			continue
		var patch_entry: Dictionary = patch_entry_value
		var target := str(patch_entry.get("target", ""))
		if not DataManager.ai_templates.has(target):
			continue
		var entry_value: Variant = DataManager.ai_templates.get(target, {})
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._append_array_field(entry, "tags", patch_entry.get("add_tags", []))
		DataManager._remove_array_values(entry, "tags", patch_entry.get("remove_tags", []))
		DataManager.ai_templates[target] = entry


## Returns an AI template by id, or empty dict.
static func get_template(template_id: String) -> Dictionary:
	return DataManager.ai_templates.get(template_id, {})


## Returns all AI templates as an Array.
static func get_all() -> Array:
	return DataManager.ai_templates.values()


## Returns true if an AI template with the given id exists.
static func has_template(template_id: String) -> bool:
	return DataManager.ai_templates.has(template_id)
