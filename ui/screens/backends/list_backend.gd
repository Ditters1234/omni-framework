extends "res://ui/screens/backends/backend_base.gd"

class_name OmniListBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}
var _selected_row_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ListBackend", {
		"required": [],
		"optional": [
			"data_source",
			"row_template",
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"cancel_label",
			"action_payload",
			"empty_label",
		],
		"field_types": {
			"data_source": TYPE_STRING,
			"row_template": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"action_payload": TYPE_DICTIONARY,
			"empty_label": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_row_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var title := str(_params.get("screen_title", "List View"))
	var description := str(_params.get("screen_description", "Browse a runtime-backed list and optionally dispatch an action for the selected row."))
	var summary := str(_params.get("screen_summary", "Pick a row from the left to inspect it on the right."))
	var empty_label := str(_params.get("empty_label", "Nothing is available in this list."))
	var rows := _build_rows()
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": rows,
		"detail_kind": str(selected_row.get("detail_kind", "")),
		"selected_detail": _read_dictionary(selected_row.get("detail_view_model", {})),
		"status_text": _build_status_text(rows, selected_row, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Use Selected")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty() and _has_action_payload(),
	}


func select_row(row_id: String) -> void:
	_selected_row_id = row_id
	_status_text = ""


func confirm() -> Dictionary:
	if not _has_action_payload():
		_status_text = "This list does not define an action for selected rows."
		return {}
	var rows := _build_rows()
	var selected_row := _get_selected_row(rows)
	if selected_row.is_empty():
		_status_text = "Select a row before trying to use it."
		return {}
	var action_payload := _read_dictionary(_params.get("action_payload", {}))
	if action_payload.is_empty():
		_status_text = "This list does not define an action for selected rows."
		return {}
	if not action_payload.has("selected_id"):
		action_payload["selected_id"] = str(selected_row.get("row_id", ""))
	if not action_payload.has("template_id"):
		action_payload["template_id"] = str(selected_row.get("template_id", ""))
	if not action_payload.has("part_id"):
		action_payload["part_id"] = str(selected_row.get("template_id", ""))
	if not action_payload.has("quest_id"):
		action_payload["quest_id"] = str(selected_row.get("quest_id", ""))
	if not action_payload.has("runtime_id"):
		action_payload["runtime_id"] = str(selected_row.get("runtime_id", ""))
	ActionDispatcher.dispatch(action_payload)
	_status_text = "Triggered the configured action for %s." % str(selected_row.get("display_name", "the selected row"))
	return {}


func _build_rows() -> Array[Dictionary]:
	var data_source := str(_params.get("data_source", "player:inventory"))
	if data_source == "game_state.active_quests":
		return _build_active_quest_rows()
	return _build_inventory_rows(data_source)


func _build_inventory_rows(data_source: String) -> Array[Dictionary]:
	var owner := _resolve_owner_from_source(data_source)
	var source_suffix := _resolve_source_suffix(data_source)
	var rows: Array[Dictionary] = []
	if owner == null:
		return rows
	if source_suffix == "equipped":
		var equipped_slots: Array = owner.equipped.keys()
		equipped_slots.sort()
		for slot_value in equipped_slots:
			var slot_id := str(slot_value)
			var part := owner.get_equipped(slot_id)
			if part == null:
				continue
			var template := part.get_template()
			if template.is_empty():
				continue
			rows.append({
				"row_id": slot_id,
				"template_id": part.template_id,
				"display_name": str(template.get("display_name", part.template_id)),
				"detail_text": BACKEND_HELPERS.humanize_id(slot_id),
				"selected": slot_id == _selected_row_id,
				"detail_kind": "part_card",
				"detail_view_model": BACKEND_HELPERS.build_part_card_view_model(
					template,
					"",
					1.0,
					[
						{"label": BACKEND_HELPERS.humanize_id(slot_id), "color_token": "primary"},
						{"label": "Equipped", "color_token": "positive"},
					],
					true
				),
			})
		return rows

	for part_data in owner.inventory:
		var part := part_data as PartInstance
		if part == null or part.is_equipped:
			continue
		var template := part.get_template()
		if template.is_empty():
			continue
		rows.append({
			"row_id": part.instance_id,
			"template_id": part.template_id,
			"display_name": str(template.get("display_name", part.template_id)),
			"detail_text": str(template.get("description", "")),
			"selected": part.instance_id == _selected_row_id,
			"detail_kind": "part_card",
			"detail_view_model": BACKEND_HELPERS.build_part_card_view_model(
				template,
				"",
				1.0,
				[
					{"label": "Inventory", "color_token": "primary"},
				],
				true
			),
		})
	return rows


func _build_active_quest_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for quest_id_value in GameState.active_quests.keys():
		var quest_id := str(quest_id_value)
		var quest_template := DataManager.get_quest(quest_id)
		if quest_template.is_empty():
			continue
		var stage_index := 0
		var quest_instance_value: Variant = GameState.active_quests.get(quest_id_value, {})
		if quest_instance_value is Dictionary:
			var quest_instance: Dictionary = quest_instance_value
			stage_index = int(quest_instance.get("stage_index", 0))
		var stage_view_model := BACKEND_HELPERS.build_quest_card_view_model(quest_template, stage_index, false)
		rows.append({
			"row_id": quest_id,
			"quest_id": quest_id,
			"display_name": str(quest_template.get("display_name", quest_id)),
			"detail_text": str(stage_view_model.get("current_stage", "")),
			"selected": quest_id == _selected_row_id,
			"detail_kind": "quest_card",
			"detail_view_model": stage_view_model,
		})
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _resolve_owner_from_source(data_source: String) -> EntityInstance:
	var normalized_source := data_source.strip_edges()
	if normalized_source == "player:inventory" or normalized_source == "player:equipped":
		return GameState.player as EntityInstance
	if normalized_source.begins_with("entity:"):
		var segments := normalized_source.split(":", false)
		if segments.size() < 3:
			return null
		var suffix := str(segments[segments.size() - 1])
		if suffix != "inventory" and suffix != "equipped":
			return null
		var entity_id := ":".join(segments.slice(1, segments.size() - 1))
		return GameState.get_entity_instance(entity_id)
	return null


func _resolve_source_suffix(data_source: String) -> String:
	var segments := data_source.split(":", false)
	if segments.is_empty():
		return "inventory"
	return str(segments[segments.size() - 1])


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_row_id = ""
		return
	for row in rows:
		if str(row.get("row_id", "")) == _selected_row_id:
			return
	_selected_row_id = str(rows[0].get("row_id", ""))


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("row_id", "")) == _selected_row_id:
			return row
	return {}


func _build_status_text(rows: Array[Dictionary], selected_row: Dictionary, empty_label: String) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select a row to inspect it."
	return "Selected %s." % str(selected_row.get("display_name", "item"))


func _has_action_payload() -> bool:
	var action_payload_value: Variant = _params.get("action_payload", {})
	return action_payload_value is Dictionary and not (action_payload_value as Dictionary).is_empty()


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
