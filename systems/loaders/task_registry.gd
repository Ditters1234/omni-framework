## TaskRegistry — Loads tasks.json into DataManager.tasks.
## Key field: "template_id" (namespaced, e.g. "base:courier_run")
## Tasks are repeatable entity operations. Player-facing contracts live in quests.json.
extends RefCounted

class_name TaskRegistry


## Parses tasks.json content and adds entries to DataManager.tasks.
static func load_additions(data: Array) -> void:
	for task in data:
		if not task is Dictionary:
			continue
		var template_id := str(task.get("template_id", ""))
		if template_id.is_empty():
			continue
		DataManager.tasks[template_id] = task.duplicate(true)


## Applies patch operations to existing task entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.tasks.has(target):
			continue
		var entry: Dictionary = DataManager.tasks[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		if patch_entry.has("set_reward"):
			entry["reward"] = patch_entry.get("set_reward", {}).duplicate(true)
		if patch_entry.has("set_completion_actions"):
			entry["completion_actions"] = patch_entry.get("set_completion_actions", []).duplicate(true)
		DataManager.tasks[target] = entry


## Returns a task template by id, or empty dict.
static func get_task(template_id: String) -> Dictionary:
	return DataManager.tasks.get(template_id, {})


## Returns all task templates as an Array.
static func get_all() -> Array:
	return DataManager.tasks.values()


## Legacy helper: returns task templates listed by a faction. Contract boards now use quest_pool as quest ids.
static func get_for_faction(faction_id: String) -> Array:
	var result: Array = []
	var faction := DataManager.get_faction(faction_id)
	for template_id in faction.get("quest_pool", []):
		var task := get_task(str(template_id))
		if not task.is_empty():
			result.append(task)
	return result


## Returns true if a task template with the given id exists.
static func has_task(template_id: String) -> bool:
	return DataManager.tasks.has(template_id)
