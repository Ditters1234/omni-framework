extends Control

const APP_SETTINGS := preload("res://core/app_settings.gd")
const DIALOGUE_BACKEND := preload("res://ui/screens/backends/dialogue_backend.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const AI_MODE_DISABLED := "disabled"
const AI_MODE_HYBRID := "hybrid"
const AI_MODE_FREEFORM := "freeform"
const AI_INPUT_MAX_LENGTH := 500
const STACKED_LAYOUT_WIDTH := 720.0

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _main_content: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent
@onready var _portrait_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/PortraitScroll/PortraitHost
@onready var _speaker_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/SpeakerLabel
@onready var _body_label: RichTextLabel = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/BodyLabel
@onready var _responses_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/ResponsesContainer
@onready var _ai_chat_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer
@onready var _ai_speaker_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AISpeakerLabel
@onready var _ai_response_label: RichTextLabel = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIResponseLabel
@onready var _ai_input: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIInputRow/AIInput
@onready var _ai_send_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIInputRow/AISendButton
@onready var _ai_back_to_topics_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIBackToTopicsButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _advance_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/AdvanceButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniDialogueBackend = DIALOGUE_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _portrait: Control = null
var _dialogue_resource: Resource = null
var _current_line: RefCounted = null
var _conversation_finished: bool = false
var _request_token: int = 0
var _dialogue_started_emitted: bool = false
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false
var _ai_chat_service: AIChatService = null
var _ai_mode: String = AI_MODE_DISABLED
var _ai_chat_active: bool = false
var _pending_ai_chat_open: bool = false
var _pending_ai_chat_close: bool = false
var _ai_request_id: String = ""
var _ai_request_in_flight: bool = false
var _ai_request_context: Dictionary = {}
var _ai_response_text: String = ""
var _ai_stream_queue: String = ""
var _ai_streaming_speed: float = APP_SETTINGS.DEFAULT_AI_STREAMING_SPEED
var _ai_stream_timer: Timer = null

func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_context()
		_start_dialogue_if_needed()

func _ready() -> void:
	_sync_responsive_layout()
	_create_ai_stream_timer()
	_load_ai_runtime_settings()
	_connect_ai_signals()
	_initialize_backend()
	_refresh_context()
	_start_dialogue_if_needed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_responsive_layout()

func _exit_tree() -> void:
	_request_token += 1
	_ai_request_id = ""
	_ai_request_in_flight = false
	_ai_request_context.clear()
	_clear_ai_stream_state()
	_current_line = null
	_dialogue_resource = null
	if is_instance_valid(_responses_container):
		_clear_responses()
	_disconnect_ai_signals()

func _sync_responsive_layout() -> void:
	if not is_node_ready() or _main_content == null:
		return
	_main_content.columns = 1 if size.x < STACKED_LAYOUT_WIDTH else 2

func get_debug_snapshot() -> Dictionary:
	var snapshot := _last_view_model.duplicate(true)
	snapshot["conversation_finished"] = _conversation_finished
	snapshot["dialogue_started_emitted"] = _dialogue_started_emitted
	snapshot["current_line_id"] = "" if _current_line == null else str(_current_line.get("id"))
	snapshot["opened_from_gameplay_shell"] = _opened_from_gameplay_shell
	snapshot["ai_mode"] = _ai_mode
	snapshot["ai_chat_active"] = _ai_chat_active
	snapshot["ai_request_id"] = _ai_request_id
	snapshot["ai_request_in_flight"] = _ai_request_in_flight
	snapshot["ai_response_text"] = _ai_response_text
	snapshot["ai_service"] = {} if _ai_chat_service == null else _ai_chat_service.get_debug_snapshot()
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
	_load_ai_runtime_settings()
	_ai_mode = str(view_model.get("ai_mode", AI_MODE_DISABLED))
	_ai_chat_service = _backend.get_ai_chat_service()
	_title_label.text = str(view_model.get("title", "Dialogue"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_portrait(_read_dictionary(view_model.get("portrait", {})))
	_refresh_scripted_widgets()
	_refresh_ai_widgets()
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
	if _conversation_finished or _current_line != null or _ai_chat_active:
		return
	if _backend.should_start_in_ai_chat():
		_open_ai_chat_interface()
		return
	var resource_path := _backend.get_dialogue_resource_path()
	if resource_path.is_empty():
		if _backend.can_use_ai_chat():
			_open_ai_chat_interface()
		else:
			_status_label.text = "The configured dialogue reference could not be resolved."
		return
	if not ResourceLoader.exists(resource_path):
		_status_label.text = "The configured dialogue resource could not be loaded."
		return
	var resource_value: Variant = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var dialogue_resource := resource_value as Resource
	if dialogue_resource == null:
		_status_label.text = "The configured dialogue resource could not be loaded."
		return
	_dialogue_resource = dialogue_resource
	_request_token += 1
	var active_request := _request_token
	_emit_dialogue_started()
	var first_line_value: Variant = await dialogue_resource.call(
		"get_next_dialogue_line",
		_backend.get_dialogue_start(),
		[self]
	)
	if active_request != _request_token:
		return
	var first_line := first_line_value as RefCounted
	_apply_line(first_line)

func _apply_line(line: RefCounted) -> void:
	if _pending_ai_chat_close:
		_pending_ai_chat_close = false
		_close_ai_chat_to_topics(false)
		return
	_current_line = line
	if _current_line == null:
		if _pending_ai_chat_open:
			_pending_ai_chat_open = false
			_open_ai_chat_interface()
			return
		_finish_dialogue("Conversation ended.")
		return
	_speaker_label.text = _read_line_character(_current_line)
	_body_label.text = _read_line_text(_current_line)
	_set_ai_response_text("")
	_render_responses(_read_responses(_current_line))
	_play_dialogue_blip()
	_refresh_scripted_widgets()
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
	var line_value: Variant = await _dialogue_resource.call("get_next_dialogue_line", next_id, [self])
	if active_request != _request_token:
		return
	var line := line_value as RefCounted
	_apply_line(line)

func _finish_dialogue(message: String) -> void:
	if _conversation_finished:
		return
	_conversation_finished = true
	_ai_chat_active = false
	_pending_ai_chat_open = false
	_pending_ai_chat_close = false
	_ai_request_in_flight = false
	_ai_request_id = ""
	_ai_request_context.clear()
	_clear_ai_stream_state()
	_current_line = null
	_speaker_label.text = _backend.get_speaker_display_name()
	_body_label.text = message
	_set_ai_response_text("")
	_clear_responses()
	_refresh_scripted_widgets()
	_refresh_ai_widgets()
	_status_label.text = message
	_emit_dialogue_ended()
	_update_advance_button()

func _render_responses(responses: Array[RefCounted]) -> void:
	_clear_responses()
	for response in responses:
		if not _read_response_is_allowed(response):
			continue
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
	if _ai_chat_active:
		_advance_button.visible = false
		return
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
	if _ai_chat_active:
		_finish_dialogue("Conversation closed.")
		_navigate_back()
		return
	if not _conversation_finished:
		_finish_dialogue("Conversation closed.")
	_navigate_back()

func _navigate_back() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
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


func _read_response_is_allowed(response: RefCounted) -> bool:
	var is_allowed_value: Variant = response.get("is_allowed")
	if is_allowed_value is bool:
		return bool(is_allowed_value)
	return true

func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}


func can_open_ai_chat() -> bool:
	return _ai_mode != AI_MODE_DISABLED and _backend.can_use_ai_chat()


func ai_chat_open() -> void:
	if not can_open_ai_chat():
		return
	_pending_ai_chat_open = true


func ai_chat_close() -> void:
	_pending_ai_chat_close = true


func _open_ai_chat_interface() -> void:
	_emit_dialogue_started()
	_ai_chat_active = true
	_conversation_finished = false
	_current_line = null
	_pending_ai_chat_open = false
	_clear_ai_stream_state()
	_ai_speaker_label.text = _backend.get_speaker_display_name()
	_set_ai_response_text("Ask %s anything." % _backend.get_speaker_display_name())
	_status_label.text = ""
	_clear_responses()
	_refresh_scripted_widgets()
	_refresh_ai_widgets()
	_update_advance_button()
	_ai_input.grab_focus()


func _close_ai_chat_to_topics(restart_dialogue: bool = true) -> void:
	_cancel_ai_request()
	_ai_chat_active = false
	_pending_ai_chat_open = false
	_pending_ai_chat_close = false
	_clear_ai_stream_state()
	_set_ai_response_text("")
	_status_label.text = ""
	_refresh_ai_widgets()
	_refresh_scripted_widgets()
	_update_advance_button()
	if restart_dialogue:
		_restart_scripted_dialogue()


func _restart_scripted_dialogue() -> void:
	_request_token += 1
	_current_line = null
	_conversation_finished = false
	_body_label.text = ""
	_clear_responses()
	_start_dialogue_if_needed()


func _refresh_scripted_widgets() -> void:
	var scripted_visible := not _ai_chat_active
	_speaker_label.visible = scripted_visible
	_body_label.visible = scripted_visible
	_responses_container.visible = scripted_visible


func _refresh_ai_widgets() -> void:
	var ai_available := _ai_mode != AI_MODE_DISABLED and _ai_chat_service != null
	_ai_chat_container.visible = _ai_chat_active and ai_available
	_ai_speaker_label.text = _backend.get_speaker_display_name()
	var can_return_to_topics := _ai_mode == AI_MODE_HYBRID and _backend.has_valid_dialogue_reference()
	_ai_back_to_topics_button.visible = can_return_to_topics
	_ai_back_to_topics_button.disabled = _ai_request_in_flight
	var can_send := _ai_chat_active and _backend.can_use_ai_chat() and not _ai_request_in_flight
	_ai_input.max_length = AI_INPUT_MAX_LENGTH
	_ai_input.editable = can_send
	_ai_send_button.disabled = not can_send


func _set_ai_response_text(text: String) -> void:
	_ai_response_text = text
	_ai_response_label.text = text


func _submit_ai_message(raw_message: String) -> void:
	if not _ai_chat_active or _ai_chat_service == null:
		return
	_clear_ai_stream_state()
	var turn := _ai_chat_service.begin_player_turn(raw_message)
	var should_generate := bool(turn.get("should_generate", false))
	var immediate_result_value: Variant = turn.get("result", {})
	if not should_generate:
		if immediate_result_value is Dictionary:
			var immediate_result: Dictionary = immediate_result_value
			_set_ai_response_text(str(immediate_result.get("response", "")))
			var validation_value: Variant = immediate_result.get("validation", {})
			if validation_value is Dictionary:
				var validation: Dictionary = validation_value
				_status_label.text = str(validation.get("reason", ""))
			else:
				_status_label.text = ""
		_refresh_ai_widgets()
		return

	var prompt := str(turn.get("prompt", ""))
	var request_context_value: Variant = turn.get("context", {})
	if request_context_value is Dictionary:
		_ai_request_context = (request_context_value as Dictionary).duplicate(true)
	else:
		_ai_request_context.clear()
	_ai_request_id = AIManager.generate_streaming(prompt, _ai_request_context)
	_ai_request_in_flight = not _ai_request_id.is_empty()
	_set_ai_response_text("")
	_status_label.text = "%s is thinking..." % _backend.get_speaker_display_name()
	_ai_input.text = ""
	_refresh_ai_widgets()


func _cancel_ai_request() -> void:
	_ai_request_in_flight = false
	_ai_request_id = ""
	_ai_request_context.clear()
	_clear_ai_stream_state()


func _connect_ai_signals() -> void:
	if GameEvents == null:
		return
	var token_callable := Callable(self, "_on_ai_token_received")
	if not GameEvents.ai_token_received.is_connected(token_callable):
		GameEvents.ai_token_received.connect(token_callable)
	var response_callable := Callable(self, "_on_ai_response_received")
	if not GameEvents.ai_response_received.is_connected(response_callable):
		GameEvents.ai_response_received.connect(response_callable)
	var error_callable := Callable(self, "_on_ai_error")
	if not GameEvents.ai_error.is_connected(error_callable):
		GameEvents.ai_error.connect(error_callable)


func _disconnect_ai_signals() -> void:
	if GameEvents == null:
		return
	var token_callable := Callable(self, "_on_ai_token_received")
	if GameEvents.ai_token_received.is_connected(token_callable):
		GameEvents.ai_token_received.disconnect(token_callable)
	var response_callable := Callable(self, "_on_ai_response_received")
	if GameEvents.ai_response_received.is_connected(response_callable):
		GameEvents.ai_response_received.disconnect(response_callable)
	var error_callable := Callable(self, "_on_ai_error")
	if GameEvents.ai_error.is_connected(error_callable):
		GameEvents.ai_error.disconnect(error_callable)


func _on_ai_token_received(context_id: String, token: String) -> void:
	if context_id != _ai_request_id or not _ai_request_in_flight:
		return
	if _ai_streaming_speed <= 0.0:
		_set_ai_response_text(_ai_response_text + token)
		return
	_ai_stream_queue += token
	if _ai_stream_timer != null and _ai_stream_timer.is_stopped():
		_ai_stream_timer.start()


func _on_ai_response_received(context_id: String, response: String) -> void:
	if context_id != _ai_request_id:
		return
	var result := _ai_chat_service.finalize_generated_response(response, _ai_request_context)
	_cancel_ai_request()
	_set_ai_response_text(str(result.get("response", "")))
	_status_label.text = ""
	_play_dialogue_blip()
	_refresh_ai_widgets()


func _on_ai_error(context_id: String, error_text: String) -> void:
	if context_id != _ai_request_id:
		return
	var result := _ai_chat_service.finalize_failed_response("provider_error", _ai_request_context)
	_cancel_ai_request()
	_set_ai_response_text(str(result.get("response", "")))
	_status_label.text = error_text
	_refresh_ai_widgets()


func _on_ai_send_button_pressed() -> void:
	_submit_ai_message(_ai_input.text)


func _on_ai_input_text_submitted(new_text: String) -> void:
	_submit_ai_message(new_text)


func _on_ai_back_to_topics_button_pressed() -> void:
	_close_ai_chat_to_topics()


func _create_ai_stream_timer() -> void:
	if _ai_stream_timer != null:
		return
	_ai_stream_timer = Timer.new()
	_ai_stream_timer.one_shot = false
	_ai_stream_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_ai_stream_timer.timeout.connect(_on_ai_stream_timer_timeout)
	add_child(_ai_stream_timer)


func _load_ai_runtime_settings() -> void:
	var ai_settings := APP_SETTINGS.get_ai_settings()
	_ai_streaming_speed = float(ai_settings.get(
		APP_SETTINGS.AI_STREAMING_SPEED,
		APP_SETTINGS.DEFAULT_AI_STREAMING_SPEED
	))
	if _ai_stream_timer != null:
		_ai_stream_timer.wait_time = maxf(_ai_streaming_speed, 0.01)


func _clear_ai_stream_state() -> void:
	_ai_stream_queue = ""
	if _ai_stream_timer != null:
		_ai_stream_timer.stop()


func _on_ai_stream_timer_timeout() -> void:
	if _ai_stream_queue.is_empty():
		if _ai_stream_timer != null:
			_ai_stream_timer.stop()
		return
	_set_ai_response_text(_ai_response_text + _ai_stream_queue.left(1))
	_ai_stream_queue = _ai_stream_queue.substr(1)
	if _ai_stream_queue.is_empty() and _ai_stream_timer != null:
		_ai_stream_timer.stop()
