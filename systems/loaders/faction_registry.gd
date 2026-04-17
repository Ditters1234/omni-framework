## FactionRegistry — Loads factions.json into DataManager.factions.
## Key field: "faction_id" (namespaced, e.g. "base:merchants_guild")
extends RefCounted

class_name FactionRegistry


## Parses factions.json content and adds entries to DataManager.factions.
static func load_additions(data: Array) -> void:
	for faction in data:
		if not faction is Dictionary:
			continue
		var faction_id := str(faction.get("faction_id", ""))
		if faction_id.is_empty():
			continue
		DataManager.factions[faction_id] = faction.duplicate(true)


## Applies patch operations to existing faction entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.factions.has(target):
			continue
		var entry: Dictionary = DataManager.factions[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager.factions[target] = entry