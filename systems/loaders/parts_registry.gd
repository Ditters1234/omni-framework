## PartsRegistry — Loads parts.json into DataManager.parts.
## Key field: "id" (namespaced, e.g. "base:iron_sword")
extends RefCounted

class_name PartsRegistry


## Parses parts.json content and adds entries to DataManager.parts.
static func load_additions(data: Array) -> void:
	for part in data:
		if not part is Dictionary:
			continue
		var part_id := str(part.get("id", ""))
		if part_id.is_empty():
			continue
		DataManager.parts[part_id] = part.duplicate(true)


## Applies patch operations to existing part entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.parts.has(target):
			continue
		var entry: Dictionary = DataManager.parts[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._merge_dict_field(entry, "stats", patch_entry.get("set_stats", {}))
		DataManager._append_array_field(entry, "tags", patch_entry.get("add_tags", []))
		DataManager._remove_array_values(entry, "tags", patch_entry.get("remove_tags", []))
		DataManager._remove_objects_by_key(entry, "provides_sockets", "id", patch_entry.get("remove_socket_ids", []))
		DataManager.parts[target] = entry


## Returns all part templates that have the given tag.
static func get_by_category(tag: String) -> Array:
	var result: Array = []
	for part_id in DataManager.parts.keys():
		var part: Dictionary = DataManager.parts[part_id]
		var tags: Variant = part.get("tags", [])
		if tags is Array and tags.has(tag):
			result.append(part)
	return result