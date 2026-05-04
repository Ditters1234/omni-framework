## QuestTracker — Manages active quest state machines.
## Uses LimboAI HSMs built dynamically from quest JSON templates.
## Quest JSON defines states and transitions; QuestTracker drives them.
## State is persisted in GameState.active_quests.
##
## NOTE: LimboAI HSM integration requires a spike during early development.
## The public API below is stable; the HSM internals are TBD.
extends Node

class_name QuestTracker

var _refreshing_quests: Dictionary = {}


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick)
	GameEvents.location_changed.connect(_on_location_changed)
	GameEvents.part_acquired.connect(_on_inventory_changed)
	GameEvents.part_removed.connect(_on_inventory_changed)
	GameEvents.entity_stat_changed.connect(_on_entity_state_changed)
	GameEvents.entity_currency_changed.connect(_on_entity_state_changed)
	GameEvents.flag_changed.connect(_on_flag_changed)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Starts a quest by id. No-op if already active or completed.
## Returns true on success.
func start_quest(quest_id: String, params: Dictionary = {}) -> bool:
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		push_warning("QuestTracker: unknown quest '%s'" % quest_id)
		return false
	var repeatable := bool(template.get("repeatable", false))
	var runtime_id := _resolve_runtime_id(quest_id, template, params)
	if runtime_id.is_empty():
		return false
	if GameState.active_quests.has(runtime_id):
		return false
	if _has_active_quest_template(quest_id) and not bool(params.get("allow_duplicate", false)):
		return false
	if is_quest_complete(quest_id) and not repeatable:
		return false
	_create_quest_instance(template, runtime_id, params)
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		ScriptHookService.invoke_template_hook(template, "on_quest_start", [quest_instance.duplicate(true)])
	GameEvents.quest_started.emit(quest_id)
	_refresh_quest(runtime_id)
	return true


## Advances a quest's state machine by signaling a named transition.
func advance_quest(quest_id: String, transition: String) -> void:
	var runtime_id := _resolve_active_runtime_id(quest_id)
	if runtime_id.is_empty():
		return
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	if not quest_instance_data is Dictionary:
		return
	var quest_instance: Dictionary = quest_instance_data
	var template := DataManager.get_quest(str(quest_instance.get("quest_id", quest_id)))
	if template.is_empty():
		return
	var stages_data: Variant = template.get("stages", [])
	if not stages_data is Array:
		return
	var stages: Array = stages_data
	var current_stage_index := int(quest_instance.get("stage_index", 0))
	if current_stage_index < 0 or current_stage_index >= stages.size():
		complete_quest(runtime_id)
		return
	# Advance the index first so that any hook fired by _apply_stage_completion
	# sees the updated stage number rather than the old one.
	var next_stage_index := current_stage_index + 1
	if transition != "":
		quest_instance["last_transition"] = transition
	quest_instance["stage_index"] = next_stage_index
	# Mark the stage we just completed so _refresh_quest_inner won't re-apply
	# its rewards if it runs before the next tick.
	var completed_stages: Array = quest_instance.get("_completed_stages", [])
	if current_stage_index not in completed_stages:
		completed_stages.append(current_stage_index)
	quest_instance["_completed_stages"] = completed_stages
	GameState.active_quests[runtime_id] = quest_instance
	# Apply completion rewards for the stage we just finished.
	var current_stage_data: Variant = stages[current_stage_index]
	if current_stage_data is Dictionary:
		var current_stage: Dictionary = current_stage_data
		_apply_stage_completion(current_stage, quest_instance)
	if next_stage_index >= stages.size():
		_complete_active_quest(runtime_id, template)
		return
	GameEvents.quest_stage_advanced.emit(str(quest_instance.get("quest_id", quest_id)), next_stage_index)
	# Do NOT call _refresh_quest here — _apply_stage_completion may have already
	# triggered an auto-advance via event listeners, and calling it again would
	# double-fire rewards for any stages whose objectives are already met.
	# The next tick / event will naturally trigger _refresh_active_quests.


