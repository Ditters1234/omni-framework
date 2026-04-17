## AchievementRegistry — Loads achievements.json into DataManager.achievements.
## Key field: "achievement_id" (namespaced, e.g. "base:first_sale")
extends RefCounted

class_name AchievementRegistry


## Parses achievements.json content and adds to DataManager.achievements.
static func load_additions(data: Array) -> void:
	for achievement in data:
		if not achievement is Dictionary:
			continue
		var achievement_id := str(achievement.get("achievement_id", ""))
		if achievement_id.is_empty():
			continue
		DataManager.achievements[achievement_id] = achievement.duplicate(true)


## Applies patch operations to existing achievement entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.achievements.has(target):
			continue
		var entry: Dictionary = DataManager.achievements[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager.achievements[target] = entry


## Returns an achievement template by id, or empty dict.
static func get_achievement(achievement_id: String) -> Dictionary:
	return DataManager.achievements.get(achievement_id, {})


## Returns all achievement templates as an Array.
static func get_all() -> Array:
	return DataManager.achievements.values()


## Returns achievement templates not yet unlocked by the player.
static func get_locked(unlocked_ids: Array[String]) -> Array:
	var result: Array = []
	for ach in DataManager.achievements.values():
		if not str(ach.get("achievement_id", "")) in unlocked_ids:
			result.append(ach)
	return result


## Returns true if an achievement template with the given id exists.
static func has_achievement(achievement_id: String) -> bool:
	return DataManager.achievements.has(achievement_id)
