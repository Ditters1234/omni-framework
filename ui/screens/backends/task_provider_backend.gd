extends "res://ui/screens/backends/backend_base.gd"

class_name OmniTaskProviderBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}
var _selected_template_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("TaskProviderBackend", {
		"required": ["faction_id"],
		"optional": [
			"provider_entity_id",
			"assignee_entity_id",
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"cancel_label",
			"empty_label",
			"accept_sound",
		],
		"field_types": {
			"faction_id": TYPE_STRING,
			"provider_entity_id": TYPE_STRING,
			"assignee_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"accept_sound": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_template_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var faction_id := str(_params.get("faction_id", ""))
	var tasks := _build_task_rows(faction_id)
	_select_first_row_if_needed(tasks)
	var selected_row := _get_selected_row(tasks)
	var title := str(_params.get("screen_title", "Task Provider"))
	var description := str(_params.get("screen_description", "Browse faction jobs and accept one into the active task queue."))
	var summary := str(_params.get("screen_summary", "Task templates come directly from the configured faction quest_pool."))
	var empty_label := str(_params.get("empty_label", "This faction does not currently offer any tasks."))
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"portrait": _build_provider_portrait(faction_id),
		"rows": tasks,
		"selected_task": _read_dictionary(selected_row.get("quest_card_view_model", {})),
		"status_text": _build_status_text(tasks, selected_row, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Accept Selected")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty(),
	}


func select_row(template_id: String) -> void:
	_selected_template_id = template_id
	_status_text = ""


func confirm() -> Dictionary:
	var template_id := _selected_template_id
	if template_id.is_empty():
		_status_text = "Select a task before accepting it."
		return {}
	var assignee_lookup := str(_params.get("assignee_entity_id", "player"))
	var runtime_id := TimeKeeper.accept_task(template_id, {
		"entity_id": assignee_lookup,
	})
	if runtime_id.is_empty():
		_status_text = "That task could not be accepted right now."
		return {}
	var accept_sound := str(_params.get("accept_sound", ""))
	if not accept_sound.is_empty():
		AudioManager.play_sfx(accept_sound)
	var task_template := TaskRegistry.get_task(template_id)
	_status_text = "Accepted %s." % str(task_template.get("display_name", template_id))
	_selected_template_id = ""
	return {}


func _build_task_rows(faction_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if faction_id.is_empty():
		return rows
	var task_templates_value: Variant = TaskRegistry.get_for_faction(faction_id)
	if task_templates_value is Array:
		var task_templates: Array = task_templates_value
		for task_template_value in task_templates:
			if not task_template_value is Dictionary:
				continue
			var task_template: Dictionary = task_template_value
			var template_id := str(task_template.get("template_id", ""))
			if template_id.is_empty() or not TimeKeeper.can_accept_task(template_id):
				continue
			rows.append({
				"template_id": template_id,
				"display_name": str(task_template.get("display_name", task_template.get("title", template_id))),
				"detail_text": str(task_template.get("description", "")),
				"selected": template_id == _selected_template_id,
				"quest_card_view_model": BACKEND_HELPERS.build_task_card_view_model(task_template),
			})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _build_provider_portrait(faction_id: String) -> Dictionary:
	var provider_entity := BACKEND_HELPERS.resolve_entity_lookup(str(_params.get("provider_entity_id", "")))
	if provider_entity != null:
		return BACKEND_HELPERS.build_entity_portrait_view_model(provider_entity, "", "", faction_id)
	var faction := DataManager.get_faction(faction_id)
	if faction.is_empty():
		return {
			"display_name": "Task Provider",
			"description": "Accept work from the configured faction task pool.",
			"stat_preview": [],
		}
	var player := GameState.player as EntityInstance
	return {
		"display_name": str(faction.get("display_name", BACKEND_HELPERS.humanize_id(faction_id))),
		"description": str(faction.get("description", "Accept work from the configured faction task pool.")),
		"emblem_path": str(faction.get("emblem_path", "")),
		"faction_badge": BACKEND_HELPERS.build_faction_badge_view_model(player, faction_id),
		"stat_preview": [],
	}


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_template_id = ""
		return
	for row in rows:
		if str(row.get("template_id", "")) == _selected_template_id:
			return
	_selected_template_id = str(rows[0].get("template_id", ""))


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("template_id", "")) == _selected_template_id:
			return row
	return {}


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, empty_label: String) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select a task to inspect its details."
	return "Ready to accept %s." % str(selected_row.get("display_name", "the selected task"))


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