## Completes a quest manually (e.g. from a script hook).
func complete_quest(quest_id: String) -> void:
	var runtime_id := _resolve_active_runtime_id(quest_id)
	if runtime_id.is_empty():
		return
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	var template_id := quest_id
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		template_id = str(quest_instance.get("quest_id", quest_id))
	var template := DataManager.get_quest(template_id)
	_complete_active_quest(runtime_id, template)


## Fails a quest.
func fail_quest(quest_id: String) -> void:
	var runtime_id := _resolve_active_runtime_id(quest_id)
	if runtime_id.is_empty():
		return
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	var template_id := quest_id
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		template_id = str(quest_instance.get("quest_id", quest_id))
	var template := DataManager.get_quest(template_id)
	GameState.active_quests.erase(runtime_id)
	if quest_instance_data is Dictionary:
		var quest_instance_for_hook: Dictionary = quest_instance_data
		ScriptHookService.invoke_template_hook(template, "on_quest_fail", [quest_instance_for_hook.duplicate(true)])
	GameEvents.quest_failed.emit(template_id)


## Returns true if the quest is currently active.
func is_quest_active(quest_id: String) -> bool:
	return not _resolve_active_runtime_id(quest_id).is_empty()


## Returns true if the quest has been completed.
func is_quest_complete(quest_id: String) -> bool:
	return quest_id in GameState.completed_quests


## Returns the active quest instance dict, or empty dict.
func get_quest_instance(quest_id: String) -> Dictionary:
	var runtime_id := _resolve_active_runtime_id(quest_id)
	if runtime_id.is_empty():
		return {}
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		return quest_instance.duplicate(true)
	return {}


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_quest_instance(template: Dictionary, runtime_id: String, params: Dictionary) -> void:
	var quest_id := str(template.get("quest_id", ""))
	if quest_id.is_empty() or runtime_id.is_empty():
		return
	var assignee_entity_id := _resolve_entity_id(str(params.get("assignee_entity_id", params.get("entity_id", template.get("assignee_entity_id", "player")))), "player")
	var owner_entity_id := _resolve_entity_id(str(params.get("owner_entity_id", template.get("owner_entity_id", "player"))), "player")
	var reward_recipient_entity_id := _resolve_entity_id(str(params.get("reward_recipient_entity_id", template.get("reward_recipient_entity_id", owner_entity_id))), owner_entity_id)
	GameState.active_quests[runtime_id] = {
		"runtime_id": runtime_id,
		"quest_id": quest_id,
		"stage_index": 0,
		"assignee_entity_id": assignee_entity_id,
		"owner_entity_id": owner_entity_id,
		"reward_recipient_entity_id": reward_recipient_entity_id,
		"started_day": GameState.current_day,
		"started_tick": GameState.current_tick,
	}


func _on_tick(_tick: int) -> void:
	_refresh_active_quests()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh_active_quests()


func _on_inventory_changed(_entity_id: String, _part_id: String) -> void:
	_refresh_active_quests()


func _on_entity_state_changed(_entity_id: String, _key: String, _old_value: float, _new_value: float) -> void:
	_refresh_active_quests()


func _on_flag_changed(_entity_id: String, _flag_id: String, _value: Variant) -> void:
	_refresh_active_quests()


func _refresh_active_quests() -> void:
	var active_ids: Array[String] = []
	for quest_id_value in GameState.active_quests.keys():
		active_ids.append(str(quest_id_value))
	for quest_id in active_ids:
		_refresh_quest(quest_id)


func _refresh_quest(runtime_id: String) -> void:
	if _refreshing_quests.has(runtime_id):
		return
	_refreshing_quests[runtime_id] = true
	_refresh_quest_inner(runtime_id)
	_refreshing_quests.erase(runtime_id)


