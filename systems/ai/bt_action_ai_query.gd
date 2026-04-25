@tool
extends BTAction

class_name BTActionAIQuery

const BT_AI_UTILS := preload("res://systems/ai/bt_ai_utils.gd")

@export_multiline var prompt_template: String = ""
@export var result_var: StringName = &"ai_result"
@export var response_format: String = BT_AI_UTILS.RESPONSE_FORMAT_TEXT
@export var enum_options: PackedStringArray = PackedStringArray()
@export_range(0.01, 300.0, 0.01, "or_greater") var timeout_seconds: float = 30.0
@export var fallback_value: String = ""

var _awaiting_response: bool = false
var _response_ready: bool = false
var _elapsed_seconds: float = 0.0
var _request_token: int = 0
var _resolved_status: int = -1
var _resolved_prompt: String = ""
var _raw_response: String = ""


func _generate_name() -> String:
	return "AIQuery (%s -> %s)" % [response_format, str(result_var)]


func _enter() -> void:
	_awaiting_response = false
	_response_ready = false
	_elapsed_seconds = 0.0
	_resolved_status = -1
	_resolved_prompt = ""
	_raw_response = ""


func _exit() -> void:
	_request_token += 1
	_awaiting_response = false
	_response_ready = false


func _tick(delta: float) -> Status:
	if _resolved_status != -1:
		return _resolved_status

	if not _awaiting_response and not _response_ready:
		return _begin_request()

	if _awaiting_response:
		_elapsed_seconds += delta
		if timeout_seconds > 0.0 and _elapsed_seconds >= timeout_seconds:
			_request_token += 1
			return _finish_failure("timeout")
		return RUNNING

	return _consume_response()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if prompt_template.strip_edges().is_empty():
		warnings.append("prompt_template should not be empty.")
	if str(result_var).is_empty():
		warnings.append("result_var should not be empty.")
	if not BT_AI_UTILS.is_supported_response_format(response_format):
		warnings.append("response_format must be 'text', 'enum', or 'json'.")
	if response_format == BT_AI_UTILS.RESPONSE_FORMAT_ENUM and enum_options.is_empty():
		warnings.append("enum_options should contain at least one value when response_format is 'enum'.")
	return warnings


func _begin_request() -> Status:
	if prompt_template.strip_edges().is_empty():
		return _finish_failure("empty_prompt")
	if str(result_var).is_empty():
		return _finish_failure("missing_result_var")
	if not BT_AI_UTILS.is_supported_response_format(response_format):
		return _finish_failure("invalid_response_format")
	if response_format == BT_AI_UTILS.RESPONSE_FORMAT_ENUM and enum_options.is_empty():
		return _finish_failure("missing_enum_options")
	if not AIManager.is_available():
		return _finish_failure("ai_unavailable")

	_resolved_prompt = BT_AI_UTILS.resolve_prompt_template(prompt_template, blackboard)
	if _resolved_prompt.is_empty():
		return _finish_failure("empty_resolved_prompt")

	_awaiting_response = true
	_elapsed_seconds = 0.0
	_response_ready = false
	_raw_response = ""
	_request_token += 1
	var active_request_token := _request_token
	var request_context := _build_request_context()
	AIManager.generate(
		_resolved_prompt,
		request_context,
		Callable(self, "_on_request_completed").bind(active_request_token)
	)
	return RUNNING


func _consume_response() -> Status:
	_response_ready = false
	var parsed_result := _parse_response(_raw_response)
	if not bool(parsed_result.get("success", false)):
		var failure_reason := str(parsed_result.get("reason", "parse_failed"))
		return _finish_failure(failure_reason)

	var result_value: Variant = parsed_result.get("value", "")
	blackboard.set_var(result_var, result_value)
	_resolved_status = SUCCESS
	return SUCCESS


func _parse_response(response: String) -> Dictionary:
	var normalized_format := response_format.strip_edges().to_lower()
	match normalized_format:
		BT_AI_UTILS.RESPONSE_FORMAT_ENUM:
			return BT_AI_UTILS.parse_enum_response(response, enum_options)
		BT_AI_UTILS.RESPONSE_FORMAT_JSON:
			return BT_AI_UTILS.parse_json_response(response)
		_:
			return BT_AI_UTILS.parse_text_response(response)


func _build_request_context() -> Dictionary:
	return {
		"source": "behavior_tree",
		"task": "BTActionAIQuery",
		"response_format": response_format,
		"enum_options": PackedStringArray(enum_options),
	}


func _finish_failure(reason: String) -> Status:
	blackboard.set_var(result_var, fallback_value)
	_resolved_status = FAILURE
	_awaiting_response = false
	_response_ready = false
	_raw_response = ""
	push_warning("BTActionAIQuery: %s" % reason)
	return FAILURE


func _on_request_completed(response: String, active_request_token: int) -> void:
	if active_request_token != _request_token:
		return
	_awaiting_response = false
	_response_ready = true
	_raw_response = response
