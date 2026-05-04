extends "res://ui/screens/backends/backend_base.gd"

class_name OmniEncounterBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const ENCOUNTER_RUNTIME := preload("res://systems/encounter_runtime.gd")

const AI_LOG_TEMPLATE_ID := "base:encounter_log_flavor"
const AI_LOG_SYSTEM_PROMPT := "You rewrite resolved encounter actions for a game log. Preserve the supplied mechanical result and stat changes. Return exactly one short sentence."
const AI_LOG_MAX_LENGTH := 180
const AI_LOG_PENDING_TEXT := "Resolving action..."

var _params: Dictionary = {}
var _encounter_id: String = ""
var _template: Dictionary = {}
var _round: int = 1
var _max_rounds: int = 0
var _encounter_stats: Dictionary = {}
var _encounter_stat_defs: Dictionary = {}
var _player_tags: Dictionary = {}
var _opponent_tags: Dictionary = {}
var _log: Array[Dictionary] = []
var _resolved_outcome_id: String = ""
var _resolved_screen_text: String = ""
var _resolved_reward_lines: Array[String] = []
var _status_text: String = ""
var _player: EntityInstance = null
var _opponent: EntityInstance = null
var _rng := RandomNumberGenerator.new()
var _log_sequence: int = 0
var _ai_log_queue: Array[Dictionary] = []
var _ai_log_generation_active: bool = false


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("EncounterBackend", {
		"required": ["encounter_id"],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"player_entity_id",
			"opponent_entity_id",
			"participant_overrides",
			"next_screen_id",
			"next_screen_params",
			"pop_on_resolve",
			"default_sound",
		],
		"field_types": {
			"encounter_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"player_entity_id": TYPE_STRING,
			"opponent_entity_id": TYPE_STRING,
			"participant_overrides": TYPE_DICTIONARY,
			"next_screen_id": TYPE_STRING,
			"next_screen_params": TYPE_DICTIONARY,
			"pop_on_resolve": TYPE_BOOL,
			"default_sound": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_encounter_id = str(_params.get("encounter_id", "")).strip_edges()
	_template = DataManager.get_encounter(_encounter_id)
	_round = 1
	_max_rounds = 0
	_encounter_stats.clear()
	_encounter_stat_defs.clear()
	_player_tags.clear()
	_opponent_tags.clear()
	_log.clear()
	_resolved_outcome_id = ""
	_resolved_screen_text = ""
	_resolved_reward_lines.clear()
	_status_text = ""
	_log_sequence = 0
	_ai_log_queue.clear()
	_ai_log_generation_active = false
	_rng.randomize()
	if _template.is_empty():
		_status_text = "Encounter '%s' could not be found." % _encounter_id
		return
	_player = _resolve_participant("player")
	_opponent = _resolve_participant("opponent")
	if _player == null or _opponent == null:
		_status_text = "Encounter participants could not be resolved."
		return
	_initialize_encounter_stats()
	var resolution := _get_resolution()
	_max_rounds = int(resolution.get("max_rounds", 0))
	_apply_intro_action()
	_append_log("Encounter started.")
	if GameEvents:
		GameEvents.encounter_started.emit({
			"encounter_id": _encounter_id,
			"round": _round,
			"player_id": _player.entity_id,
			"opponent_id": _opponent.entity_id,
		})


func build_view_model() -> Dictionary:
	var title := str(_params.get("screen_title", _template.get("screen_title", _template.get("display_name", "Encounter"))))
	var description := str(_params.get("screen_description", _template.get("screen_description", _template.get("description", ""))))
	return {
		"encounter_id": _encounter_id,
		"title": title,
		"description": description,
		"round": _round,
		"player": BACKEND_HELPERS.build_entity_portrait_view_model(_player, "Player"),
		"opponent": BACKEND_HELPERS.build_entity_portrait_view_model(_opponent, "Opponent"),
		"encounter_stats": _build_encounter_stat_lines(),
		"actions": _build_player_action_models(),
		"log": _log.duplicate(true),
		"status_text": _build_status_text(),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"resolved": is_resolved(),
		"resolving_action": is_resolving_action(),
		"resolved_outcome_id": _resolved_outcome_id,
		"resolved_screen_text": _resolved_screen_text,
		"reward_lines": _resolved_reward_lines.duplicate(),
		"continue_label": "Continue",
	}


func select_action(action_id: String) -> Dictionary:
	if is_resolved():
		return {}
	if is_resolving_action():
		_status_text = "Action is still resolving."
		return {}
	if _player == null or _opponent == null:
		_status_text = "Encounter participants could not be resolved."
		return {}
	var action := _find_action("player", action_id)
	if action.is_empty():
		_status_text = "Unknown encounter action '%s'." % action_id
		return {}
	var context := _build_context()
	if not ENCOUNTER_RUNTIME.is_action_available(action, context):
		_status_text = "That action is not currently available."
		return {}
	var success := _resolve_action("player", action)
	_emit_action_resolved("player", action, success)
	var navigation := _evaluate_resolution(false)
	if not navigation.is_empty() or is_resolved():
		return {}
	_resolve_opponent_turn()
	navigation = _evaluate_resolution(true)
	if not navigation.is_empty() or is_resolved():
		return {}
	_decrement_tags()
	_advance_round()
	return {}


func cancel() -> Dictionary:
	if is_resolved():
		return {}
	var cancel_outcome := str(_get_resolution().get("cancel_outcome", _template.get("cancel_outcome", ""))).strip_edges()
	if not cancel_outcome.is_empty():
		_resolve(cancel_outcome, "cancel")
		return {}
	return {"type": "pop"}


func continue_after_resolution() -> Dictionary:
	if not is_resolved():
		return {}
	return _navigation_for_resolved()


func is_resolved() -> bool:
	return not _resolved_outcome_id.is_empty()


func is_resolving_action() -> bool:
	return _ai_log_generation_active or not _ai_log_queue.is_empty() or _has_pending_ai_log_entries()


func get_resolved_outcome_id() -> String:
	return _resolved_outcome_id


func _resolve_opponent_turn() -> void:
	var opponent_actions := _get_actions_for_role("opponent")
	var action := ENCOUNTER_RUNTIME.pick_weighted_action(opponent_actions, _build_context(), _rng)
	if action.is_empty():
		_append_log("The opponent hesitates.")
		return
	var success := _resolve_action("opponent", action)
	_emit_action_resolved("opponent", action, success)


func _resolve_action(role: String, action: Dictionary) -> bool:
	var user := _player if role == "player" else _opponent
	var target := _opponent if role == "player" else _player
	var before_state := _build_ai_state_snapshot()
	for effect in ENCOUNTER_RUNTIME.read_effects(action.get("cost", [])):
		if _apply_effect(effect, user, target, action, {
			"role": role,
			"phase": "cost",
			"success": false,
			"before_state": before_state,
		}):
			return false
	var success := ENCOUNTER_RUNTIME.evaluate_action_check(action, _build_context())
	var effects := ENCOUNTER_RUNTIME.read_effects(action.get("on_success" if success else "on_failure", []))
	for effect in effects:
		if _apply_effect(effect, user, target, action, {
			"role": role,
			"phase": "success" if success else "failure",
			"success": success,
			"before_state": before_state,
		}):
			break
	if effects.is_empty():
		_append_log("%s %s." % [_display_name(user), "succeeds" if success else "fails"], {
			"role": role,
			"phase": "success" if success else "failure",
			"success": success,
			"before_state": before_state,
			"action": action.duplicate(true),
			"user_name": _display_name(user),
			"target_name": _display_name(target),
		})
	return success


func _apply_effect(effect: Dictionary, user: EntityInstance, target: EntityInstance, action: Dictionary, action_context: Dictionary = {}) -> bool:
	var effect_type := str(effect.get("effect", "")).strip_edges()
	match effect_type:
		"modify_stat":
			_apply_modify_stat(effect, user, target)
		"modify_encounter_stat":
			_apply_modify_encounter_stat(effect, user, target)
		"set_encounter_stat":
			_apply_set_encounter_stat(effect)
		"set_flag":
			_apply_set_flag(effect)
		"log":
			var ai_context := action_context.duplicate(true)
			ai_context["action"] = action.duplicate(true)
			ai_context["user_name"] = _display_name(user)
			ai_context["target_name"] = _display_name(target)
			_append_log(_format_log_text(str(effect.get("text", "")), user, target, action), ai_context)
		"apply_tag":
			_apply_tag(effect, user, target)
		"remove_tag":
			_apply_remove_tag(effect, user, target)
		"resolve":
			var outcome_id := str(effect.get("outcome_id", "")).strip_edges()
			if not outcome_id.is_empty():
				_resolve(outcome_id, "manual")
				return true
		_:
			if not effect_type.is_empty():
				push_warning("EncounterBackend: unsupported effect '%s'." % effect_type)
	return is_resolved()


func _apply_modify_stat(effect: Dictionary, user: EntityInstance, fallback_target: EntityInstance) -> void:
	var target_role := str(effect.get("target", "target"))
	var target := _participant_for_effect_target(target_role, user, fallback_target)
	if target == null:
		return
	var stat_id := str(effect.get("stat", effect.get("stat_id", ""))).strip_edges()
	if stat_id.is_empty() or not target.has_stat(stat_id):
		return
	var delta := ENCOUNTER_RUNTIME.compute_delta(effect, user, target)
	var clone := target.duplicate_instance()
	clone.modify_stat(stat_id, delta)
	GameState.commit_entity_instance(clone, "player" if target == _player else target.entity_id)
	if target == _player:
		_player = clone
	elif target == _opponent:
		_opponent = clone


func _apply_modify_encounter_stat(effect: Dictionary, user: EntityInstance, target: EntityInstance) -> void:
	var stat_id := str(effect.get("stat", "")).strip_edges()
	if stat_id.is_empty():
		return
	var current := float(_encounter_stats.get(stat_id, 0.0))
	var next_value := current + ENCOUNTER_RUNTIME.compute_delta(effect, user, target)
	_encounter_stats[stat_id] = ENCOUNTER_RUNTIME.clamp_encounter_stat(stat_id, next_value, _encounter_stat_defs)


func _apply_set_encounter_stat(effect: Dictionary) -> void:
	var stat_id := str(effect.get("stat", "")).strip_edges()
	if stat_id.is_empty():
		return
	var value := float(effect.get("value", 0.0))
	if bool(effect.get("clamp", true)):
		value = ENCOUNTER_RUNTIME.clamp_encounter_stat(stat_id, value, _encounter_stat_defs)
	_encounter_stats[stat_id] = value


func _apply_set_flag(effect: Dictionary) -> void:
	var flag_id := str(effect.get("flag_id", effect.get("key", ""))).strip_edges()
	if flag_id.is_empty():
		return
	var entity_id := str(effect.get("entity_id", "global"))
	if entity_id == "global":
		GameState.set_flag(flag_id, effect.get("value", true))
		return
	var entity := BACKEND_HELPERS.resolve_entity_lookup(entity_id)
	if entity != null:
		entity.set_flag(flag_id, effect.get("value", true))


func _apply_tag(effect: Dictionary, user: EntityInstance, fallback_target: EntityInstance) -> void:
	var target_role := str(effect.get("target", "target"))
	var tag_map: Dictionary = _tag_map_for_effect_target(target_role, user, fallback_target)
	if tag_map.is_empty() and not _effect_target_is_participant(target_role, user, fallback_target):
		return
	var tag_id := str(effect.get("tag", effect.get("tag_id", ""))).strip_edges()
	if tag_id.is_empty():
		return
	var duration: int = maxi(1, int(effect.get("duration_rounds", effect.get("duration", 1))))
	tag_map[tag_id] = duration


func _apply_remove_tag(effect: Dictionary, user: EntityInstance, fallback_target: EntityInstance) -> void:
	var target_role := str(effect.get("target", "target"))
	var tag_map: Dictionary = _tag_map_for_effect_target(target_role, user, fallback_target)
	if tag_map.is_empty() and not _effect_target_is_participant(target_role, user, fallback_target):
		return
	var tag_id := str(effect.get("tag", effect.get("tag_id", ""))).strip_edges()
	if tag_id.is_empty():
		return
	tag_map.erase(tag_id)


func _evaluate_resolution(include_max_rounds: bool = true) -> Dictionary:
	if is_resolved():
		return {}
	var outcome := _find_matching_outcome()
	if not outcome.is_empty():
		return _resolve(str(outcome.get("outcome_id", "")), "automatic")
	if include_max_rounds and _max_rounds > 0 and _round >= _max_rounds:
		var max_rounds_outcome := str(_get_resolution().get("max_rounds_outcome", "")).strip_edges()
		if not max_rounds_outcome.is_empty():
			return _resolve(max_rounds_outcome, "max_rounds")
	return {}


func _find_matching_outcome() -> Dictionary:
	var outcomes := _get_outcomes()
	for outcome in outcomes:
		if str(outcome.get("trigger", "automatic")) == "manual":
			continue
		var conditions_value: Variant = outcome.get("conditions", {})
		if conditions_value is Dictionary and ConditionEvaluator.evaluate(conditions_value, _build_context()):
			return outcome
	return {}


func _resolve(outcome_id: String, reason: String) -> Dictionary:
	if is_resolved():
		return {}
	var outcome := _get_outcome(outcome_id)
	if outcome.is_empty():
		_status_text = "Encounter outcome '%s' could not be found." % outcome_id
		return {}
	var reward_value: Variant = outcome.get("reward", {})
	_resolved_reward_lines = RewardService.build_reward_lines(reward_value)
	if reward_value is Dictionary and _player != null:
		RewardService.apply_reward(_player, reward_value)
	var action_payload_value: Variant = outcome.get("action_payload", null)
	if action_payload_value is Dictionary:
		var action_payload: Dictionary = action_payload_value
		if not action_payload.is_empty():
			ActionDispatcher.dispatch(action_payload)
	_resolved_outcome_id = outcome_id
	_resolved_screen_text = str(outcome.get("screen_text", "Encounter resolved."))
	_status_text = _resolved_screen_text
	_append_log(_resolved_screen_text)
	_emit_resolution_feedback(outcome_id, reason, reward_value)
	if GameEvents:
		GameEvents.encounter_resolved.emit({
			"encounter_id": _encounter_id,
			"round": _round,
			"outcome_id": outcome_id,
			"reason": reason,
		})
	var sound_ref := str(outcome.get("sound", _params.get("default_sound", _template.get("default_sound", ""))))
	if not sound_ref.is_empty():
		AudioManager.play_sfx(sound_ref)
	return {}


func _emit_resolution_feedback(outcome_id: String, reason: String, reward_value: Variant) -> void:
	var display_name := str(_template.get("display_name", _template.get("screen_title", _encounter_id)))
	var reward_summary := RewardService.build_reward_summary(reward_value, "No rewards")
	var message := "Encounter complete: %s" % display_name
	if not reward_summary.is_empty():
		message = "%s | Rewards: %s" % [message, reward_summary]
	GameState.record_event("encounter_resolved", {
		"encounter_id": _encounter_id,
		"outcome_id": outcome_id,
		"reason": reason,
		"round": _round,
		"display_name": display_name,
		"reward_summary": reward_summary,
		"description": message,
	})
	if GameEvents:
		GameEvents.ui_notification_requested.emit(message, OmniConstants.NOTIFICATION_LEVEL_INFO)


func _navigation_for_resolved() -> Dictionary:
	var outcome := _get_outcome(_resolved_outcome_id)
	var next_screen_id := str(_params.get("next_screen_id", outcome.get("next_screen_id", ""))).strip_edges()
	if not next_screen_id.is_empty():
		return {
			"type": "push",
			"screen_id": next_screen_id,
			"params": _read_dictionary(_params.get("next_screen_params", outcome.get("next_screen_params", {}))),
		}
	if bool(_params.get("pop_on_resolve", outcome.get("pop_on_resolve", false))):
		return {"type": "pop"}
	return {}


func _advance_round() -> void:
	_round += 1
	if _encounter_stats.has("round"):
		_encounter_stats["round"] = float(_round)
	if GameEvents:
		GameEvents.encounter_round_advanced.emit(_encounter_id, _round)


func _decrement_tags() -> void:
	_decrement_tag_map(_player_tags)
	_decrement_tag_map(_opponent_tags)


func _decrement_tag_map(tag_map: Dictionary) -> void:
	var expired_tags: Array[String] = []
	for tag_key_value in tag_map.keys():
		var tag_id := str(tag_key_value)
		var remaining := int(tag_map.get(tag_key_value, 0)) - 1
		if remaining <= 0:
			expired_tags.append(tag_id)
		else:
			tag_map[tag_id] = remaining
	for tag_id in expired_tags:
		tag_map.erase(tag_id)


func _build_player_action_models() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var context := _build_context()
	var resolving_action := is_resolving_action()
	for action in _get_actions_for_role("player"):
		var action_id := str(action.get("action_id", ""))
		var available := ENCOUNTER_RUNTIME.is_action_available(action, context)
		var tooltip := ""
		if resolving_action:
			tooltip = "Current action is still resolving."
		elif not available:
			tooltip = "Requirements are not currently met."
		result.append({
			"action_id": action_id,
			"label": str(action.get("label", BACKEND_HELPERS.humanize_id(action_id))),
			"description": str(action.get("description", "")),
			"available": available and not is_resolved() and not resolving_action,
			"tooltip": tooltip,
		})
	return result


func _build_encounter_stat_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys: Array = _encounter_stats.keys()
	keys.sort()
	for key_value in keys:
		var stat_id := str(key_value)
		var stat_def_value: Variant = _encounter_stat_defs.get(stat_id, {})
		var stat_def: Dictionary = stat_def_value if stat_def_value is Dictionary else {}
		var max_value := float(stat_def.get("max", 0.0))
		result.append({
			"stat_id": stat_id,
			"label": str(stat_def.get("label", BACKEND_HELPERS.humanize_id(stat_id))),
			"value": float(_encounter_stats.get(stat_id, 0.0)),
			"max_value": max_value,
			"color_token": str(stat_def.get("color_token", "info")),
		})
	return result


func _initialize_encounter_stats() -> void:
	var stats_value: Variant = _template.get("encounter_stats", {})
	if not stats_value is Dictionary:
		return
	var stats: Dictionary = stats_value
	for stat_key_value in stats.keys():
		var stat_id := str(stat_key_value)
		var stat_def_value: Variant = stats.get(stat_key_value, {})
		var stat_def: Dictionary = stat_def_value if stat_def_value is Dictionary else {}
		_encounter_stat_defs[stat_id] = stat_def.duplicate(true)
		var default_value := float(stat_def.get("default", 0.0))
		_encounter_stats[stat_id] = ENCOUNTER_RUNTIME.clamp_encounter_stat(stat_id, default_value, _encounter_stat_defs)


func _resolve_participant(role: String) -> EntityInstance:
	var override_id := _participant_override(role)
	if override_id.is_empty():
		var participants_value: Variant = _template.get("participants", {})
		if participants_value is Dictionary:
			var participants: Dictionary = participants_value
			var participant_value: Variant = participants.get(role, {})
			if participant_value is Dictionary:
				var participant: Dictionary = participant_value
				override_id = str(participant.get("entity_id", "player" if role == "player" else ""))
	return BACKEND_HELPERS.resolve_entity_lookup(override_id)


func _participant_override(role: String) -> String:
	if role == "player":
		var player_override := str(_params.get("player_entity_id", "")).strip_edges()
		if not player_override.is_empty():
			return player_override
	if role == "opponent":
		var opponent_override := str(_params.get("opponent_entity_id", "")).strip_edges()
		if not opponent_override.is_empty():
			return opponent_override
	var overrides_value: Variant = _params.get("participant_overrides", {})
	if overrides_value is Dictionary:
		var overrides: Dictionary = overrides_value
		return str(overrides.get(role, "")).strip_edges()
	return ""


func _get_actions_for_role(role: String) -> Array:
	var actions_value: Variant = _template.get("actions", {})
	if not actions_value is Dictionary:
		return []
	var actions: Dictionary = actions_value
	var role_actions_value: Variant = actions.get(role, [])
	if role_actions_value is Array:
		return role_actions_value
	return []


func _find_action(role: String, action_id: String) -> Dictionary:
	for action_value in _get_actions_for_role(role):
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		if str(action.get("action_id", "")) == action_id:
			return action.duplicate(true)
	return {}


func _get_resolution() -> Dictionary:
	var resolution_value: Variant = _template.get("resolution", {})
	if resolution_value is Dictionary:
		var resolution: Dictionary = resolution_value
		return resolution
	return {}


func _get_outcomes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var outcomes_value: Variant = _get_resolution().get("outcomes", [])
	if not outcomes_value is Array:
		return result
	var outcomes: Array = outcomes_value
	for outcome_value in outcomes:
		if outcome_value is Dictionary:
			result.append((outcome_value as Dictionary).duplicate(true))
	return result


func _get_outcome(outcome_id: String) -> Dictionary:
	for outcome in _get_outcomes():
		if str(outcome.get("outcome_id", "")) == outcome_id:
			return outcome
	return {}


func _build_context() -> Dictionary:
	return ENCOUNTER_RUNTIME.build_condition_context(_player, _opponent, _encounter_stats, _player_tags, _opponent_tags)


func _participant_for_effect_target(target_role: String, user: EntityInstance, fallback_target: EntityInstance) -> EntityInstance:
	match target_role:
		"player":
			return _player
		"opponent":
			return _opponent
		"user":
			return user
		"target":
			return fallback_target
	return fallback_target


func _tag_map_for_effect_target(target_role: String, user: EntityInstance, fallback_target: EntityInstance) -> Dictionary:
	var participant := _participant_for_effect_target(target_role, user, fallback_target)
	if participant == _player:
		return _player_tags
	if participant == _opponent:
		return _opponent_tags
	return {}


func _effect_target_is_participant(target_role: String, user: EntityInstance, fallback_target: EntityInstance) -> bool:
	var participant := _participant_for_effect_target(target_role, user, fallback_target)
	return participant == _player or participant == _opponent


func _emit_action_resolved(role: String, action: Dictionary, success: bool) -> void:
	if GameEvents:
		GameEvents.encounter_action_resolved.emit({
			"encounter_id": _encounter_id,
			"round": _round,
			"actor": role,
			"action_id": str(action.get("action_id", "")),
			"success": success,
		})


func _append_log(text: String, ai_context: Dictionary = {}) -> void:
	var normalized_text := text.strip_edges()
	if normalized_text.is_empty():
		return
	_log_sequence += 1
	var entry_id := "%s:%d:%d" % [_encounter_id, _round, _log_sequence]
	var ai_request := _build_ai_log_request(entry_id, normalized_text, ai_context)
	var display_text := AI_LOG_PENDING_TEXT if not ai_request.is_empty() else normalized_text
	_log.append({
		"entry_id": entry_id,
		"round": _round,
		"text": display_text,
		"fallback_text": normalized_text,
		"ai_pending": not ai_request.is_empty(),
	})
	while _log.size() > 50:
		_log.pop_front()
	if not ai_request.is_empty():
		_enqueue_ai_log_request(ai_request)


func _build_ai_log_request(entry_id: String, fallback_text: String, ai_context: Dictionary) -> Dictionary:
	if ai_context.is_empty():
		return {}
	if not ScriptHookService.can_run_world_gen("encounter_log_flavor_enabled"):
		return {}
	var ai_template := DataManager.get_ai_template(AI_LOG_TEMPLATE_ID)
	if ai_template.is_empty():
		return {}
	var tokens := _build_ai_log_tokens(fallback_text, ai_context)
	var prompt := _resolve_template_tokens(str(ai_template.get("prompt_template", "")), tokens)
	if prompt.is_empty():
		return {}
	return {
		"entry_id": entry_id,
		"prompt": prompt,
		"fallback_text": fallback_text,
	}


func _enqueue_ai_log_request(ai_request: Dictionary) -> void:
	_ai_log_queue.append(ai_request.duplicate(true))
	if not _ai_log_generation_active:
		_process_ai_log_queue_async()


func _process_ai_log_queue_async() -> void:
	if _ai_log_generation_active:
		return
	_ai_log_generation_active = true
	while not _ai_log_queue.is_empty():
		var request: Dictionary = _ai_log_queue.pop_front()
		await _await_process_frame()
		await _generate_ai_log_flavor_async(
			str(request.get("entry_id", "")),
			str(request.get("prompt", "")),
			str(request.get("fallback_text", ""))
		)
	_ai_log_generation_active = false


func _generate_ai_log_flavor_async(entry_id: String, prompt: String, fallback_text: String) -> void:
	var response := await AIManager.generate_async(prompt, {
		"system_prompt": AI_LOG_SYSTEM_PROMPT,
	})
	var final_text := _sanitize_ai_log_text(response)
	if final_text.is_empty():
		final_text = fallback_text
	_update_log_entry_text(entry_id, final_text)
	if GameEvents:
		GameEvents.event_narrated.emit("encounter_log", entry_id, final_text)


func _await_process_frame() -> void:
	var main_loop := Engine.get_main_loop()
	var tree := main_loop as SceneTree
	if tree == null:
		return
	await tree.process_frame


func _update_log_entry_text(entry_id: String, text: String) -> void:
	for index in range(_log.size()):
		var entry: Dictionary = _log[index]
		if str(entry.get("entry_id", "")) != entry_id:
			continue
		entry["text"] = text
		entry["ai_pending"] = false
		_log[index] = entry
		return


func _has_pending_ai_log_entries() -> bool:
	for entry_value in _log:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if bool(entry.get("ai_pending", false)):
			return true
	return false


func _mark_log_entry_ai_done(entry_id: String) -> void:
	for index in range(_log.size()):
		var entry: Dictionary = _log[index]
		if str(entry.get("entry_id", "")) != entry_id:
			continue
		entry["ai_pending"] = false
		_log[index] = entry
		return


func _build_ai_log_tokens(fallback_text: String, ai_context: Dictionary) -> Dictionary:
	var action := _read_dictionary(ai_context.get("action", {}))
	var before_state := _read_dictionary(ai_context.get("before_state", {}))
	var result := "success" if bool(ai_context.get("success", false)) else "failure"
	return {
		"encounter_name": str(_template.get("display_name", _template.get("screen_title", _encounter_id))),
		"actor_role": str(ai_context.get("role", "")),
		"actor_name": str(ai_context.get("user_name", "Someone")),
		"target_name": str(ai_context.get("target_name", "someone")),
		"action_id": str(action.get("action_id", "")),
		"action_label": str(action.get("label", action.get("action_id", ""))),
		"phase": str(ai_context.get("phase", "")),
		"result": result,
		"fallback_text": fallback_text,
		"stat_delta_summary": _build_stat_delta_summary(before_state),
	}


func _build_ai_state_snapshot() -> Dictionary:
	return {
		"player_stats": _read_entity_stats(_player),
		"opponent_stats": _read_entity_stats(_opponent),
		"encounter_stats": _encounter_stats.duplicate(true),
	}


func _build_stat_delta_summary(before_state: Dictionary) -> String:
	var parts: Array[String] = []
	_append_stat_delta_parts(parts, "player", _read_dictionary(before_state.get("player_stats", {})), _read_entity_stats(_player))
	_append_stat_delta_parts(parts, "opponent", _read_dictionary(before_state.get("opponent_stats", {})), _read_entity_stats(_opponent))
	_append_stat_delta_parts(parts, "encounter", _read_dictionary(before_state.get("encounter_stats", {})), _encounter_stats)
	if parts.is_empty():
		return "no mechanical stat changes"
	return ", ".join(parts)


func _append_stat_delta_parts(parts: Array[String], label: String, before_stats: Dictionary, after_stats: Dictionary) -> void:
	var keys: Array = before_stats.keys()
	for after_key_value in after_stats.keys():
		if not keys.has(after_key_value):
			keys.append(after_key_value)
	keys.sort()
	for key_value in keys:
		var stat_id := str(key_value)
		var before_value := float(before_stats.get(key_value, 0.0))
		var after_value := float(after_stats.get(key_value, 0.0))
		var delta := after_value - before_value
		if is_zero_approx(delta):
			continue
		parts.append("%s %s %s" % [label, stat_id, _format_signed_number(delta)])


func _read_entity_stats(entity: EntityInstance) -> Dictionary:
	var stats: Dictionary = {}
	if entity == null:
		return stats
	for stat_key_value in entity.stats.keys():
		stats[str(stat_key_value)] = float(entity.stats.get(stat_key_value, 0.0))
	return stats


func _format_signed_number(value: float) -> String:
	var abs_value := absf(value)
	var value_text := str(int(abs_value)) if is_equal_approx(abs_value, float(int(abs_value))) else "%.2f" % abs_value
	return "+%s" % value_text if value >= 0.0 else "-%s" % value_text


func _sanitize_ai_log_text(text: String) -> String:
	var sanitized := text.strip_edges().replace("\n", " ")
	while sanitized.contains("  "):
		sanitized = sanitized.replace("  ", " ")
	if sanitized.length() > AI_LOG_MAX_LENGTH:
		sanitized = sanitized.substr(0, AI_LOG_MAX_LENGTH).strip_edges()
	return sanitized


func _resolve_template_tokens(template_text: String, tokens: Dictionary) -> String:
	var resolved_text := template_text
	for token_key_value in tokens.keys():
		var token_key := str(token_key_value)
		resolved_text = resolved_text.replace("{%s}" % token_key, str(tokens.get(token_key_value, "")))
	return resolved_text.strip_edges()


func _format_log_text(text: String, user: EntityInstance, target: EntityInstance, action: Dictionary) -> String:
	return text.replace("{user_name}", _display_name(user)).replace("{target_name}", _display_name(target)).replace("{action_label}", str(action.get("label", action.get("action_id", ""))))


func _display_name(entity: EntityInstance) -> String:
	if entity == null:
		return "Someone"
	return BACKEND_HELPERS.get_entity_display_name(entity, entity.entity_id)


func _build_status_text() -> String:
	if is_resolved():
		return _resolved_screen_text
	if not _status_text.is_empty():
		return _status_text
	return "Round %d" % _round


func _apply_intro_action() -> void:
	var intro_action_value: Variant = _template.get("intro_action_payload", null)
	if intro_action_value is Dictionary:
		var intro_action: Dictionary = intro_action_value
		if not intro_action.is_empty():
			ActionDispatcher.dispatch(intro_action)


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