func _refresh_quest_inner(runtime_id: String) -> void:
	if not GameState.active_quests.has(runtime_id):
		return
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	if not quest_instance_data is Dictionary:
		return
	var quest_instance: Dictionary = quest_instance_data
	var quest_id := str(quest_instance.get("quest_id", runtime_id))
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		return
	var stages_data: Variant = template.get("stages", [])
	if not stages_data is Array:
		return
	var stages: Array = stages_data
	var safety_limit := stages.size() + 1
	while safety_limit > 0 and GameState.active_quests.has(runtime_id):
		safety_limit -= 1
		quest_instance_data = GameState.active_quests.get(runtime_id, {})
		if not quest_instance_data is Dictionary:
			return
		quest_instance = quest_instance_data
		var stage_index := int(quest_instance.get("stage_index", 0))
		if stage_index < 0 or stage_index >= stages.size():
			_complete_active_quest(runtime_id, template)
			return
		var stage_data: Variant = stages[stage_index]
		if not stage_data is Dictionary:
			return
		var stage: Dictionary = stage_data
		if not _is_stage_complete(stage, quest_instance):
			return
		# Guard against double-applying rewards for stages already completed
		# by advance_quest() on the same frame.
		var completed_stages: Array = quest_instance.get("_completed_stages", [])
		if stage_index in completed_stages:
			return
		completed_stages.append(stage_index)
		quest_instance["_completed_stages"] = completed_stages
		_apply_stage_completion(stage, quest_instance)
		var next_stage_index := stage_index + 1
		quest_instance["last_transition"] = "objectives_met"
		if next_stage_index >= stages.size():
			_complete_active_quest(runtime_id, template)
			return
		quest_instance["stage_index"] = next_stage_index
		GameState.active_quests[runtime_id] = quest_instance
		GameEvents.quest_stage_advanced.emit(quest_id, next_stage_index)


func _is_stage_complete(stage: Dictionary, quest_instance: Dictionary) -> bool:
	var objectives_data: Variant = stage.get("objectives", [])
	if not objectives_data is Array:
		return false
	var objectives: Array = objectives_data
	if objectives.is_empty():
		return true
	var context := _build_quest_context(quest_instance)
	for objective_data in objectives:
		if not objective_data is Dictionary:
			return false
		var objective: Dictionary = objective_data
		if not ConditionEvaluator.evaluate(objective, context):
			return false
	return true


func _apply_stage_completion(stage: Dictionary, quest_instance: Dictionary) -> void:
	var reward_recipient := _resolve_quest_entity(quest_instance, "reward_recipient")
	if reward_recipient != null:
		RewardService.apply_reward(reward_recipient, stage.get("reward", {}))
	var action_payload_data: Variant = stage.get("action_payload", null)
	if action_payload_data is Dictionary:
		ActionDispatcher.dispatch(action_payload_data)
	var actions_data: Variant = stage.get("actions", null)
	if actions_data is Array:
		var actions: Array = actions_data
		ActionDispatcher.dispatch_all(actions)


func _complete_active_quest(runtime_id: String, template: Dictionary) -> void:
	if not GameState.active_quests.has(runtime_id):
		return
	var quest_instance_data: Variant = GameState.active_quests.get(runtime_id, {})
	if not quest_instance_data is Dictionary:
		return
	var quest_instance: Dictionary = quest_instance_data
	var quest_id := str(quest_instance.get("quest_id", runtime_id))
	GameState.active_quests.erase(runtime_id)
	if not quest_id in GameState.completed_quests:
		GameState.completed_quests.append(quest_id)
	var reward_recipient := _resolve_quest_entity(quest_instance, "reward_recipient")
	if reward_recipient != null:
		RewardService.apply_reward(reward_recipient, template.get("reward", {}))
	var action_payload_data: Variant = template.get("action_payload", null)
	if action_payload_data is Dictionary:
		ActionDispatcher.dispatch(action_payload_data)
	var actions_data: Variant = template.get("actions", null)
	if actions_data is Array:
		var actions: Array = actions_data
		ActionDispatcher.dispatch_all(actions)
	ScriptHookService.invoke_template_hook(template, "on_quest_complete", [quest_instance.duplicate(true)])
	var complete_sound := str(template.get("complete_sound", ""))
	if not complete_sound.is_empty():
		AudioManager.play_sfx(complete_sound)
	GameEvents.quest_completed.emit(quest_id)
	_emit_quest_completion_feedback(quest_id, template, quest_instance)
	ScriptHookService.invoke_world_event_narration("quest_completed", [quest_id])


