## ScriptHookLoader — Loads and caches ScriptHook instances from mod scripts.
## Mod scripts are GDScript files extending ScriptHook, referenced by
## the documented "script_path" field in part/quest/location JSON templates.
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
	for part in DataManager.parts.values():
		var hook_path: String = part.get("script_path", part.get("script_hook", ""))
		if not hook_path.is_empty() and not hook_path in paths:
			paths.append(hook_path)
	for quest in DataManager.quests.values():
		var hook_path: String = quest.get("script_path", quest.get("script_hook", ""))
		if not hook_path.is_empty() and not hook_path in paths:
			paths.append(hook_path)
	return paths
