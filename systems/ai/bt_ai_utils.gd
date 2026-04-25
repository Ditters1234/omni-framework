@tool
extends RefCounted

class_name BTAIUtils

const RESPONSE_FORMAT_TEXT := "text"
const RESPONSE_FORMAT_ENUM := "enum"
const RESPONSE_FORMAT_JSON := "json"

const _YES_TOKENS := {
	"yes": true,
	"y": true,
	"true": true,
}
const _NO_TOKENS := {
	"no": true,
	"n": true,
	"false": true,
	"nah": true,
}


static func resolve_prompt_template(template_text: String, blackboard: Blackboard) -> String:
	var normalized_template := template_text.strip_edges()
	if normalized_template.is_empty():
		return ""

	var token_pattern := RegEx.new()
	var compile_error := token_pattern.compile("\\{([A-Za-z0-9_]+)\\}")
	if compile_error != OK:
		push_warning("BTAIUtils: failed to compile prompt template token regex.")
		return normalized_template

	var resolved_text := normalized_template
	var matches := token_pattern.search_all(normalized_template)
	for match in matches:
		var token := str(match.get_string(1)).strip_edges()
		if token.is_empty():
			continue
		if blackboard == null or not blackboard.has_var(StringName(token)):
			push_warning("BTAIUtils: unresolved blackboard token '{%s}' in prompt template." % token)
			continue
		var blackboard_value: Variant = blackboard.get_var(StringName(token), null, false)
		resolved_text = resolved_text.replace("{%s}" % token, _variant_to_prompt_string(blackboard_value))
	return resolved_text


static func parse_text_response(response: String) -> Dictionary:
	var cleaned_response := response.strip_edges()
	if cleaned_response.is_empty():
		return {
			"success": false,
			"value": "",
			"reason": "empty_response",
		}
	return {
		"success": true,
		"value": cleaned_response,
		"reason": "accepted",
	}


static func parse_enum_response(response: String, enum_options: PackedStringArray) -> Dictionary:
	var normalized_response := _normalize_match_text(response)
	if normalized_response.is_empty():
		return {
			"success": false,
			"value": "",
			"reason": "empty_response",
		}

	var best_option := ""
	var best_score := -1
	var is_tied := false
	for option_value in enum_options:
		var option := str(option_value).strip_edges()
		if option.is_empty():
			continue
		var normalized_option := _normalize_match_text(option)
		if normalized_option.is_empty():
			continue
		var score := _score_enum_match(normalized_response, normalized_option)
		if score <= 0:
			continue
		if score > best_score:
			best_score = score
			best_option = option
			is_tied = false
		elif score == best_score:
			is_tied = true
	if best_option.is_empty() or is_tied:
		return {
			"success": false,
			"value": "",
			"reason": "enum_parse_failed",
		}
	return {
		"success": true,
		"value": best_option,
		"reason": "accepted",
	}


static func parse_json_response(response: String) -> Dictionary:
	var json_source := _unwrap_json_fence(response)
	if json_source.is_empty():
		return {
			"success": false,
			"value": {},
			"reason": "empty_response",
		}

	var parsed_value: Variant = JSON.parse_string(json_source)
	if not parsed_value is Dictionary:
		return {
			"success": false,
			"value": {},
			"reason": "json_parse_failed",
		}
	return {
		"success": true,
		"value": (parsed_value as Dictionary).duplicate(true),
		"reason": "accepted",
	}


static func parse_yes_no_response(response: String) -> Dictionary:
	var normalized_response := _normalize_match_text(response)
	if normalized_response.is_empty():
		return {
			"success": false,
			"value": false,
			"reason": "empty_response",
		}

	var first_token := normalized_response.get_slice(" ", 0)
	if _YES_TOKENS.has(first_token):
		return {
			"success": true,
			"value": true,
			"reason": "accepted",
		}
	if _NO_TOKENS.has(first_token):
		return {
			"success": true,
			"value": false,
			"reason": "accepted",
		}
	return {
		"success": false,
		"value": false,
		"reason": "yes_no_parse_failed",
	}


static func is_supported_response_format(value: String) -> bool:
	match value.strip_edges().to_lower():
		RESPONSE_FORMAT_TEXT, RESPONSE_FORMAT_ENUM, RESPONSE_FORMAT_JSON:
			return true
		_:
			return false


static func _variant_to_prompt_string(value: Variant) -> String:
	if value == null:
		return ""
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)


static func _normalize_match_text(value: String) -> String:
	var lowered_value := value.to_lower().strip_edges()
	if lowered_value.is_empty():
		return ""
	var cleanup_pattern := RegEx.new()
	var compile_error := cleanup_pattern.compile("[^a-z0-9]+")
	if compile_error != OK:
		return lowered_value
	var cleaned_value := cleanup_pattern.sub(lowered_value, " ", true)
	return cleaned_value.strip_edges()


static func _score_enum_match(normalized_response: String, normalized_option: String) -> int:
	if normalized_response == normalized_option:
		return 400
	if normalized_response.begins_with(normalized_option):
		return 300
	if normalized_option.begins_with(normalized_response):
		return 250
	if normalized_response.contains(normalized_option):
		return 200
	var option_tokens := normalized_option.split(" ", false)
	if option_tokens.is_empty():
		return 0
	var response_tokens := normalized_response.split(" ", false)
	var matched_tokens := 0
	for option_token in option_tokens:
		if response_tokens.has(option_token):
			matched_tokens += 1
	if matched_tokens == option_tokens.size():
		return 150
	return 0


static func _unwrap_json_fence(response: String) -> String:
	var cleaned_response := response.strip_edges()
	if not cleaned_response.begins_with("```"):
		return cleaned_response
	var lines := cleaned_response.split("\n", false)
	if lines.size() < 2:
		return cleaned_response
	lines.remove_at(0)
	if not lines.is_empty() and str(lines[lines.size() - 1]).strip_edges().begins_with("```"):
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines).strip_edges()
