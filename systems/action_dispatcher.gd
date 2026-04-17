## ActionDispatcher — Executes JSON action blocks.
## Actions are defined in quest/task JSON and dispatched at runtime.
## All actions are side-effect operations on GameState.
##
## Action block format (one action per dict, dispatched in array order):
## { "type": "give_currency", "key": "gold", "amount": 100 }
## { "type": "give_part", "part_id": "base:iron_sword" }
## { "type": "set_flag", "key": "met_blacksmith", "value": true }
## { "type": "travel", "location_id": "base:town_square" }
## { "type": "start_quest", "quest_id": "base:the_first_hunt" }
## { "type": "emit_signal", "signal_name": "custom_signal", "args": [] }
extends RefCounted

class_name ActionDispatcher


## Dispatches an array of action blocks in order.
static func dispatch_all(actions: Array) -> void:
	for action in actions:
		dispatch(action)


## Dispatches a single action block.
static func dispatch(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	match action_type:
		"give_currency", "add_currency": _action_give_currency(action)
		"take_currency", "remove_currency": _action_take_currency(action)
		"give_part":        _action_give_part(action)
		"remove_part":      _action_remove_part(action)
		"set_flag":         _action_set_flag(action)
		"modify_stat":      _action_modify_stat(action)
		"travel":           _action_travel(action)
		"start_quest":      _action_start_quest(action)
		"unlock_achievement": _action_unlock_achievement(action)
		"emit_signal":      _action_emit_signal(action)
		_:
			push_warning("ActionDispatcher: unknown action type '%s'" % action_type)


# ---------------------------------------------------------------------------
# Action implementations
# ---------------------------------------------------------------------------

static func _action_give_currency(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	entity.add_currency(
		str(action.get("currency_id", action.get("key", ""))),
		float(action.get("amount", 0))
	)


static func _action_take_currency(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	entity.spend_currency(
		str(action.get("currency_id", action.get("key", ""))),
		float(action.get("amount", 0))
	)


static func _action_give_part(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var template := DataManager.get_part(str(action.get("part_id", "")))
	if template.is_empty():
		return
	var instance := PartInstance.from_template(template)
	entity.add_part(instance)
	GameEvents.part_acquired.emit(entity.entity_id, instance.template_id)


static func _action_remove_part(action: Dictionary) -> void:
	pass


static func _action_set_flag(action: Dictionary) -> void:
	var entity_id := str(action.get("entity_id", "global"))
	if entity_id == "global":
		GameState.set_flag(str(action.get("flag_id", action.get("key", ""))), action.get("value", true))
		return
	var entity := _resolve_entity(entity_id)
	if entity:
		entity.flags[str(action.get("flag_id", action.get("key", "")))] = action.get("value", true)


static func _action_modify_stat(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	entity.modify_stat(
		str(action.get("stat", "")),
		float(action.get("delta", 0))
	)


static func _action_travel(action: Dictionary) -> void:
	GameState.travel_to(str(action.get("location_id", "")))


static func _action_start_quest(action: Dictionary) -> void:
	pass  # Handled by QuestTracker


static func _action_unlock_achievement(action: Dictionary) -> void:
	var ach_id := str(action.get("achievement_id", ""))
	if ach_id in GameState.unlocked_achievements:
		return
	GameState.unlocked_achievements.append(ach_id)
	GameEvents.achievement_unlocked.emit(ach_id)


static func _action_emit_signal(action: Dictionary) -> void:
	var signal_name := str(action.get("signal_name", ""))
	if GameEvents.has_signal(signal_name):
		var args: Array = action.get("args", [])
		GameEvents.callv("emit_signal", [signal_name] + args)


static func _resolve_entity(entity_id: String) -> EntityInstance:
	if entity_id.is_empty() or entity_id == "player":
		return GameState.player
	return GameState.get_entity_instance(entity_id)
