## ActionDispatcher — Executes JSON action blocks.
## Actions are defined in quest/task JSON and dispatched at runtime.
## All actions are side-effect operations on GameState.
extends RefCounted

class_name ActionDispatcher


## Dispatches an array of action blocks in order.
static func dispatch_all(actions: Array) -> void:
	for action in actions:
		if not action is Dictionary:
			push_warning("ActionDispatcher: action entries must be dictionaries.")
			continue
		dispatch(action)


## Dispatches a single action block.
static func dispatch(action: Dictionary) -> void:
	var action_type := str(action.get("type", "")).strip_edges()
	if action_type.is_empty():
		push_warning("ActionDispatcher: action type must not be empty.")
		return

	match action_type:
		"give_currency", "add_currency": _action_give_currency(action)
		"take_currency", "remove_currency": _action_take_currency(action)
		"learn_recipe":     _action_learn_recipe(action)
		"modify_reputation", "add_reputation", "remove_reputation": _action_modify_reputation(action)
		"give_part":        _action_give_part(action)
		"remove_part", "consume": _action_remove_part(action)
		"set_flag":         _action_set_flag(action)
		"modify_stat":      _action_modify_stat(action)
		"travel":           _action_travel(action)
		"start_task":       _action_start_task(action)
		"start_quest":      _action_start_quest(action)
		"unlock_location":  _action_unlock_location(action)
		"spawn_entity":     _action_spawn_entity(action)
		"reward":           _action_reward(action)
		"unlock_achievement": _action_unlock_achievement(action)
		"emit_signal":      _action_emit_signal(action)
		"push_screen":      _action_push_screen(action)
		"pop_screen":       _action_pop_screen(action)
		"replace_all_screens": _action_replace_all_screens(action)
		_:
			push_warning("ActionDispatcher: unknown action type '%s'" % action_type)


# ---------------------------------------------------------------------------
# Action implementations
# ---------------------------------------------------------------------------

