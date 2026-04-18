extends "res://ui/screens/backends/backend_base.gd"

class_name OmniChallengeBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const PHASE4_HELPERS := preload("res://ui/screens/backends/phase4_backend_helpers.gd")

var _params: Dictionary = {}
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ChallengeBackend", {
		"required": ["required_stat", "required_value"],
		"optional": [
			"target_entity_id",
			"portrait_entity_id",
			"screen_title",
			"screen_description",
			"confirm_label",
			"cancel_label",
			"reward",
			"action_payload",
			"failure_action_payload",
			"success_sound",
			"failure_sound",
		],
		"field_types": {
			"required_stat": TYPE_STRING,
			"required_value": TYPE_FLOAT,
			"target_entity_id": TYPE_STRING,
			"portrait_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"reward": TYPE_DICTIONARY,
			"action_payload": TYPE_DICTIONARY,
			"failure_action_payload": TYPE_DICTIONARY,
			"success_sound": TYPE_STRING,
			"failure_sound": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_status_text = ""


func build_view_model() -> Dictionary:
	var target_entity := _resolve_target_entity()
	var portrait_entity := _resolve_portrait_entity(target_entity)
	var required_stat := str(_params.get("required_stat", ""))
	var required_value := _read_required_value()
	var current_value := 0.0 if target_entity == null else target_entity.effective_stat(required_stat)
	var title := str(_params.get("screen_title", "Challenge"))
	var description := str(_params.get("screen_description", "Attempt a one-shot stat check against the configured threshold."))
	return {
		"title": title,
		"description": description,
		"portrait": PHASE4_HELPERS.build_entity_portrait_view_model(
			portrait_entity,
			"Challenge",
			"Review the opposition, then decide whether to attempt the check."
		),
		"stat_line": {
			"stat_id": required_stat,
			"label": PHASE4_HELPERS.humanize_id(required_stat),
			"value": current_value,
			"max_value": maxf(required_value, current_value),
			"color_token": "warning",
		},
		"required_value": required_value,
		"current_value": current_value,
		"confirm_label": str(_params.get("confirm_label", "Attempt")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"confirm_enabled": target_entity != null and not required_stat.is_empty(),
		"status_text": _build_status_text(target_entity, required_stat, current_value, required_value),
	}


func confirm() -> Dictionary:
	var target_entity := _resolve_target_entity()
	if target_entity == null:
		_status_text = "The challenge target entity could not be resolved."
		return {}
	var required_stat := str(_params.get("required_stat", ""))
	if required_stat.is_empty():
		_status_text = "This challenge is missing a required_stat value."
		return {}
	var current_value := target_entity.effective_stat(required_stat)
	var required_value := _read_required_value()
	var passed := current_value >= required_value
	if passed:
		_apply_success(target_entity)
		var success_sound := str(_params.get("success_sound", ""))
		if not success_sound.is_empty():
			AudioManager.play_sfx(success_sound)
		_status_text = "Success: %s met the %s threshold." % [
			PHASE4_HELPERS.get_entity_display_name(target_entity, target_entity.entity_id),
			PHASE4_HELPERS.humanize_id(required_stat),
		]
	else:
		_apply_failure()
		var failure_sound := str(_params.get("failure_sound", ""))
		if not failure_sound.is_empty():
			AudioManager.play_sfx(failure_sound)
		_status_text = "Failure: %s needs %.0f %s but only has %.0f." % [
			PHASE4_HELPERS.get_entity_display_name(target_entity, target_entity.entity_id),
			required_value,
			PHASE4_HELPERS.humanize_id(required_stat),
			current_value,
		]
	return {}


func _resolve_target_entity() -> EntityInstance:
	return PHASE4_HELPERS.resolve_entity_lookup(str(_params.get("target_entity_id", "player")))


func _resolve_portrait_entity(target_entity: EntityInstance) -> EntityInstance:
	var portrait_lookup := str(_params.get("portrait_entity_id", ""))
	if portrait_lookup.is_empty():
		return target_entity
	return PHASE4_HELPERS.resolve_entity_lookup(portrait_lookup)


func _apply_success(target_entity: EntityInstance) -> void:
	var reward_value: Variant = _params.get("reward", {})
	if reward_value is Dictionary:
		var target_clone := target_entity.duplicate_instance()
		RewardService.apply_reward(target_clone, reward_value)
		GameState.commit_entity_instance(target_clone, str(_params.get("target_entity_id", "player")))
	var action_payload_value: Variant = _params.get("action_payload", {})
	if action_payload_value is Dictionary:
		var action_payload: Dictionary = action_payload_value
		ActionDispatcher.dispatch(action_payload)


func _apply_failure() -> void:
	var failure_action_value: Variant = _params.get("failure_action_payload", {})
	if failure_action_value is Dictionary:
		var failure_action: Dictionary = failure_action_value
		ActionDispatcher.dispatch(failure_action)


func _build_status_text(target_entity: EntityInstance, required_stat: String, current_value: float, required_value: float) -> String:
	if not _status_text.is_empty():
		return _status_text
	if target_entity == null:
		return "The challenge target entity could not be resolved."
	if required_stat.is_empty():
		return "This challenge is missing a required_stat value."
	return "%s currently has %.0f %s. %.0f is required to pass." % [
		PHASE4_HELPERS.get_entity_display_name(target_entity, target_entity.entity_id),
		current_value,
		PHASE4_HELPERS.humanize_id(required_stat),
		required_value,
	]


func _read_required_value() -> float:
	var required_value: Variant = _params.get("required_value", 0.0)
	if required_value is int or required_value is float:
		return float(required_value)
	return 0.0