func _emit_quest_completion_feedback(quest_id: String, template: Dictionary, quest_instance: Dictionary) -> void:
	var display_name := str(template.get("display_name", template.get("title", quest_id)))
	var reward_value: Variant = template.get("reward", {})
	var reward_summary := RewardService.build_reward_summary(reward_value, "No rewards")
	var assignee_entity := _resolve_quest_entity(quest_instance, "assignee")
	var assignee_name := _entity_display_name(assignee_entity)
	var message := "Quest complete: %s" % display_name
	if not assignee_name.is_empty() and assignee_entity != GameState.player:
		message = "%s (%s)" % [message, assignee_name]
	if not reward_summary.is_empty():
		message = "%s | Rewards: %s" % [message, reward_summary]
	GameState.record_event("quest_completed", {
		"quest_id": quest_id,
		"runtime_id": str(quest_instance.get("runtime_id", quest_id)),
		"assignee_entity_id": str(quest_instance.get("assignee_entity_id", "player")),
		"reward_recipient_entity_id": str(quest_instance.get("reward_recipient_entity_id", "player")),
		"display_name": display_name,
		"reward_summary": reward_summary,
		"description": message,
	})
	GameEvents.ui_notification_requested.emit(message, OmniConstants.NOTIFICATION_LEVEL_INFO)


func _resolve_runtime_id(quest_id: String, template: Dictionary, params: Dictionary) -> String:
	var explicit_runtime_id := str(params.get("runtime_id", "")).strip_edges()
	if not explicit_runtime_id.is_empty():
		return explicit_runtime_id
	if bool(params.get("allow_duplicate", false)):
		return "quest_%d_%d" % [Time.get_ticks_usec(), randi()]
	var repeatable := bool(template.get("repeatable", false))
	if repeatable and is_quest_complete(quest_id) and GameState.active_quests.has(quest_id):
		return "quest_%d_%d" % [Time.get_ticks_usec(), randi()]
	return quest_id


func _resolve_active_runtime_id(quest_id_or_runtime_id: String) -> String:
	if GameState.active_quests.has(quest_id_or_runtime_id):
		return quest_id_or_runtime_id
	for runtime_id_value in GameState.active_quests.keys():
		var runtime_id := str(runtime_id_value)
		var quest_instance_data: Variant = GameState.active_quests.get(runtime_id_value, {})
		if not quest_instance_data is Dictionary:
			continue
		var quest_instance: Dictionary = quest_instance_data
		if str(quest_instance.get("quest_id", "")) == quest_id_or_runtime_id:
			return runtime_id
	return ""


func _has_active_quest_template(quest_id: String) -> bool:
	return not _resolve_active_runtime_id(quest_id).is_empty()


func _resolve_entity_id(entity_lookup: String, fallback_entity_id: String) -> String:
	var normalized_lookup := entity_lookup.strip_edges()
	if normalized_lookup.is_empty():
		normalized_lookup = fallback_entity_id
	if normalized_lookup == "player":
		return "player"
	var entity := GameState.get_entity_instance(normalized_lookup)
	if entity != null:
		return entity.entity_id
	return fallback_entity_id


func _build_quest_context(quest_instance: Dictionary) -> Dictionary:
	return {
		"quest": quest_instance.duplicate(true),
		"quest_entities": {
			"assignee": _resolve_quest_entity(quest_instance, "assignee"),
			"owner": _resolve_quest_entity(quest_instance, "owner"),
			"reward_recipient": _resolve_quest_entity(quest_instance, "reward_recipient"),
		},
	}


func _resolve_quest_entity(quest_instance: Dictionary, role: String) -> EntityInstance:
	var field_name := "%s_entity_id" % role
	var entity_id := str(quest_instance.get(field_name, "player"))
	if entity_id.is_empty() or entity_id == "player":
		return GameState.player as EntityInstance
	return GameState.get_entity_instance(entity_id)


func _entity_display_name(entity: EntityInstance) -> String:
	if entity == null:
		return ""
	var template := DataManager.get_entity(entity.template_id)
	return str(template.get("display_name", entity.entity_id))