static func _action_give_currency(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return

	var currency_id := str(action.get("currency_id", action.get("key", ""))).strip_edges()
	var amount := _positive_amount(action, "amount")
	if currency_id.is_empty() or amount <= 0.0:
		push_warning("ActionDispatcher: give_currency requires non-empty currency_id/key and positive amount.")
		return

	entity.add_currency(currency_id, amount)


static func _action_take_currency(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return

	var currency_id := str(action.get("currency_id", action.get("key", ""))).strip_edges()
	var amount := _positive_amount(action, "amount")
	if currency_id.is_empty() or amount <= 0.0:
		push_warning("ActionDispatcher: take_currency requires non-empty currency_id/key and positive amount.")
		return

	if not entity.spend_currency(currency_id, amount):
		push_warning("ActionDispatcher: entity '%s' lacks %.2f %s." % [entity.entity_id, amount, currency_id])


static func _action_learn_recipe(action: Dictionary) -> void:
	var recipe_id := str(action.get("recipe_id", "")).strip_edges()
	if recipe_id.is_empty() or not DataManager.has_recipe(recipe_id):
		push_warning("ActionDispatcher: learn_recipe references missing recipe '%s'." % recipe_id)
		return
	var learned_flag := "learned:%s" % recipe_id
	var entity_id := str(action.get("entity_id", "player"))
	if entity_id == "global":
		GameState.set_flag(learned_flag, true)
		return
	var entity := _resolve_entity(entity_id)
	if entity != null:
		entity.set_flag(learned_flag, true)


static func _action_modify_reputation(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var faction_id := str(action.get("faction_id", "")).strip_edges()
	if faction_id.is_empty():
		push_warning("ActionDispatcher: modify_reputation requires faction_id.")
		return
	var amount := absf(float(action.get("amount", action.get("delta", 0.0))))
	if amount <= 0.0:
		return
	if str(action.get("type", "")) == "remove_reputation":
		amount = -amount
	entity.add_reputation(faction_id, amount)


static func _action_give_part(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var part_id := str(action.get("part_id", action.get("template_id", ""))).strip_edges()
	var template := DataManager.get_part(part_id)
	if template.is_empty():
		push_warning("ActionDispatcher: give_part references missing part '%s'." % part_id)
		return
	var instance := PartInstance.from_template(template)
	entity.add_part(instance)
	GameEvents.part_acquired.emit(entity.entity_id, instance.template_id)


static func _action_remove_part(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var instance_id := str(action.get("instance_id", "")).strip_edges()
	if not instance_id.is_empty():
		var existing_part := entity.get_inventory_part(instance_id)
		if existing_part == null:
			return
		var existing_template_id := existing_part.template_id
		if entity.remove_part(instance_id):
			GameEvents.part_removed.emit(entity.entity_id, existing_template_id)
		return

	var template_id := str(action.get("part_id", action.get("template_id", ""))).strip_edges()
	if template_id.is_empty():
		push_warning("ActionDispatcher: remove_part requires instance_id, part_id, or template_id.")
		return
	TransactionService.remove_one_inventory_template(entity, template_id)


static func _action_set_flag(action: Dictionary) -> void:
	var flag_id := str(action.get("flag_id", action.get("key", ""))).strip_edges()
	if flag_id.is_empty():
		push_warning("ActionDispatcher: set_flag requires flag_id/key.")
		return

	var entity_id := str(action.get("entity_id", "global"))
	if entity_id == "global":
		GameState.set_flag(flag_id, action.get("value", true))
		return

	var entity := _resolve_entity(entity_id)
	if entity:
		entity.set_flag(flag_id, action.get("value", true))


static func _action_modify_stat(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return

	var stat_id := str(action.get("stat", action.get("stat_id", action.get("stat_key", "")))).strip_edges()
	if stat_id.is_empty():
		push_warning("ActionDispatcher: modify_stat requires stat/stat_id/stat_key.")
		return
	if not entity.has_stat(stat_id):
		push_warning("ActionDispatcher: entity '%s' does not have stat '%s'." % [entity.entity_id, stat_id])
		return

	entity.modify_stat(stat_id, float(action.get("delta", 0)))


static func _action_travel(action: Dictionary) -> void:
	var location_id := str(action.get("location_id", "")).strip_edges()
	if location_id.is_empty():
		push_warning("ActionDispatcher: travel requires location_id.")
		return
	if not DataManager.has_location(location_id):
		push_warning("ActionDispatcher: travel references missing location '%s'." % location_id)
		return
	GameState.travel_to(location_id, max(0, int(action.get("travel_ticks", 0))))


static func _action_start_task(action: Dictionary) -> void:
	var template_id := str(action.get("task_template_id", action.get("template_id", ""))).strip_edges()
	if template_id.is_empty() or not DataManager.has_task(template_id):
		push_warning("ActionDispatcher: start_task references missing task template '%s'." % template_id)
		return
	var params: Dictionary = {}
	var entity_id := str(action.get("entity_id", "player"))
	if not entity_id.is_empty():
		params["entity_id"] = entity_id
	TimeKeeper.accept_task(template_id, params)


static func _action_start_quest(action: Dictionary) -> void:
	var quest_id := str(action.get("quest_id", "")).strip_edges()
	if quest_id.is_empty() or not DataManager.has_quest(quest_id):
		push_warning("ActionDispatcher: start_quest references missing quest '%s'." % quest_id)
		return
	GameState.start_quest(quest_id)


static func _action_unlock_location(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var location_id := str(action.get("location_id", "")).strip_edges()
	if location_id.is_empty():
		push_warning("ActionDispatcher: unlock_location requires location_id.")
		return
	entity.discover_location(location_id)


static func _action_spawn_entity(action: Dictionary) -> void:
	var template_id := str(action.get("template_id", action.get("entity_template_id", ""))).strip_edges()
	if template_id.is_empty():
		return
	var template := DataManager.get_entity(template_id)
	if template.is_empty():
		push_warning("ActionDispatcher: spawn_entity references missing template '%s'." % template_id)
		return
	var instance := EntityInstance.from_template(template)
	if GameState.entity_instances.has(instance.entity_id):
		instance.entity_id = "%s:%d_%d" % [template_id, Time.get_ticks_usec(), randi()]
	var location_id := str(action.get("location_id", instance.location_id)).strip_edges()
	if not location_id.is_empty():
		if not DataManager.has_location(location_id):
			push_warning("ActionDispatcher: spawn_entity references missing location '%s'." % location_id)
			return
		instance.location_id = location_id
	GameState.commit_entity_instance(instance)


static func _action_reward(action: Dictionary) -> void:
	var entity := _resolve_entity(str(action.get("entity_id", "player")))
	if entity == null:
		return
	var reward_data: Variant = action.get("reward", action)
	if not reward_data is Dictionary:
		push_warning("ActionDispatcher: reward payload must be a dictionary.")
		return
	RewardService.apply_reward(entity, reward_data)


static func _action_unlock_achievement(action: Dictionary) -> void:
	var ach_id := str(action.get("achievement_id", "")).strip_edges()
	if ach_id.is_empty() or not DataManager.has_achievement(ach_id):
		push_warning("ActionDispatcher: unlock_achievement references missing achievement '%s'." % ach_id)
		return
	GameState.unlock_achievement(ach_id)


static func _action_emit_signal(action: Dictionary) -> void:
	var signal_name := str(action.get("signal_name", "")).strip_edges()
	if signal_name.is_empty():
		push_warning("ActionDispatcher: emit_signal requires signal_name.")
		return
	var args_data: Variant = action.get("args", [])
	var args: Array = []
	if args_data is Array:
		args = args_data
	GameEvents.emit_dynamic(signal_name, args)


static func _action_push_screen(action: Dictionary) -> void:
	var router := UIRouter as OmniUIRouter
	if router == null:
		return
	var screen_id := str(action.get("screen_id", "")).strip_edges()
	if screen_id.is_empty():
		push_warning("ActionDispatcher: push_screen requires a non-empty screen_id.")
		return
	var params := _read_params(action)
	router.push(screen_id, params)


static func _action_pop_screen(_action: Dictionary) -> void:
	var router := UIRouter as OmniUIRouter
	if router == null:
		return
	router.pop()


static func _action_replace_all_screens(action: Dictionary) -> void:
	var router := UIRouter as OmniUIRouter
	if router == null:
		return
	var screen_id := str(action.get("screen_id", "")).strip_edges()
	if screen_id.is_empty():
		push_warning("ActionDispatcher: replace_all_screens requires a non-empty screen_id.")
		return
	var params := _read_params(action)
	router.replace_all(screen_id, params)


static func _resolve_entity(entity_id: String) -> EntityInstance:
	if entity_id.is_empty() or entity_id == "player":
		return GameState.player as EntityInstance
	var entity := GameState.get_entity_instance(entity_id)
	if entity == null:
		push_warning("ActionDispatcher: unable to resolve entity '%s'." % entity_id)
	return entity


static func _positive_amount(action: Dictionary, field_name: String) -> float:
	return absf(float(action.get(field_name, 0.0)))


static func _read_params(action: Dictionary) -> Dictionary:
	var params_data: Variant = action.get("params", {})
	if params_data is Dictionary:
		var raw_params: Dictionary = params_data
		return raw_params.duplicate(true)
	return {}
