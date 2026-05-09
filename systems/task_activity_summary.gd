extends RefCounted

class_name TaskActivitySummary

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const TASK_STATUS_ACTIVE := "active"
const TASK_STATUS_QUEUED := "queued"


static func build_for_entity(entity_id: String) -> Dictionary:
	var normalized_entity_id := entity_id.strip_edges()
	var active_tasks := _get_tasks_for_entity(normalized_entity_id, TASK_STATUS_ACTIVE)
	var queued_tasks := _get_tasks_for_entity(normalized_entity_id, TASK_STATUS_QUEUED)
	var primary_task := active_tasks[0] if not active_tasks.is_empty() else {}
	var active_text := _format_task_text(primary_task, false)
	if active_tasks.size() > 1:
		active_text = "%s + %d active" % [active_text, active_tasks.size() - 1]
	var queue_text := _format_queue_text(queued_tasks.size())
	var detail_lines: Array[String] = []
	if not primary_task.is_empty():
		detail_lines.append(active_text)
	for queued_task in queued_tasks:
		detail_lines.append(_format_task_text(queued_task, true))
	return {
		"entity_id": normalized_entity_id,
		"status": TASK_STATUS_ACTIVE if not active_tasks.is_empty() else "idle",
		"active_task": primary_task,
		"active_tasks": active_tasks,
		"queued_tasks": queued_tasks,
		"active_task_count": active_tasks.size(),
		"queued_task_count": queued_tasks.size(),
		"active_task_text": active_text if not active_tasks.is_empty() else "Idle",
		"queue_text": queue_text,
		"detail_text": "\n".join(detail_lines) if not detail_lines.is_empty() else "Idle",
		"remaining_ticks": int(primary_task.get("remaining_ticks", 0)) if not primary_task.is_empty() else 0,
	}


static func _get_tasks_for_entity(entity_id: String, status: String) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	for runtime_id_value in GameState.active_tasks.keys():
		var task_value: Variant = GameState.active_tasks.get(runtime_id_value, {})
		if not task_value is Dictionary:
			continue
		var task: Dictionary = (task_value as Dictionary).duplicate(true)
		if str(task.get("entity_id", "")) != entity_id:
			continue
		if str(task.get("status", TASK_STATUS_ACTIVE)) != status:
			continue
		task["runtime_id"] = str(task.get("runtime_id", runtime_id_value))
		tasks.append(task)
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		if status == TASK_STATUS_QUEUED:
			var queue_compare := int(a.get("queued_at_tick", 0)) - int(b.get("queued_at_tick", 0))
			if queue_compare != 0:
				return queue_compare < 0
			return int(a.get("queued_order", 0)) < int(b.get("queued_order", 0))
		return int(a.get("remaining_ticks", 0)) < int(b.get("remaining_ticks", 0))
	tasks.sort_custom(sort_callable)
	return tasks


static func _format_task_text(task: Dictionary, queued: bool) -> String:
	if task.is_empty():
		return "Idle"
	var label := _get_task_label(task)
	var remaining := int(task.get("remaining_ticks", 0))
	var timing := "queued" if queued else _format_remaining_ticks(remaining)
	return "%s, %s" % [label, timing]


static func _get_task_label(task: Dictionary) -> String:
	var template_id := str(task.get("template_id", ""))
	var template := DataManager.get_task(template_id)
	var label := str(template.get("display_name", BACKEND_HELPERS.humanize_id(template_id)))
	var target := str(task.get("target", "")).strip_edges()
	if target.is_empty():
		return label
	var target_label := _get_target_label(target)
	if target_label.is_empty():
		return label
	return "%s to %s" % [label, target_label]


static func _get_target_label(target: String) -> String:
	if DataManager.has_location(target):
		var location := DataManager.get_location(target)
		return str(location.get("display_name", BACKEND_HELPERS.humanize_id(target)))
	return BACKEND_HELPERS.humanize_id(target)


static func _format_remaining_ticks(remaining_ticks: int) -> String:
	if remaining_ticks <= 0:
		return "finishing now"
	if remaining_ticks == 1:
		return "1 tick remaining"
	return "%d ticks remaining" % remaining_ticks


static func _format_queue_text(count: int) -> String:
	if count <= 0:
		return ""
	if count == 1:
		return "1 queued"
	return "%d queued" % count
