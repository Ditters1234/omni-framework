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
	var summary := str(_params.get("screen_summary", "Faction contracts come directly from the configured faction quest_pool."))
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
	var quest_id := _selected_template_id
	if quest_id.is_empty():
		_status_text = "Select a contract before accepting it."
		return {}
	var assignee_lookup := str(_params.get("assignee_entity_id", "player"))
	if not GameState.start_quest(quest_id, {
		"assignee_entity_id": assignee_lookup,
		"owner_entity_id": "player",
		"reward_recipient_entity_id": "player",
	}):
		_status_text = "That contract could not be accepted right now."
		return {}
	var accept_sound := str(_params.get("accept_sound", ""))
	if not accept_sound.is_empty():
		AudioManager.play_sfx(accept_sound)
	var quest_template := DataManager.get_quest(quest_id)
	_status_text = "Accepted %s." % str(quest_template.get("display_name", quest_id))
	_selected_template_id = ""
	return {}


func _build_task_rows(faction_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if faction_id.is_empty():
		return rows
	var faction := DataManager.get_faction(faction_id)
	var provider_entity_id := str(_params.get("provider_entity_id", ""))
	var quest_pool_value: Variant = faction.get("quest_pool", [])
	if not quest_pool_value is Array:
		return rows
	var quest_pool: Array = quest_pool_value
	for quest_id_value in quest_pool:
		var quest_id := str(quest_id_value)
		var quest_template := DataManager.get_quest(quest_id)
		if quest_id.is_empty() or quest_template.is_empty() or not _can_offer_quest(quest_template):
			continue
		var quest_card_view_model := BACKEND_HELPERS.build_quest_card_view_model(quest_template, 0, false)
		var ai_flavor_text := ScriptHookService.request_task_flavor(_build_flavor_template(quest_template), {
			"faction_id": faction_id,
			"provider_entity_id": provider_entity_id,
		})
		if not ai_flavor_text.is_empty():
			quest_card_view_model["flavor_text"] = ai_flavor_text
		rows.append({
			"template_id": quest_id,
			"display_name": str(quest_template.get("display_name", quest_template.get("title", quest_id))),
			"detail_text": str(quest_template.get("description", "")),
			"ai_flavor_text": ai_flavor_text,
			"selected": quest_id == _selected_template_id,
			"quest_card_view_model": quest_card_view_model,
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _can_offer_quest(quest_template: Dictionary) -> bool:
	var quest_id := str(quest_template.get("quest_id", ""))
	if quest_id.is_empty() or _has_active_quest_template(quest_id):
		return false
	if quest_id in GameState.completed_quests and not bool(quest_template.get("repeatable", false)):
		return false
	return true


func _has_active_quest_template(quest_id: String) -> bool:
	for runtime_id_value in GameState.active_quests.keys():
		var runtime_id := str(runtime_id_value)
		if runtime_id == quest_id:
			return true
		var quest_instance_value: Variant = GameState.active_quests.get(runtime_id_value, {})
		if not quest_instance_value is Dictionary:
			continue
		var quest_instance: Dictionary = quest_instance_value
		if str(quest_instance.get("quest_id", runtime_id)) == quest_id:
			return true
	return false


func _build_flavor_template(quest_template: Dictionary) -> Dictionary:
	var quest_id := str(quest_template.get("quest_id", ""))
	return {
		"template_id": quest_id,
		"display_name": str(quest_template.get("display_name", quest_template.get("title", quest_id))),
		"description": str(quest_template.get("description", "")),
		"type": "CONTRACT",
		"target": _resolve_first_reach_location(quest_template),
		"reward": _read_dictionary(quest_template.get("reward", {})),
	}


func _resolve_first_reach_location(quest_template: Dictionary) -> String:
	var stages_value: Variant = quest_template.get("stages", [])
	if not stages_value is Array:
		return ""
	var stages: Array = stages_value
	for stage_value in stages:
		if not stage_value is Dictionary:
			continue
		var stage: Dictionary = stage_value
		var objectives_value: Variant = stage.get("objectives", [])
		if not objectives_value is Array:
			continue
		var objectives: Array = objectives_value
		for objective_value in objectives:
			if not objective_value is Dictionary:
				continue
			var objective: Dictionary = objective_value
			if str(objective.get("type", "")) == "reach_location":
				return str(objective.get("location_id", objective.get("location", "")))
	return ""


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
