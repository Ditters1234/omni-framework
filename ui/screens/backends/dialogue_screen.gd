extends Control

const DIALOGUE_BACKEND := preload("res://ui/screens/backends/dialogue_backend.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const DIALOGUE_RESOURCE_SCRIPT := preload("res://addons/dialogue_manager/dialogue_resource.gd")
const DIALOGUE_LINE_SCRIPT := preload("res://addons/dialogue_manager/dialogue_line.gd")
const DIALOGUE_RESPONSE_SCRIPT := preload("res://addons/dialogue_manager/dialogue_response.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _portrait_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/PortraitHost
@onready var _speaker_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationPanel/SpeakerLabel
@onready var _body_label: RichTextLabel = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationPanel/BodyLabel
@onready var _responses_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationPanel/ResponsesContainer
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _advance_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/AdvanceButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = DIALOGUE_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _portrait: Control = null
var _dialogue_resource: Resource = null
var _current_line: RefCounted = null
var _conversation_finished: bool = false
var _request_token: int = 0
var _dialogue_started_emitted: bool = false
var _last_view_model: Dictionary = {}


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_initialize_backend()
	if is_node_ready():
		_refresh_context()
		_start_dialogue_if_needed()


func _ready() -> void:
	_initialize_backend()
	_refresh_context()
	_start_dialogue_if_needed()


func get_debug_snapshot() -> Dictionary:
	var snapshot := _last_view_model.duplicate(true)
	snapshot["conversation_finished"] = _conversation_finished
	snapshot["dialogue_started_emitted"] = _dialogue_started_emitted
	snapshot["current_line_id"] = "" if _current_line == null else str(_current_line.get("id"))
	return snapshot


func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_pending_params = {}
	_backend_initialized = true


func _refresh_context() -> void:
	if not _backend_initialized:
		return
	var view_model: Dictionary = _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_title_label.text = str(view_model.get("title", "Dialogue"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_portrait(_read_dictionary(view_model.get("portrait", {})))
	_update_advance_button()


func _render_portrait(view_model: Dictionary) -> void:
	if _portrait == null:
		var portrait_value: Variant = ENTITY_PORTRAIT_SCENE.instantiate()
		if portrait_value is Control:
			_portrait = portrait_value
			_portrait_host.add_child(_portrait)
	if _portrait != null:
		_portrait.call("render", view_model)


func _start_dialogue_if_needed() -> void:
	if _conversation_finished or _current_line != null:
		return
	var resource_path := _backend.get_dialogue_resource_path()
	if resource_path.is_empty():
		_status_label.text = "This dialogue entry is missing a dialogue_resource path."
		return
	if not ResourceLoader.exists(resource_path):
		_status_label.text = "The configured dialogue resource could not be loaded."
		return
	var resource_value: Variant = load(resource_path)
	var dialogue_resource := resource_value as Resource
	if dialogue_resource == null:
		_status_label.text = "The configured dialogue resource could not be loaded."
		return
	_dialogue_resource = dialogue_resource
	_request_token += 1
	var active_request := _request_token
	_emit_dialogue_started()
	var first_line_value: Variant = await dialogue_resource.call("get_next_dialogue_line", _backend.get_dialogue_start())
	if active_request != _request_token:
		return
	var first_line := first_line_value as RefCounted
	_apply_line(first_line)


func _apply_line(line: RefCounted) -> void:
	_current_line = line
	if _current_line == null:
		_finish_dialogue("Conversation ended.")
		return
	_speaker_label.text = _read_line_character(_current_line)
	_body_label.text = _read_line_text(_current_line)
	_render_responses(_read_responses(_current_line))
	_play_dialogue_blip()
	_update_advance_button()
	if _body_label.text.is_empty() and _responses_container.get_child_count() == 0:
		var next_id := _read_line_next_id(_current_line)
		if next_id.is_empty():
			_finish_dialogue("Conversation ended.")
			return
		_advance_to(next_id)


func _advance_to(next_id: String) -> void:
	if _dialogue_resource == null:
		_finish_dialogue("Conversation ended.")
		return
	_request_token += 1
	var active_request := _request_token
	var line_value: Variant = await _dialogue_resource.call("get_next_dialogue_line", next_id)
	if active_request != _request_token:
		return
	var line := line_value as RefCounted
	_apply_line(line)


func _finish_dialogue(message: String) -> void:
	if _conversation_finished:
		return
	_conversation_finished = true
	_current_line = null
	_speaker_label.text = _backend.get_speaker_display_name()
	_body_label.text = message
	_clear_responses()
	_status_label.text = message
	_emit_dialogue_ended()
	_update_advance_button()


func _render_responses(responses: Array[RefCounted]) -> void:
	_clear_responses()
	for response in responses:
		var response_text := _read_response_text(response)
		if response_text.is_empty():
			continue
		var button := Button.new()
		button.text = response_text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_response_pressed.bind(_read_response_next_id(response)))
		_responses_container.add_child(button)


func _clear_responses() -> void:
	for child in _responses_container.get_children():
		_responses_container.remove_child(child)
		child.queue_free()


func _update_advance_button() -> void:
	if _conversation_finished:
		_advance_button.visible = true
		_advance_button.text = "Close"
		return
	if _current_line == null:
		_advance_button.visible = false
		return
	if _responses_container.get_child_count() > 0:
		_advance_button.visible = false
		return
	var next_id := _read_line_next_id(_current_line)
	_advance_button.visible = true
	_advance_button.text = "Close" if next_id.is_empty() else "Continue"


func _play_dialogue_blip() -> void:
	var dialogue_blip := _backend.get_dialogue_blip_path()
	if dialogue_blip.is_empty():
		return
	AudioManager.play_sfx(dialogue_blip)


func _emit_dialogue_started() -> void:
	if _dialogue_started_emitted:
		return
	_dialogue_started_emitted = true
	if GameEvents != null:
		GameEvents.dialogue_started.emit(_backend.get_speaker_entity_id(), _backend.get_dialogue_resource_path())


func _emit_dialogue_ended() -> void:
	if not _dialogue_started_emitted:
		return
	_dialogue_started_emitted = false
	if GameEvents != null:
		GameEvents.dialogue_ended.emit(_backend.get_speaker_entity_id(), _backend.get_dialogue_resource_path())


func _on_response_pressed(next_id: String) -> void:
	if next_id.is_empty():
		_finish_dialogue("Conversation ended.")
		return
	_advance_to(next_id)


func _on_advance_button_pressed() -> void:
	if _conversation_finished:
		_on_back_button_pressed()
		return
	if _current_line == null:
		_on_back_button_pressed()
		return
	var next_id := _read_line_next_id(_current_line)
	if next_id.is_empty():
		_finish_dialogue("Conversation ended.")
		return
	_advance_to(next_id)


func _on_back_button_pressed() -> void:
	if not _conversation_finished:
		_finish_dialogue("Conversation closed.")
	UIRouter.pop()


func _read_line_character(line: RefCounted) -> String:
	var character_value: Variant = line.get("character")
	var character_name := str(character_value)
	if character_name.is_empty():
		return _backend.get_speaker_display_name()
	return character_name


func _read_line_text(line: RefCounted) -> String:
	var text_value: Variant = line.get("text")
	return str(text_value)


func _read_line_next_id(line: RefCounted) -> String:
	var next_id_value: Variant = line.get("next_id")
	return str(next_id_value)


func _read_responses(line: RefCounted) -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	var responses_value: Variant = line.get("responses")
	if not responses_value is Array:
		return result
	var responses: Array = responses_value
	for response_value in responses:
		var response := response_value as RefCounted
		if response != null:
			result.append(response)
	return result


func _read_response_text(response: RefCounted) -> String:
	var text_value: Variant = response.get("text")
	return str(text_value)


func _read_response_next_id(response: RefCounted) -> String:
	var next_id_value: Variant = response.get("next_id")
	return str(next_id_value)


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
