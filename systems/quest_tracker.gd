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
func start_quest(quest_id: String) -> bool:
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		push_warning("QuestTracker: unknown quest '%s'" % quest_id)
		return false
	var repeatable := bool(template.get("repeatable", false))
	if is_quest_active(quest_id):
		return false
	if is_quest_complete(quest_id) and not repeatable:
		return false
	_create_quest_instance(template)
	var quest_instance_data: Variant = GameState.active_quests.get(quest_id, {})
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		ScriptHookService.invoke_template_hook(template, "on_quest_start", [quest_instance.duplicate(true)])
	GameEvents.quest_started.emit(quest_id)
	_refresh_quest(quest_id)
	return true


## Advances a quest's state machine by signaling a named transition.
func advance_quest(quest_id: String, transition: String) -> void:
	if not is_quest_active(quest_id):
		return
	var quest_instance_data: Variant = GameState.active_quests.get(quest_id, {})
	if not quest_instance_data is Dictionary:
		return
	var quest_instance: Dictionary = quest_instance_data
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		return
	var stages_data: Variant = template.get("stages", [])
	if not stages_data is Array:
		return
	var stages: Array = stages_data
	var current_stage_index := int(quest_instance.get("stage_index", 0))
	if current_stage_index < 0 or current_stage_index >= stages.size():
		complete_quest(quest_id)
		return
	# Advance the index first so that any hook fired by _apply_stage_completion
	# sees the updated stage number rather than the old one.
	var next_stage_index := current_stage_index + 1
	if transition != "":
		quest_instance["last_transition"] = transition
	quest_instance["stage_index"] = next_stage_index
	GameState.active_quests[quest_id] = quest_instance
	# Apply completion rewards for the stage we just finished.
	var current_stage_data: Variant = stages[current_stage_index]
	if current_stage_data is Dictionary:
		var current_stage: Dictionary = current_stage_data
		_apply_stage_completion(current_stage)
	if next_stage_index >= stages.size():
		_complete_active_quest(quest_id, template)
		return
	GameEvents.quest_stage_advanced.emit(quest_id, next_stage_index)
	# Do NOT call _refresh_quest here — _apply_stage_completion may have already
	# triggered an auto-advance via event listeners, and calling it again would
	# double-fire rewards for any stages whose objectives are already met.
	# The next tick / event will naturally trigger _refresh_active_quests.


## Completes a quest manually (e.g. from a script hook).
func complete_quest(quest_id: String) -> void:
	if not is_quest_active(quest_id):
		return
	var template := DataManager.get_quest(quest_id)
	_complete_active_quest(quest_id, template)


## Fails a quest.
func fail_quest(quest_id: String) -> void:
	if not is_quest_active(quest_id):
		return
	var template := DataManager.get_quest(quest_id)
	var quest_instance_data: Variant = GameState.active_quests.get(quest_id, {})
	GameState.active_quests.erase(quest_id)
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		ScriptHookService.invoke_template_hook(template, "on_quest_fail", [quest_instance.duplicate(true)])
	GameEvents.quest_failed.emit(quest_id)


## Returns true if the quest is currently active.
func is_quest_active(quest_id: String) -> bool:
	return quest_id in GameState.active_quests


## Returns true if the quest has been completed.
func is_quest_complete(quest_id: String) -> bool:
	return quest_id in GameState.completed_quests


## Returns the active quest instance dict, or empty dict.
func get_quest_instance(quest_id: String) -> Dictionary:
	return GameState.active_quests.get(quest_id, {})


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_quest_instance(template: Dictionary) -> void:
	var quest_id := str(template.get("quest_id", ""))
	if quest_id.is_empty():
		return
	GameState.active_quests[quest_id] = {
		"quest_id": quest_id,
		"stage_index": 0,
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


func _refresh_quest(quest_id: String) -> void:
	if _refreshing_quests.has(quest_id):
		return
	_refreshing_quests[quest_id] = true
	_refresh_quest_inner(quest_id)
	_refreshing_quests.erase(quest_id)


func _refresh_quest_inner(quest_id: String) -> void:
	if not is_quest_active(quest_id):
		return
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		return
	var stages_data: Variant = template.get("stages", [])
	if not stages_data is Array:
		return
	var stages: Array = stages_data
	var safety_limit := stages.size() + 1
	while safety_limit > 0 and is_quest_active(quest_id):
		safety_limit -= 1
		var quest_instance_data: Variant = GameState.active_quests.get(quest_id, {})
		if not quest_instance_data is Dictionary:
			return
		var quest_instance: Dictionary = quest_instance_data
		var stage_index := int(quest_instance.get("stage_index", 0))
		if stage_index < 0 or stage_index >= stages.size():
			_complete_active_quest(quest_id, template)
			return
		var stage_data: Variant = stages[stage_index]
		if not stage_data is Dictionary:
			return
		var stage: Dictionary = stage_data
		if not _is_stage_complete(stage):
			return
		_apply_stage_completion(stage)
		var next_stage_index := stage_index + 1
		quest_instance["last_transition"] = "objectives_met"
		if next_stage_index >= stages.size():
			_complete_active_quest(quest_id, template)
			return
		quest_instance["stage_index"] = next_stage_index
		GameState.active_quests[quest_id] = quest_instance
		GameEvents.quest_stage_advanced.emit(quest_id, next_stage_index)


func _is_stage_complete(stage: Dictionary) -> bool:
	var objectives_data: Variant = stage.get("objectives", [])
	if not objectives_data is Array:
		return false
	var objectives: Array = objectives_data
	if objectives.is_empty():
		return true
	for objective_data in objectives:
		if not objective_data is Dictionary:
			return false
		var objective: Dictionary = objective_data
		if not ConditionEvaluator.evaluate(objective):
			return false
	return true


func _apply_stage_completion(stage: Dictionary) -> void:
	var player := GameState.player as EntityInstance
	if player == null:
		return
	RewardService.apply_reward(player, stage.get("reward", {}))
	var action_payload_data: Variant = stage.get("action_payload", null)
	if action_payload_data is Dictionary:
		ActionDispatcher.dispatch(action_payload_data)
	var actions_data: Variant = stage.get("actions", null)
	if actions_data is Array:
		var actions: Array = actions_data
		ActionDispatcher.dispatch_all(actions)


func _complete_active_quest(quest_id: String, template: Dictionary) -> void:
	if not is_quest_active(quest_id):
		return
	var quest_instance_data: Variant = GameState.active_quests.get(quest_id, {})
	GameState.active_quests.erase(quest_id)
	if not quest_id in GameState.completed_quests:
		GameState.completed_quests.append(quest_id)
	var player := GameState.player as EntityInstance
	if player != null:
		RewardService.apply_reward(player, template.get("reward", {}))
	var action_payload_data: Variant = template.get("action_payload", null)
	if action_payload_data is Dictionary:
		ActionDispatcher.dispatch(action_payload_data)
	var actions_data: Variant = template.get("actions", null)
	if actions_data is Array:
		var actions: Array = actions_data
		ActionDispatcher.dispatch_all(actions)
	if quest_instance_data is Dictionary:
		var quest_instance: Dictionary = quest_instance_data
		ScriptHookService.invoke_template_hook(template, "on_quest_complete", [quest_instance.duplicate(true)])
	var complete_sound := str(template.get("complete_sound", ""))
	if not complete_sound.is_empty():
		AudioManager.play_sfx(complete_sound)
	GameEvents.quest_completed.emit(quest_id)
