## StatusEffectRunner -- Applies and advances data-authored timed effects.
## Runtime instances live in GameState.active_status_effects as dictionaries.
extends Node

class_name StatusEffectRunner

const DEFAULT_DURATION := 1
const DEFAULT_TICK_INTERVAL := 1
const STACK_MODE_REFRESH := "refresh"
const STACK_MODE_REPLACE := "replace"
const STACK_MODE_ADD_DURATION := "add_duration"
const STACK_MODE_STACK := "stack"


func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick)


func apply_status_effect(effect_id: String, entity_id: String = "player", params: Dictionary = {}) -> String:
	var template := DataManager.get_status_effect(effect_id)
	if template.is_empty():
		push_warning("StatusEffectRunner: unknown status effect '%s'." % effect_id)
		return ""
	var entity := _resolve_entity(entity_id)
	if entity == null:
		return ""

	var existing_runtime_id := _find_existing_runtime_id(entity.entity_id, effect_id)
	if not existing_runtime_id.is_empty():
		return _apply_to_existing(existing_runtime_id, template, entity, params)

	var duration := _resolve_duration(template, params)
	var runtime_id := _generate_runtime_id()
	var instance := {
		"runtime_id": runtime_id,
		"status_effect_id": effect_id,
		"entity_id": entity.entity_id,
		"started_tick": GameState.current_tick,
		"remaining_ticks": duration,
		"duration": duration,
		"elapsed_ticks": 0,
		"tick_interval": _resolve_tick_interval(template, params),
		"stacks": clampi(int(params.get("stacks", 1)), 1, _resolve_max_stacks(template)),
	}
	GameState.active_status_effects[runtime_id] = instance
	_dispatch_actions(template, "on_apply", instance)
	GameEvents.status_effect_applied.emit(entity.entity_id, effect_id, runtime_id)
	return runtime_id


func remove_status_effect(effect_id: String, entity_id: String = "player", expire: bool = false) -> int:
	var entity := _resolve_entity(entity_id)
	if entity == null:
		return 0
	var removed := 0
	var runtime_ids: Array[String] = []
	for runtime_id_value in GameState.active_status_effects.keys():
		var runtime_id := str(runtime_id_value)
		var instance_value: Variant = GameState.active_status_effects.get(runtime_id, {})
		if not instance_value is Dictionary:
			continue
		var instance: Dictionary = instance_value
		if str(instance.get("entity_id", "")) == entity.entity_id and str(instance.get("status_effect_id", "")) == effect_id:
			runtime_ids.append(runtime_id)
	for runtime_id in runtime_ids:
		_remove_runtime_id(runtime_id, expire)
		removed += 1
	return removed


