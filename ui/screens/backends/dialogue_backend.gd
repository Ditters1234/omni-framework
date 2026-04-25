extends "res://ui/screens/backends/backend_base.gd"

class_name OmniDialogueBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const AI_CHAT_SERVICE := preload("res://systems/ai/ai_chat_service.gd")
const APP_SETTINGS := preload("res://core/app_settings.gd")

const AI_MODE_DISABLED := "disabled"
const AI_MODE_HYBRID := "hybrid"
const AI_MODE_FREEFORM := "freeform"

var _params: Dictionary = {}
var _ai_chat_service: AIChatService = null


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("DialogueBackend", {
		"required": [],
		"optional": [
			"dialogue_id",
			"dialogue_resource",
			"dialogue_start",
			"ai_mode",
			"speaker_entity_id",
			"screen_title",
			"screen_description",
			"cancel_label",
		],
		"field_types": {
			"dialogue_id": TYPE_STRING,
			"dialogue_resource": TYPE_STRING,
			"dialogue_start": TYPE_STRING,
			"ai_mode": TYPE_STRING,
			"speaker_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"cancel_label": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_initialize_ai_chat_service()


func build_view_model() -> Dictionary:
	var speaker := _resolve_speaker_entity()
	var dialogue_ref := _get_dialogue_reference()
	var dialogue_resource := get_dialogue_resource_path()
	var ai_mode := get_ai_mode()
	var ai_chat_available := can_use_ai_chat()
	var status_text := ""
	if dialogue_ref.is_empty() and ai_mode == AI_MODE_DISABLED:
		status_text = "This dialogue entry is missing a dialogue_id or dialogue_resource reference."
	elif dialogue_ref.is_empty() and ai_mode != AI_MODE_DISABLED and not ai_chat_available:
		status_text = "This dialogue entry needs a valid dialogue resource or an available AI persona."
	elif not dialogue_ref.is_empty() and dialogue_resource.is_empty():
		status_text = "The configured dialogue reference could not be resolved."
	return {
		"title": str(_params.get("screen_title", "Dialogue")),
		"description": str(_params.get("screen_description", "Play a branching dialogue file through the routed UI layer.")),
		"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(
			speaker,
			"Speaker",
			"Dialogue will use the configured dialogue id or resource reference."
		),
		"dialogue_id": str(_params.get("dialogue_id", "")),
		"dialogue_resource": dialogue_resource,
		"dialogue_start": str(_params.get("dialogue_start", "")),
		"ai_mode": ai_mode,
		"ai_available": ai_chat_available,
		"speaker_entity_id": "" if speaker == null else speaker.entity_id,
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"status_text": status_text,
	}


func get_dialogue_resource_path() -> String:
	var dialogue_id := str(_params.get("dialogue_id", ""))
	if not dialogue_id.is_empty():
		return BACKEND_HELPERS.resolve_dialogue_resource_path(dialogue_id)
	return BACKEND_HELPERS.resolve_dialogue_resource_path(str(_params.get("dialogue_resource", "")))


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
	return BACKEND_HELPERS.resolve_sound_path(str(template.get("dialogue_blip", template.get("dialogue_blip_id", ""))))


func has_valid_dialogue_reference() -> bool:
	return not _get_dialogue_reference().is_empty() and not get_dialogue_resource_path().is_empty()


func get_ai_mode() -> String:
	var raw_mode := str(_params.get("ai_mode", AI_MODE_DISABLED)).strip_edges().to_lower()
	match raw_mode:
		AI_MODE_HYBRID, AI_MODE_FREEFORM:
			return raw_mode
		_:
			return AI_MODE_DISABLED


func has_ai_chat_service() -> bool:
	return _ai_chat_service != null and _ai_chat_service.is_configured()


func get_ai_chat_service() -> AIChatService:
	return _ai_chat_service


func can_use_ai_chat() -> bool:
	return has_ai_chat_service() and AIManager.is_available()


func should_start_in_ai_chat() -> bool:
	return get_ai_mode() == AI_MODE_FREEFORM and can_use_ai_chat()


func _resolve_speaker_entity() -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(str(_params.get("speaker_entity_id", "")))


func _get_dialogue_reference() -> String:
	var dialogue_id := str(_params.get("dialogue_id", ""))
	if not dialogue_id.is_empty():
		return dialogue_id
	return str(_params.get("dialogue_resource", ""))


func _initialize_ai_chat_service() -> void:
	_ai_chat_service = null
	if get_ai_mode() == AI_MODE_DISABLED:
		return
	var speaker_entity_id := get_speaker_entity_id()
	if speaker_entity_id.is_empty():
		return
	var ai_settings := APP_SETTINGS.get_ai_settings()
	var history_window_turns := int(ai_settings.get(
		APP_SETTINGS.AI_CHAT_HISTORY_WINDOW,
		APP_SETTINGS.DEFAULT_AI_CHAT_HISTORY_WINDOW
	))
	var service: AIChatService = AI_CHAT_SERVICE.new()
	if not service.configure_for_entity(speaker_entity_id, history_window_turns):
		return
	_ai_chat_service = service
