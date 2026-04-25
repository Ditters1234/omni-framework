@tool
extends BTCondition

class_name BTConditionAICheck

const BT_AI_UTILS := preload("res://systems/ai/bt_ai_utils.gd")

const _YES_NO_SUFFIX := "Respond with only YES or NO."

@export_multiline var prompt_template: String = ""
@export var default_result: bool = false
@export_range(0.01, 300.0, 0.01, "or_greater") var timeout_seconds: float = 10.0

var _awaiting_response: bool = false
var _response_ready: bool = false
var _elapsed_seconds: float = 0.0
var _request_token: int = 0
var _resolved_status: int = -1
var _resolved_prompt: String = ""
var _raw_response: String = ""


func _generate_name() -> String:
	return "AICheck (%s)" % prompt_template.strip_edges()


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
			return _finish_with_default("timeout")
		return RUNNING

	return _consume_response()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if prompt_template.strip_edges().is_empty():
		warnings.append("prompt_template should not be empty.")
	return warnings


func _begin_request() -> Status:
	if prompt_template.strip_edges().is_empty():
		return _finish_with_default("empty_prompt")
	if not AIManager.is_available():
		return _finish_with_default("ai_unavailable")

	var resolved_template := BT_AI_UTILS.resolve_prompt_template(prompt_template, blackboard)
	if resolved_template.is_empty():
		return _finish_with_default("empty_resolved_prompt")
	_resolved_prompt = resolved_template
	if not _resolved_prompt.to_lower().contains(_YES_NO_SUFFIX.to_lower()):
		_resolved_prompt = "%s\n\n%s" % [_resolved_prompt, _YES_NO_SUFFIX]

	_awaiting_response = true
	_elapsed_seconds = 0.0
	_response_ready = false
	_raw_response = ""
	_request_token += 1
	var active_request_token := _request_token
	var request_context := {
		"source": "behavior_tree",
		"task": "BTConditionAICheck",
		"response_format": "yes_no",
	}
	AIManager.generate(
		_resolved_prompt,
		request_context,
		Callable(self, "_on_request_completed").bind(active_request_token)
	)
	return RUNNING


func _consume_response() -> Status:
	_response_ready = false
	var parsed_result := BT_AI_UTILS.parse_yes_no_response(_raw_response)
	if not bool(parsed_result.get("success", false)):
		var failure_reason := str(parsed_result.get("reason", "parse_failed"))
		return _finish_with_default(failure_reason)
	var result_value := bool(parsed_result.get("value", false))
	_resolved_status = SUCCESS if result_value else FAILURE
	return _resolved_status


func _finish_with_default(reason: String) -> Status:
	push_warning("BTConditionAICheck: %s" % reason)
	_resolved_status = SUCCESS if default_result else FAILURE
	_awaiting_response = false
	_response_ready = false
	_raw_response = ""
	return _resolved_status


func _on_request_completed(response: String, active_request_token: int) -> void:
	if active_request_token != _request_token:
		return
	_awaiting_response = false
	_response_ready = true
	_raw_response = response
