extends RefCounted

class_name OmniAssemblyEditorConfig

const SCREEN_MAIN_MENU := "main_menu"
const DEFAULT_OPTION_TAG := "character_creator_option"

var target_entity_lookup_id: String = "player"
var budget_entity_lookup_id: String = ""
var budget_currency_id: String = "credits"
var payment_recipient_lookup_id: String = ""
var option_source_entity_lookup_id: String = ""
var option_tags: Array[String] = []
var option_template_ids: Array[String] = []
var next_screen_id: String = ""
var cancel_screen_id: String = SCREEN_MAIN_MENU
var reset_game_state_on_cancel: bool = false
var pop_on_confirm: bool = false
var confirm_screen_params: Dictionary = {}
var cancel_screen_params: Dictionary = {}
var screen_title: String = "Assembly Editor"
var screen_description: String = "Choose parts for the selected entity from a configured catalog."
var screen_summary: String = "Preview parts on the left, inspect the current selection on the right, and confirm when the build looks right."
var cancel_label: String = "Cancel"
var confirm_label: String = "Confirm"


func apply_params(params: Dictionary) -> void:
	target_entity_lookup_id = str(params.get("target_entity_id", "player"))
	budget_entity_lookup_id = str(params.get("budget_entity_id", ""))
	budget_currency_id = str(params.get("budget_currency_id", "credits"))
	payment_recipient_lookup_id = str(params.get("payment_recipient_id", ""))
	option_source_entity_lookup_id = str(params.get("option_source_entity_id", ""))
	next_screen_id = str(params.get("next_screen_id", ""))
	cancel_screen_id = str(params.get("cancel_screen_id", SCREEN_MAIN_MENU))
	reset_game_state_on_cancel = bool(params.get("reset_game_state_on_cancel", false))
	pop_on_confirm = bool(params.get("pop_on_confirm", false))
	screen_title = str(params.get("screen_title", screen_title))
	screen_description = str(params.get("screen_description", screen_description))
	screen_summary = str(params.get("screen_summary", screen_summary))
	cancel_label = str(params.get("cancel_label", cancel_label))
	confirm_label = str(params.get("confirm_label", confirm_label))

	var confirm_params_data: Variant = params.get("next_screen_params", {})
	if confirm_params_data is Dictionary:
		var confirm_params: Dictionary = confirm_params_data
		confirm_screen_params = confirm_params.duplicate(true)
	else:
		confirm_screen_params = {}

	var cancel_params_data: Variant = params.get("cancel_screen_params", {})
	if cancel_params_data is Dictionary:
		var cancel_params: Dictionary = cancel_params_data
		cancel_screen_params = cancel_params.duplicate(true)
	else:
		cancel_screen_params = {}

	option_tags = _to_string_array(params.get("option_tags", []))
	if option_tags.is_empty():
		var option_tag := str(params.get("option_tag", DEFAULT_OPTION_TAG))
		if not option_tag.is_empty():
			option_tags.append(option_tag)
	option_template_ids = _to_string_array(params.get("option_template_ids", []))


func build_header_view_model() -> Dictionary:
	return {
		"title": screen_title,
		"description": screen_description,
		"summary": screen_summary,
		"cancel_label": cancel_label,
		"confirm_label": confirm_label,
	}


func build_cancel_action() -> Dictionary:
	if cancel_screen_id.is_empty():
		return {"type": "pop"}
	return {
		"type": "replace_all",
		"screen_id": cancel_screen_id,
		"params": cancel_screen_params.duplicate(true),
	}


func build_confirm_navigation_action() -> Dictionary:
	if pop_on_confirm:
		return {"type": "pop"}
	if next_screen_id.is_empty():
		return {}
	return {
		"type": "replace_all",
		"screen_id": next_screen_id,
		"params": confirm_screen_params.duplicate(true),
	}


static func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	var entries: Array = values
	for entry in entries:
		result.append(str(entry))
	return result
