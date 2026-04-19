extends "res://ui/screens/backends/backend_base.gd"

class_name OmniDialogueBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

var _params: Dictionary = {}


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("DialogueBackend", {
		"required": ["dialogue_resource"],
		"optional": [
			"dialogue_start",
			"speaker_entity_id",
			"screen_title",
			"screen_description",
			"cancel_label",
		],
		"field_types": {
			"dialogue_resource": TYPE_STRING,
			"dialogue_start": TYPE_STRING,
			"speaker_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)


func build_view_model() -> Dictionary:
	var speaker := _resolve_speaker_entity()
	var dialogue_resource := str(_params.get("dialogue_resource", ""))
	var status_text := ""
	if dialogue_resource.is_empty():
		status_text = "This dialogue entry is missing a dialogue_resource path."
	elif not ResourceLoader.exists(dialogue_resource):
		status_text = "The configured dialogue resource could not be loaded."
	return {
		"title": str(_params.get("screen_title", "Dialogue")),
		"description": str(_params.get("screen_description", "Play a branching dialogue file through the routed UI layer.")),
		"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(
			speaker,
			"Speaker",
			"Dialogue will use the configured resource and optional start title."
		),
		"dialogue_resource": dialogue_resource,
		"dialogue_start": str(_params.get("dialogue_start", "")),
		"speaker_entity_id": "" if speaker == null else speaker.entity_id,
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"status_text": status_text,
	}


func get_dialogue_resource_path() -> String:
	return str(_params.get("dialogue_resource", ""))


func get_dialogue_start() -> String:
	return str(_params.get("dialogue_start", ""))


func get_speaker_entity_id() -> String:
	var speaker := _resolve_speaker_entity()
	return "" if speaker == null else speaker.entity_id


func get_speaker_display_name() -> String:
	var speaker := _resolve_speaker_entity()
	if speaker == null:
		return "Speaker"
	return BACKEND_HELPERS.get_entity_display_name(speaker, speaker.entity_id)


func get_dialogue_blip_path() -> String:
	var speaker := _resolve_speaker_entity()
	if speaker == null:
		return ""
	var template := speaker.get_template()
	return str(template.get("dialogue_blip", ""))


func _resolve_speaker_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(str(_params.get("speaker_entity_id", "")))
