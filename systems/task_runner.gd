## TaskRunner — Manages active task instances for the player.
## Tasks are repeatable, time-limited jobs from faction job boards.
## Unlike quests, tasks do not use a full HSM — they are simpler pass/fail.
extends Node

class_name TaskRunner

## Active task instances: { runtime_id → task_instance_dict }
var _active_tasks: Dictionary = {}

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Accepts a task from a template and starts tracking it.
## Returns the runtime_id string for this instance, or "" on failure.
func accept_task(template_id: String) -> String:
	return ""


## Marks a task instance as completed and runs its reward actions.
## Returns true on success.
func complete_task(runtime_id: String) -> bool:
	return false


## Abandons an active task instance.
func abandon_task(runtime_id: String) -> void:
	pass


## Returns the active task instance dict for a runtime_id, or empty dict.
func get_task_instance(runtime_id: String) -> Dictionary:
	return _active_tasks.get(runtime_id, {})


## Returns all active task instance dicts.
func get_all_active() -> Array:
	return _active_tasks.values()


## Returns true if the player currently has the task accepted.
func is_task_active(runtime_id: String) -> bool:
	return _active_tasks.has(runtime_id)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_tick(tick: int) -> void:
	pass


func _generate_runtime_id() -> String:
	return str(randi())
