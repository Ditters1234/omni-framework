## EntityRegistry — Loads entities.json into DataManager.entities.
## Key field: "entity_id" (namespaced, e.g. "base:blacksmith")
extends RefCounted

class_name EntityRegistry


## Parses entities.json content and adds entries to DataManager.entities.
static func load_additions(data: Array) -> void:
	for entity in data:
		if not entity is Dictionary:
			continue
		var entity_id := str(entity.get("entity_id", ""))
		if entity_id.is_empty():
			continue
		DataManager.entities[entity_id] = entity.duplicate(true)


## Applies patch operations to existing entity entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.entities.has(target):
			continue
		var entry: Dictionary = DataManager.entities[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._merge_dict_field(entry, "currencies", patch_entry.get("set_currencies", {}))
		DataManager._append_array_field(entry, "provides_sockets", patch_entry.get("add_sockets", []))
		DataManager._remove_objects_by_key(entry, "provides_sockets", "id", patch_entry.get("remove_socket_ids", []))
		DataManager.entities[target] = entry