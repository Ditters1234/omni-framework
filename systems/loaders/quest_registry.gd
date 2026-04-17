## QuestRegistry — Loads quests.json into DataManager.quests.
## Key field: "quest_id" (namespaced, e.g. "base:the_first_hunt")
## Quest state machines are managed at runtime by QuestTracker.
extends RefCounted

class_name QuestRegistry


## Parses quests.json content and adds entries to DataManager.quests.
static func load_additions(data: Array) -> void:
	for quest in data:
		if not quest is Dictionary:
			continue
		var quest_id := str(quest.get("quest_id", ""))
		if quest_id.is_empty():
			continue
		DataManager.quests[quest_id] = quest.duplicate(true)


## Applies patch operations to existing quest entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.quests.has(target):
			continue
		var entry: Dictionary = DataManager.quests[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._append_array_field(entry, "stages", patch_entry.get("add_stages", []))
		DataManager.quests[target] = entry


## Returns a quest template by id, or empty dict.
static func get_quest(quest_id: String) -> Dictionary:
	return DataManager.quests.get(quest_id, {})


## Returns all quest templates as an Array.
static func get_all() -> Array:
	return DataManager.quests.values()


## Returns quest templates whose prerequisites are all satisfied by the player.
static func get_available(completed_quest_ids: Array[String]) -> Array:
	var result: Array = []
	for quest in DataManager.quests.values():
		var prereqs: Array = quest.get("prerequisites", [])
		var satisfied := true
		for prereq in prereqs:
			if not str(prereq) in completed_quest_ids:
				satisfied = false
				break
		if satisfied:
			result.append(quest)
	return result


## Returns true if a quest template with the given id exists.
static func has_quest(quest_id: String) -> bool:
	return DataManager.quests.has(quest_id)
