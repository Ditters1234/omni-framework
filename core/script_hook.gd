## ScriptHook — Base class for all mod script hooks.
## Modders extend this class to attach custom logic to game events
## such as equipping a part, entering a location, completing a quest, etc.
##
## Example usage in a mod:
##   extends ScriptHook
##   func on_equip(entity: Dictionary, instance: Dictionary) -> void:
##       print("Equipped: ", instance.get("id"))
extends RefCounted

class_name ScriptHook

# ---------------------------------------------------------------------------
# Lifecycle hooks — override in subclasses as needed
# ---------------------------------------------------------------------------

## Called when a part using this hook is equipped to an entity.
## entity: the EntityInstance dict, instance: the PartInstance dict.
func on_equip(_entity: Dictionary, _instance: Dictionary) -> void:
	pass


## Called when a part using this hook is unequipped from an entity.
func on_unequip(_entity: Dictionary, _instance: Dictionary) -> void:
	pass


## Called once per game tick for each entity carrying this part.
func on_tick(_entity: Dictionary, _instance: Dictionary, _tick: int) -> void:
	pass


## Called when a quest with this hook starts.
func on_quest_start(_quest_instance: Dictionary) -> void:
	pass


## Called when a quest with this hook completes.
func on_quest_complete(_quest_instance: Dictionary) -> void:
	pass


## Called when a quest with this hook fails.
func on_quest_fail(_quest_instance: Dictionary) -> void:
	pass


## Called when the player enters a location with this hook.
func on_location_enter(_location_template: Dictionary) -> void:
	pass


## Called when the player leaves a location with this hook.
func on_location_exit(_location_template: Dictionary) -> void:
	pass


## Called when a task with this hook is started.
func on_task_start(_task_instance: Dictionary) -> void:
	pass


## Called when a task with this hook is completed.
func on_task_complete(_task_instance: Dictionary) -> void:
	pass


# ---------------------------------------------------------------------------
# Utility helpers available to all hooks
# ---------------------------------------------------------------------------

## Convenience wrapper — checks AIManager availability before calling.
func generate_ai_async(prompt: String, context: Dictionary = {}) -> String:
	if not AIManager.is_available():
		return ""
	return await AIManager.generate_async(prompt, context)


## Resolves {placeholder} tokens in a template string from a dictionary.
## Unrecognized tokens are left in place.
func resolve_template_tokens(template_text: String, tokens: Dictionary) -> String:
	var resolved_text := template_text
	for token_key_value in tokens.keys():
		var token_key := str(token_key_value)
		resolved_text = resolved_text.replace("{%s}" % token_key, str(tokens.get(token_key_value, "")))
	return resolved_text.strip_edges()