func get_effects_for_entity(entity_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for effect_value in GameState.active_status_effects.values():
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		if str(effect.get("entity_id", "")) == entity_id:
			results.append(effect.duplicate(true))
	return results


func _on_tick(_tick: int) -> void:
	var runtime_ids: Array[String] = []
	for runtime_id_value in GameState.active_status_effects.keys():
		runtime_ids.append(str(runtime_id_value))
	for runtime_id in runtime_ids:
		_advance_effect(runtime_id)


func _advance_effect(runtime_id: String) -> void:
	var instance_value: Variant = GameState.active_status_effects.get(runtime_id, {})
	if not instance_value is Dictionary:
		return
	var instance: Dictionary = instance_value
	var template := DataManager.get_status_effect(str(instance.get("status_effect_id", "")))
	if template.is_empty():
		GameState.active_status_effects.erase(runtime_id)
		return
	var remaining_ticks := int(instance.get("remaining_ticks", 0)) - 1
	var elapsed_ticks := int(instance.get("elapsed_ticks", 0)) + 1
	instance["remaining_ticks"] = remaining_ticks
	instance["elapsed_ticks"] = elapsed_ticks
	var tick_interval := maxi(int(instance.get("tick_interval", DEFAULT_TICK_INTERVAL)), DEFAULT_TICK_INTERVAL)
	if elapsed_ticks % tick_interval == 0:
		_dispatch_actions(template, "on_tick", instance)
		GameEvents.status_effect_ticked.emit(str(instance.get("entity_id", "")), str(instance.get("status_effect_id", "")), runtime_id)
	if remaining_ticks <= 0:
		GameState.active_status_effects[runtime_id] = instance
		_remove_runtime_id(runtime_id, true)
		return
	GameState.active_status_effects[runtime_id] = instance


func _apply_to_existing(runtime_id: String, template: Dictionary, entity: EntityInstance, params: Dictionary) -> String:
	var instance_value: Variant = GameState.active_status_effects.get(runtime_id, {})
	if not instance_value is Dictionary:
		return ""
	var instance: Dictionary = instance_value
	var duration := _resolve_duration(template, params)
	var max_stacks := _resolve_max_stacks(template)
	var stack_mode := str(params.get("stack_mode", template.get("stack_mode", STACK_MODE_REFRESH)))
	match stack_mode:
		STACK_MODE_REPLACE:
			instance["stacks"] = clampi(int(params.get("stacks", 1)), 1, max_stacks)
			instance["remaining_ticks"] = duration
			instance["duration"] = duration
			instance["elapsed_ticks"] = 0
		STACK_MODE_ADD_DURATION:
			instance["remaining_ticks"] = maxi(int(instance.get("remaining_ticks", 0)) + duration, DEFAULT_DURATION)
			instance["duration"] = maxi(int(instance.get("duration", duration)), duration)
		STACK_MODE_STACK:
			var added_stacks := clampi(int(params.get("stacks", 1)), 1, max_stacks)
			instance["stacks"] = clampi(int(instance.get("stacks", 1)) + added_stacks, 1, max_stacks)
			instance["remaining_ticks"] = duration
			instance["duration"] = duration
		_:
			instance["remaining_ticks"] = duration
			instance["duration"] = duration
	GameState.active_status_effects[runtime_id] = instance
	_dispatch_actions(template, "on_apply", instance)
	GameEvents.status_effect_applied.emit(entity.entity_id, str(template.get("status_effect_id", "")), runtime_id)
	return runtime_id


func _remove_runtime_id(runtime_id: String, expire: bool) -> void:
	var instance_value: Variant = GameState.active_status_effects.get(runtime_id, {})
	if not instance_value is Dictionary:
		return
	var instance: Dictionary = instance_value
	var effect_id := str(instance.get("status_effect_id", ""))
	var entity_id := str(instance.get("entity_id", ""))
	if expire:
		var template := DataManager.get_status_effect(effect_id)
		if not template.is_empty():
			_dispatch_actions(template, "on_expire", instance)
	GameState.active_status_effects.erase(runtime_id)
	if expire:
		GameEvents.status_effect_expired.emit(entity_id, effect_id, runtime_id)
	else:
		GameEvents.status_effect_removed.emit(entity_id, effect_id, runtime_id)


func _dispatch_actions(template: Dictionary, field_name: String, instance: Dictionary) -> void:
	var actions_value: Variant = template.get(field_name, [])
	if not actions_value is Array:
		return
	var actions: Array = actions_value
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		var action_payload := action.duplicate(true)
		if not action_payload.has("entity_id"):
			action_payload["entity_id"] = str(instance.get("entity_id", "player"))
		if not action_payload.has("status_effect_id"):
			action_payload["status_effect_id"] = str(instance.get("status_effect_id", ""))
		if not action_payload.has("status_effect_runtime_id"):
			action_payload["status_effect_runtime_id"] = str(instance.get("runtime_id", ""))
		if not action_payload.has("stacks"):
			action_payload["stacks"] = int(instance.get("stacks", 1))
		ActionDispatcher.dispatch(action_payload)


func _find_existing_runtime_id(entity_id: String, effect_id: String) -> String:
	for runtime_id_value in GameState.active_status_effects.keys():
		var runtime_id := str(runtime_id_value)
		var instance_value: Variant = GameState.active_status_effects.get(runtime_id, {})
		if not instance_value is Dictionary:
			continue
		var instance: Dictionary = instance_value
		if str(instance.get("entity_id", "")) == entity_id and str(instance.get("status_effect_id", "")) == effect_id:
			return runtime_id
	return ""


func _resolve_duration(template: Dictionary, params: Dictionary) -> int:
	return maxi(int(params.get("duration", params.get("duration_ticks", template.get("duration", DEFAULT_DURATION)))), DEFAULT_DURATION)


func _resolve_tick_interval(template: Dictionary, params: Dictionary) -> int:
	return maxi(int(params.get("tick_interval", template.get("tick_interval", DEFAULT_TICK_INTERVAL))), DEFAULT_TICK_INTERVAL)


func _resolve_max_stacks(template: Dictionary) -> int:
	return maxi(int(template.get("max_stacks", 1)), 1)


func _resolve_entity(entity_id: String) -> EntityInstance:
	if entity_id == "player" or entity_id.is_empty():
		return GameState.player as EntityInstance
	return GameState.get_entity_instance(entity_id)


func _generate_runtime_id() -> String:
	return "status_%d_%d" % [Time.get_ticks_usec(), randi()]
