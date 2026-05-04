extends "res://ui/screens/backends/backend_base.gd"

class_name OmniActiveQuestLogBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("ActiveQuestLogBackend", {
		"required": [],
		"optional": [
			"screen_title",
			"screen_description",
			"cancel_label",
			"empty_label",
			"include_completed",
		],
		"field_types": {
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"include_completed": TYPE_BOOL,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var cards := _build_active_cards()
	if _get_bool_param(_params, "include_completed", false):
		cards.append_array(_build_completed_cards())
	var empty_label := _get_string_param(_params, "empty_label", "No active quests.")
	return {
		"title": _get_string_param(_params, "screen_title", "Quest Log"),
		"description": _get_string_param(_params, "screen_description", "Review active quest stages and objectives."),
		"cards": cards,
		"status_text": empty_label if cards.is_empty() else "%s quest entries." % str(cards.size()),
		"cancel_label": _get_string_param(_params, "cancel_label", "Back"),
		"empty_label": empty_label,
	}


func _build_active_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var runtime_ids: Array = GameState.active_quests.keys()
	runtime_ids.sort()
	for runtime_id_value in runtime_ids:
		var runtime_id := str(runtime_id_value)
		var quest_instance_value: Variant = GameState.active_quests.get(runtime_id_value, {})
		var quest_id := runtime_id
		var stage_index := 0
		if quest_instance_value is Dictionary:
			var quest_instance: Dictionary = quest_instance_value
			quest_id = str(quest_instance.get("quest_id", runtime_id))
			stage_index = int(quest_instance.get("stage_index", 0))
		var quest_template := DataManager.get_quest(quest_id)
		if quest_template.is_empty():
			continue
		var card := BACKEND_HELPERS.build_quest_card_view_model(quest_template, stage_index, false)
		card["runtime_id"] = runtime_id
		cards.append(card)
	return cards


func _build_completed_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var quest_ids := GameState.completed_quests.duplicate()
	quest_ids.sort()
	for quest_id in quest_ids:
		if _has_active_quest_template(str(quest_id)):
			continue
		var quest_template := DataManager.get_quest(str(quest_id))
		if quest_template.is_empty():
			continue
		var final_stage_index := _resolve_final_stage_index(quest_template)
		cards.append(BACKEND_HELPERS.build_quest_card_view_model(quest_template, final_stage_index, true))
	return cards


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


func _resolve_final_stage_index(quest_template: Dictionary) -> int:
	var stages_value: Variant = quest_template.get("stages", [])
	if stages_value is Array:
		var stages: Array = stages_value
		if not stages.is_empty():
			return stages.size() - 1
	return 0
