## ConfigLoader — Loads config.json into DataManager.config.
## Config is deep-merged across all mods; later mods override earlier ones.
## No key field — the entire document is a nested dictionary.
extends RefCounted

class_name ConfigLoader


## Parses config.json content and deep-merges into DataManager.config.
static func load_additions(data: Dictionary) -> void:
	DataManager._deep_merge(DataManager.config, data)


## Applies patch operations to the config dictionary.
static func apply_patch(patch: Dictionary) -> void:
	DataManager._deep_merge(DataManager.config, patch)


## Returns a config value by dot-separated path, e.g. "ai.provider".
## Returns default_value if the path does not exist.
static func get_value(key_path: String, default_value: Variant = null) -> Variant:
	var parts := key_path.split(".")
	var current: Variant = DataManager.config
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return default_value
	return current


## Returns the full config dictionary.
static func get_all() -> Dictionary:
	return DataManager.config
