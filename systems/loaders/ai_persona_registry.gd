## AIPersonaRegistry -- Loads ai_personas.json into DataManager.ai_personas.
## Key field: "persona_id" (namespaced, e.g. "base:kael_persona")
extends RefCounted

class_name AIPersonaRegistry


## Parses ai_personas.json content and adds entries to DataManager.ai_personas.
static func load_additions(data: Array) -> void:
	for persona in data:
		if not persona is Dictionary:
			continue
		var persona_id := str(persona.get("persona_id", ""))
		if persona_id.is_empty():
			continue
		DataManager.ai_personas[persona_id] = persona.duplicate(true)


## Applies patch operations to existing AI persona entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.ai_personas.has(target):
			continue
		var entry: Dictionary = DataManager.ai_personas[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._append_array_field(entry, "tags", patch_entry.get("add_tags", []))
		DataManager._remove_array_values(entry, "tags", patch_entry.get("remove_tags", []))
		DataManager.ai_personas[target] = entry
