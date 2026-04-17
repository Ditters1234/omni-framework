## ScriptHookLoader — Loads and caches ScriptHook instances from mod scripts.
## Mod scripts are GDScript files extending ScriptHook, referenced by
## the documented "script_path" field in part/entity/location/quest/task templates.
##
## Example JSON usage:
##   "script_path": "res://mods/my_name/my_mod/scripts/my_hook.gd"
extends RefCounted

class_name ScriptHookLoader

## Cache: script_path → ScriptHook instance
var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns a cached ScriptHook instance for the given path.
## Loads and caches it on first access. Returns null on failure.
func get_hook(script_path: String) -> ScriptHook:
	if _cache.has(script_path):
		return _cache[script_path]
	return _load_hook(script_path)


## Clears the cache (e.g. after a mod reload).
func clear_cache() -> void:
	_cache.clear()


## Pre-loads all script hooks referenced in the loaded templates.
## Call after DataManager finishes both load phases.
func preload_all() -> void:
	for script_path in _collect_hook_paths():
		get_hook(script_path)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_hook(script_path: String) -> ScriptHook:
	if not ResourceLoader.exists(script_path):
		push_warning("ScriptHookLoader: script not found at '%s'" % script_path)
		return null
	var script: GDScript = load(script_path)
	if not script:
		push_warning("ScriptHookLoader: failed to load script at '%s'" % script_path)
		return null
	var instance = script.new()
	if not instance is ScriptHook:
		push_warning("ScriptHookLoader: script at '%s' does not extend ScriptHook" % script_path)
		return null
	_cache[script_path] = instance
	return instance


func _collect_hook_paths() -> Array[String]:
	var paths: Array[String] = []
	_append_hook_paths(paths, DataManager.parts.values())
	_append_hook_paths(paths, DataManager.entities.values())
	_append_hook_paths(paths, DataManager.locations.values())
	_append_hook_paths(paths, DataManager.quests.values())
	_append_hook_paths(paths, DataManager.tasks.values())
	return paths


func _append_hook_paths(paths: Array[String], templates: Array) -> void:
	for template_data in templates:
		if not template_data is Dictionary:
			continue
		var template: Dictionary = template_data
		var hook_path := str(template.get("script_path", template.get("script_hook", "")))
		if hook_path.is_empty() or hook_path in paths:
			continue
		paths.append(hook_path)
