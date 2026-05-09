## EntityLifecycleRunner -- Evaluates data-authored entity lifecycle states.
## Rules live in config under entity_lifecycle.rules and dispatch normal actions.
extends Node

class_name EntityLifecycleRunner

const CONFIG_RULES_KEY := "entity_lifecycle.rules"
const DEFAULT_NOTIFICATION_LEVEL := "warning"
const ENTITY_SCOPED_ACTIONS := {
	"set_flag": true,
	"modify_stat": true,
	"apply_status_effect": true,
	"remove_status_effect": true,
	"give_part": true,
	"remove_part": true,
	"give_currency": true,
	"take_currency": true,
	"modify_reputation": true,
	"start_task": true,
}

var _is_evaluating: bool = false


func _ready() -> void:
	if GameEvents == null:
		return
	if GameEvents.has_signal("entity_stat_changed"):
		GameEvents.entity_stat_changed.connect(_on_entity_stat_changed)
	if GameEvents.has_signal("game_started"):
		GameEvents.game_started.connect(_on_game_started)
	if GameEvents.has_signal("load_completed"):
		GameEvents.load_completed.connect(_on_load_completed)


func evaluate_all_entities() -> void:
	for entity_value in GameState.entity_instances.values():
		var entity := entity_value as EntityInstance
		if entity != null:
			_evaluate_entity(entity, "")


func _on_entity_stat_changed(entity_id: String, stat_key: String, _old_value: float, _new_value: float) -> void:
	var entity := GameState.get_entity_instance(entity_id)
	if entity == null:
		return
	_evaluate_entity(entity, stat_key)


func _on_game_started() -> void:
	evaluate_all_entities()


func _on_load_completed(_slot: int) -> void:
	evaluate_all_entities()


func _evaluate_entity(entity: EntityInstance, changed_stat: String) -> void:
	if _is_evaluating:
		return
	var rules := _get_rules()
	if rules.is_empty():
		return
	_is_evaluating = true
	for rule in rules:
		if not _rule_matches_stat(rule, changed_stat):
			continue
		_evaluate_rule(entity, rule)
	_is_evaluating = false


func _evaluate_rule(entity: EntityInstance, rule: Dictionary) -> void:
	var state_flag := _resolve_state_flag(rule)
	if state_flag.is_empty():
		return
	var should_be_active := _rule_condition_matches(entity, rule)
	var is_active := bool(entity.get_flag(state_flag, false))
	if should_be_active and not is_active:
		_enter_state(entity, rule, state_flag)
	elif not should_be_active and is_active and _can_exit_state(rule):
		_exit_state(entity, rule, state_flag)


func _enter_state(entity: EntityInstance, rule: Dictionary, state_flag: String) -> void:
	if bool(rule.get("set_state_flag", true)):
		entity.set_flag(state_flag, true)
	_dispatch_rule_actions(entity, rule, "actions")
	_emit_state_changed(entity, rule, true)
	_emit_notification(entity, rule, "notification", "notification_level")
	if bool(rule.get("game_over_on_player", false)) and GameState.player == entity:
		GameEvents.game_over.emit()


func _exit_state(entity: EntityInstance, rule: Dictionary, state_flag: String) -> void:
	if bool(rule.get("set_state_flag", true)):
		entity.set_flag(state_flag, false)
	_dispatch_rule_actions(entity, rule, "exit_actions")
	_emit_state_changed(entity, rule, false)
	_emit_notification(entity, rule, "exit_notification", "exit_notification_level")


func _get_rules() -> Array[Dictionary]:
	var rules_value: Variant = DataManager.get_config_value(CONFIG_RULES_KEY, [])
	var results: Array[Dictionary] = []
	if not rules_value is Array:
		return results
	var rules: Array = rules_value
	for rule_value in rules:
		if rule_value is Dictionary:
			var rule: Dictionary = rule_value
			results.append(rule)
	return results


func _rule_matches_stat(rule: Dictionary, changed_stat: String) -> bool:
	if changed_stat.is_empty():
		return true
	var stat_value: Variant = rule.get("stat", "")
	if stat_value is String:
		var stat_key := str(stat_value)
		return stat_key.is_empty() or stat_key == changed_stat
	if stat_value is Array:
		var stat_keys: Array = stat_value
		return stat_keys.is_empty() or changed_stat in stat_keys
	return true


func _rule_condition_matches(entity: EntityInstance, rule: Dictionary) -> bool:
	var condition_value: Variant = rule.get("condition", {})
	if not condition_value is Dictionary:
		return false
	var condition: Dictionary = condition_value
	var context := {
		"entity": entity,
		"lifecycle_entity": entity,
		"lifecycle_rule": rule,
	}
	return ConditionEvaluator.evaluate(condition, context)


func _can_exit_state(rule: Dictionary) -> bool:
	if bool(rule.get("clear_when_condition_false", false)):
		return true
	var exit_actions_value: Variant = rule.get("exit_actions", [])
	if exit_actions_value is Array and not (exit_actions_value as Array).is_empty():
		return true
	return not str(rule.get("exit_notification", "")).is_empty()


func _resolve_state_flag(rule: Dictionary) -> String:
	var state_flag := str(rule.get("state_flag", ""))
	if not state_flag.is_empty():
		return state_flag
	var rule_id := str(rule.get("rule_id", ""))
	if rule_id.is_empty():
		return ""
	return "lifecycle:%s" % rule_id


func _dispatch_rule_actions(entity: EntityInstance, rule: Dictionary, field_name: String) -> void:
	var actions_value: Variant = rule.get(field_name, [])
	if not actions_value is Array:
		return
	var actions: Array = actions_value
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		var action_payload := action.duplicate(true)
		_prepare_entity_action(action_payload, entity)
		ActionDispatcher.dispatch(action_payload)


func _prepare_entity_action(action_payload: Dictionary, entity: EntityInstance) -> void:
	var action_type := str(action_payload.get("type", ""))
	if action_type.is_empty():
		return
	if ENTITY_SCOPED_ACTIONS.has(action_type) and not action_payload.has("entity_id"):
		action_payload["entity_id"] = entity.entity_id


func _emit_state_changed(entity: EntityInstance, rule: Dictionary, active: bool) -> void:
	GameEvents.entity_lifecycle_state_changed.emit(
		entity.entity_id,
		str(rule.get("rule_id", "")),
		_resolve_state_flag(rule),
		active
	)


func _emit_notification(entity: EntityInstance, rule: Dictionary, message_field: String, level_field: String) -> void:
	var template := str(rule.get(message_field, ""))
	if template.is_empty():
		return
	var level := str(rule.get(level_field, rule.get("notification_level", DEFAULT_NOTIFICATION_LEVEL)))
	GameEvents.ui_notification_requested.emit(_format_message(template, entity, rule), level)


func _format_message(template: String, entity: EntityInstance, rule: Dictionary) -> String:
	var rule_id := str(rule.get("rule_id", ""))
	var state_name := str(rule.get("display_name", rule_id))
	var stat_key := str(rule.get("stat", ""))
	var stat_value := 0.0
	if not stat_key.is_empty() and entity.has_stat(stat_key):
		stat_value = entity.effective_stat(stat_key)
	return template.format({
		"entity_id": entity.entity_id,
		"entity_name": _entity_display_name(entity),
		"rule_id": rule_id,
		"state_name": state_name,
		"state_flag": _resolve_state_flag(rule),
		"stat": stat_key,
		"value": stat_value,
	})


func _entity_display_name(entity: EntityInstance) -> String:
	var template := DataManager.get_entity(entity.template_id)
	return str(template.get("display_name", entity.entity_id))
