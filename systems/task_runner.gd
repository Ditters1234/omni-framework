## TaskRunner — Manages active task instances for runtime entities.
## Tasks are repeatable, time-limited jobs that advance with ticks.
## Unlike quests, tasks do not use a full HSM — they are simpler pass/fail.
extends Node

class_name TaskRunner

const TASK_TYPE_WAIT := "WAIT"
const TASK_TYPE_CRAFT := "CRAFT"
const TASK_TYPE_DELIVER := "DELIVER"
const TASK_TYPE_TRAVEL := "TRAVEL"
const DEFAULT_TASK_DURATION := 1

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Accepts a task from a template and starts tracking it.
## Optional params may override the runtime entity owner via `entity_id`.
## Returns the runtime_id string for this instance, or "" on failure.
func accept_task(template_id: String, params: Dictionary = {}) -> String:
	var template := TaskRegistry.get_task(template_id)
	if template.is_empty():
		push_warning("TaskRunner: unknown task template '%s'" % template_id)
		return ""
	var entity := _resolve_entity(str(params.get("entity_id", "player")))
	if entity == null:
		return ""
	if not _can_accept_template(template):
		return ""
	var runtime_id := _generate_runtime_id()
	var task_type := str(template.get("type", TASK_TYPE_WAIT))
	var task_instance := {
		"runtime_id": runtime_id,
		"template_id": template_id,
		"entity_id": entity.entity_id,
		"type": task_type,
		"target": str(template.get("target", "")),
		"remaining_ticks": _resolve_remaining_ticks(template),
		"started_day": GameState.current_day,
		"started_tick": GameState.current_tick,
		"reward": _duplicate_dict(template.get("reward", {})),
		"complete_sound": str(template.get("complete_sound", "")),
	}
	GameState.active_tasks[runtime_id] = task_instance
	ScriptHookService.invoke_template_hook(template, "on_task_start", [task_instance.duplicate(true)])
	GameEvents.task_started.emit(runtime_id, entity.entity_id)
	return runtime_id


## Marks a task instance as completed and runs its reward actions.
## Returns true on success.
func complete_task(runtime_id: String) -> bool:
	if not is_task_active(runtime_id):
		return false
	var task_instance_data: Variant = GameState.active_tasks.get(runtime_id, {})
	if not task_instance_data is Dictionary:
		return false
	var task_instance: Dictionary = task_instance_data
	var entity := _resolve_entity(str(task_instance.get("entity_id", "player")))
	if entity == null:
		return false
	_apply_completion_state(task_instance, entity)
	_apply_reward(task_instance, entity)
	_apply_hook(task_instance, "on_task_complete")
	GameState.active_tasks.erase(runtime_id)
	_mark_completion(task_instance)
	_play_complete_sound(task_instance)
	GameEvents.task_completed.emit(runtime_id, entity.entity_id)
	return true


## Abandons an active task instance.
func abandon_task(runtime_id: String) -> void:
	GameState.active_tasks.erase(runtime_id)


## Returns the active task instance dict for a runtime_id, or empty dict.
func get_task_instance(runtime_id: String) -> Dictionary:
	var task_instance_data: Variant = GameState.active_tasks.get(runtime_id, {})
	if task_instance_data is Dictionary:
		var task_instance: Dictionary = task_instance_data
		return task_instance
	return {}


## Returns all active task instance dicts.
func get_all_active() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for task_instance_data in GameState.active_tasks.values():
		if task_instance_data is Dictionary:
			var task_instance: Dictionary = task_instance_data
			result.append(task_instance)
	return result


## Returns true if the player currently has the task accepted.
func is_task_active(runtime_id: String) -> bool:
	return GameState.active_tasks.has(runtime_id)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_tick(tick: int) -> void:
	var to_complete: Array[String] = []
	for runtime_id_value in GameState.active_tasks.keys():
		var runtime_id := str(runtime_id_value)
		var task_instance_data: Variant = GameState.active_tasks.get(runtime_id, {})
		if not task_instance_data is Dictionary:
			continue
		var task_instance: Dictionary = task_instance_data
		var remaining_ticks := int(task_instance.get("remaining_ticks", 0))
		if remaining_ticks <= 0:
			to_complete.append(runtime_id)
			continue
		task_instance["remaining_ticks"] = remaining_ticks - 1
		task_instance["last_tick"] = tick
		GameState.active_tasks[runtime_id] = task_instance
		if int(task_instance.get("remaining_ticks", 0)) <= 0:
			to_complete.append(runtime_id)
	for runtime_id in to_complete:
		complete_task(runtime_id)


func _generate_runtime_id() -> String:
	return str(randi())


func _resolve_remaining_ticks(template: Dictionary) -> int:
	var task_type := str(template.get("type", TASK_TYPE_WAIT))
	if task_type == TASK_TYPE_DELIVER or task_type == TASK_TYPE_TRAVEL:
		var travel_cost := int(template.get("travel_cost", DataManager.get_config_value("balance.default_travel_cost_ticks", DEFAULT_TASK_DURATION)))
		return maxi(travel_cost, DEFAULT_TASK_DURATION)
	var duration := int(template.get("duration", DEFAULT_TASK_DURATION))
	return maxi(duration, DEFAULT_TASK_DURATION)


func _can_accept_template(template: Dictionary) -> bool:
	var template_id := str(template.get("template_id", ""))
	var repeatable := bool(template.get("repeatable", true))
	if not repeatable and template_id in GameState.completed_task_templates:
		return false
	if repeatable:
		return true
	for task_instance in GameState.active_tasks.values():
		if not task_instance is Dictionary:
			continue
		if str(task_instance.get("template_id", "")) == template_id:
			return false
	return true


func _apply_reward(task_instance: Dictionary, entity: EntityInstance) -> void:
	var reward_data: Variant = task_instance.get("reward", {})
	RewardService.apply_reward(entity, reward_data)


func _apply_completion_state(task_instance: Dictionary, entity: EntityInstance) -> void:
	var task_type := str(task_instance.get("type", TASK_TYPE_WAIT))
	var target := str(task_instance.get("target", ""))
	if target.is_empty():
		return
	if task_type != TASK_TYPE_DELIVER and task_type != TASK_TYPE_TRAVEL:
		return
	var player_entity := GameState.player as EntityInstance
	if player_entity != null and player_entity.entity_id == entity.entity_id:
		GameState.travel_to(target)
		return
	entity.location_id = target


func _apply_hook(task_instance: Dictionary, method_name: String) -> void:
	var template_id := str(task_instance.get("template_id", ""))
	if template_id.is_empty():
		return
	var template := TaskRegistry.get_task(template_id)
	if template.is_empty():
		return
	ScriptHookService.invoke_template_hook(template, method_name, [task_instance.duplicate(true)])


func _mark_completion(task_instance: Dictionary) -> void:
	var template_id := str(task_instance.get("template_id", ""))
	if template_id.is_empty():
		return
	var template := TaskRegistry.get_task(template_id)
	if template.is_empty():
		return
	if bool(template.get("repeatable", true)):
		return
	if template_id in GameState.completed_task_templates:
		return
	GameState.completed_task_templates.append(template_id)


func _play_complete_sound(task_instance: Dictionary) -> void:
	var complete_sound := str(task_instance.get("complete_sound", ""))
	if complete_sound.is_empty():
		return
	AudioManager.play_sfx(complete_sound)


func _duplicate_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	return {}


func _resolve_entity(entity_id: String) -> EntityInstance:
	if entity_id.is_empty() or entity_id == "player":
		return GameState.player as EntityInstance
	return GameState.get_entity_instance(entity_id)
