## QuestTracker — Manages active quest state machines.
## Uses LimboAI HSMs built dynamically from quest JSON templates.
## Quest JSON defines states and transitions; QuestTracker drives them.
## State is persisted in GameState.active_quests.
##
## NOTE: LimboAI HSM integration requires a spike during early development.
## The public API below is stable; the HSM internals are TBD.
extends Node

class_name QuestTracker


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Starts a quest by id. No-op if already active or completed.
## Returns true on success.
func start_quest(quest_id: String) -> bool:
	if is_quest_active(quest_id) or is_quest_complete(quest_id):
		return false
	var template := DataManager.get_quest(quest_id)
	if template.is_empty():
		push_warning("QuestTracker: unknown quest '%s'" % quest_id)
		return false
	_create_quest_instance(template)
	GameEvents.quest_started.emit(quest_id)
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
	var next_stage_index := current_stage_index + 1
	if next_stage_index >= stages.size():
		complete_quest(quest_id)
		return
	quest_instance["stage_index"] = next_stage_index
	if transition != "":
		quest_instance["last_transition"] = transition
	GameState.active_quests[quest_id] = quest_instance
	GameEvents.quest_stage_advanced.emit(quest_id, next_stage_index)


## Completes a quest manually (e.g. from a script hook).
func complete_quest(quest_id: String) -> void:
	if not is_quest_active(quest_id):
		return
	GameState.active_quests.erase(quest_id)
	if not quest_id in GameState.completed_quests:
		GameState.completed_quests.append(quest_id)
	GameEvents.quest_completed.emit(quest_id)


## Fails a quest.
func fail_quest(quest_id: String) -> void:
	if not is_quest_active(quest_id):
		return
	GameState.active_quests.erase(quest_id)
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


func _on_tick(tick: int) -> void:
	pass
