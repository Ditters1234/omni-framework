## QuestCard view model contract:
## {
##   "quest_id": String,
##   "display_name": String,
##   "current_stage": Variant,
##   "objectives": Array[Dictionary],
##   "rewards": Variant
## }
extends PanelContainer

class_name QuestCard

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_MUTED_TEXT_COLOR := Color("#9aa8bf")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _quest_id_label: Label = $MarginContainer/VBoxContainer/QuestIdLabel
@onready var _stage_label: Label = $MarginContainer/VBoxContainer/StageLabel
@onready var _objectives_container: VBoxContainer = $MarginContainer/VBoxContainer/ObjectivesContainer
@onready var _rewards_label: Label = $MarginContainer/VBoxContainer/RewardsLabel

var _pending_view_model: Dictionary = {}


func _ready() -> void:
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model.duplicate(true)
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	_title_label.text = str(view_model.get("display_name", "Unnamed Quest"))
	_quest_id_label.text = str(view_model.get("quest_id", ""))
	_quest_id_label.visible = not _quest_id_label.text.is_empty()
	_stage_label.text = _format_stage_label(view_model.get("current_stage", null))
	_render_objectives(view_model.get("objectives", []))
	_rewards_label.text = _format_rewards(view_model.get("rewards", null))
	_rewards_label.visible = not _rewards_label.text.is_empty()


func _render_objectives(objectives_value: Variant) -> void:
	for child in _objectives_container.get_children():
		_objectives_container.remove_child(child)
		child.queue_free()
	if not objectives_value is Array:
		_add_objective_label("No objectives listed.", false, true)
		return
	var objectives: Array = objectives_value
	if objectives.is_empty():
		_add_objective_label("No objectives listed.", false, true)
		return
	for objective_value in objectives:
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		var label := str(objective.get("label", objective.get("description", "Objective")))
		var satisfied := bool(objective.get("satisfied", false))
		_add_objective_label(label, satisfied, false)


func _add_objective_label(text: String, satisfied: bool, muted: bool) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s %s" % ["[x]" if satisfied else "[ ]", text]
	if muted:
		label.modulate = _get_semantic_color("muted_text", FALLBACK_MUTED_TEXT_COLOR)
	elif satisfied:
		label.modulate = _get_semantic_color("positive", FALLBACK_POSITIVE_COLOR)
	_objectives_container.add_child(label)


func _format_stage_label(current_stage_value: Variant) -> String:
	if current_stage_value is Dictionary:
		var current_stage: Dictionary = current_stage_value
		var title := str(current_stage.get("title", current_stage.get("description", "")))
		if not title.is_empty():
			return "Current Stage: %s" % title
	if current_stage_value == null:
		return ""
	var current_stage_text := str(current_stage_value)
	if current_stage_text.is_empty():
		return ""
	return "Current Stage: %s" % current_stage_text


func _format_rewards(rewards_value: Variant) -> String:
	if rewards_value is Dictionary:
		var rewards: Dictionary = rewards_value
		if rewards.is_empty():
			return ""
		var parts: Array[String] = []
		var keys: Array = rewards.keys()
		keys.sort()
		for key_value in keys:
			parts.append("%s: %s" % [BACKEND_HELPERS.humanize_id(str(key_value)), str(rewards.get(key_value, ""))])
		return "Rewards: %s" % ", ".join(parts)
	if rewards_value == null:
		return ""
	var rewards_text := str(rewards_value)
	return "" if rewards_text.is_empty() else "Rewards: %s" % rewards_text


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
