## AIChatService -- Persona-aware prompt builder and conversation state helper.
## Bridges entity/persona data to AIManager without owning any UI.
extends RefCounted

class_name AIChatService

const ROLE_USER := "user"
const ROLE_ASSISTANT := "assistant"
const ROLE_SYSTEM := "system"
const DEFAULT_HISTORY_WINDOW_TURNS := 20
const DEFAULT_FALLBACK_LINE := "I don't have anything useful to add to that."
const CHARACTER_BREAKER_PHRASES := [
	"as an ai",
	"language model",
	"artificial intelligence",
	"i cannot browse",
	"i don't have personal",
	"i do not have personal",
	"i don't have feelings",
	"i do not have feelings",
	"openai",
	"anthropic",
]

var _speaker_entity_id: String = ""
var _speaker_template: Dictionary = {}
var _persona_id: String = ""
var _persona: Dictionary = {}
var _history_window_turns: int = DEFAULT_HISTORY_WINDOW_TURNS
var _history: Array[Dictionary] = []
var _last_system_prompt: String = ""
var _last_player_message: String = ""
var _last_raw_response: String = ""
var _last_response: String = ""
var _last_validation: Dictionary = {}


func configure_for_entity(
		speaker_entity_id: String,
		history_window_turns: int = DEFAULT_HISTORY_WINDOW_TURNS) -> bool:
	_reset_runtime_state()
	_history_window_turns = maxi(history_window_turns, 1)
	_speaker_entity_id = speaker_entity_id.strip_edges()
	if _speaker_entity_id.is_empty():
		push_warning("AIChatService: speaker_entity_id must not be empty.")
		return false

	var speaker_instance := GameState.get_entity_instance(_speaker_entity_id)
	if speaker_instance != null:
		_speaker_template = speaker_instance.get_template()
	if _speaker_template.is_empty():
		_speaker_template = DataManager.get_entity(_speaker_entity_id)
	if _speaker_template.is_empty():
		push_warning("AIChatService: unable to resolve entity '%s'." % _speaker_entity_id)
		return false

	var persona_id_value: Variant = _speaker_template.get("ai_persona_id", "")
	_persona_id = str(persona_id_value).strip_edges()
	if _persona_id.is_empty():
		push_warning("AIChatService: entity '%s' does not declare ai_persona_id." % _speaker_entity_id)
		return false

	_persona = DataManager.get_ai_persona(_persona_id)
	if _persona.is_empty():
		push_warning("AIChatService: entity '%s' references missing AI persona '%s'." % [_speaker_entity_id, _persona_id])
		return false
	return true


func is_configured() -> bool:
	return not _speaker_entity_id.is_empty() and not _speaker_template.is_empty() and not _persona.is_empty()


func get_speaker_entity_id() -> String:
	return _speaker_entity_id


func get_persona_id() -> String:
	return _persona_id


func get_persona() -> Dictionary:
	return _persona.duplicate(true)


func clear_history() -> void:
	_history.clear()


func get_history() -> Array[Dictionary]:
	return _duplicate_history(_history)


func add_message(role: String, content: String) -> void:
	var normalized_content := content.strip_edges()
	if normalized_content.is_empty():
		return
	_history.append({
		"role": _normalize_role(role),
		"content": normalized_content,
	})
	_trim_history()


func build_context() -> Dictionary:
	var context := {
		"system_prompt": build_system_prompt(),
		"history": _duplicate_history(_history),
	}
	return context


func build_system_prompt() -> String:
	if _persona.is_empty():
		_last_system_prompt = ""
		return ""

	var prompt_lines: Array[String] = []
	var template_value: Variant = _persona.get("system_prompt_template", "")
	var template_text := str(template_value).strip_edges()
	if not template_text.is_empty():
		prompt_lines.append(_resolve_placeholder_tokens(template_text))

	var personality_traits := _variant_to_string_array(_persona.get("personality_traits", []))
	if not personality_traits.is_empty():
		prompt_lines.append("Personality traits: %s." % ", ".join(personality_traits))

	var speech_style_value: Variant = _persona.get("speech_style", "")
	var speech_style := str(speech_style_value).strip_edges()
	if not speech_style.is_empty():
		prompt_lines.append("Speech style: %s" % speech_style)

	var constraints := _read_response_constraints()
	var tone := str(constraints.get("tone", "")).strip_edges()
	if not tone.is_empty():
		prompt_lines.append("Tone target: %s." % tone)

	var max_sentences := int(constraints.get("max_sentences", 0))
	if max_sentences > 0:
		prompt_lines.append("Keep each reply to %d sentences or fewer." % max_sentences)

	if bool(constraints.get("always_in_character", false)):
		prompt_lines.append("Always stay in character and never mention being an AI system or assistant.")

	var forbidden_topics := _variant_to_string_array(_persona.get("forbidden_topics", []))
	if not forbidden_topics.is_empty():
		prompt_lines.append("Avoid these topics: %s. Deflect briefly and stay in character." % ", ".join(forbidden_topics))

	var knowledge_block := _build_knowledge_block()
	if not knowledge_block.is_empty():
		prompt_lines.append("Relevant world knowledge:\n%s" % knowledge_block)

	_last_system_prompt = "\n\n".join(prompt_lines).strip_edges()
	return _last_system_prompt


func send_message_async(
		player_message: String,
		request_context_overrides: Dictionary = {}) -> Dictionary:
	var normalized_message := player_message.strip_edges()
	_last_player_message = normalized_message
	_last_raw_response = ""
	_last_response = ""
	var base_context := build_context()
	var request_context := _merge_context(base_context, request_context_overrides)

	if normalized_message.is_empty():
		var empty_prompt_validation := _build_fallback_validation("empty_prompt")
		return _build_result(request_context, empty_prompt_validation)

	add_message(ROLE_USER, normalized_message)

	if not is_configured():
		var unconfigured_validation := _build_fallback_validation("service_unconfigured")
		var unconfigured_response := str(unconfigured_validation.get("response", ""))
		add_message(ROLE_ASSISTANT, unconfigured_response)
		return _build_result(request_context, unconfigured_validation)

	if not AIManager.is_available():
		var unavailable_validation := _build_fallback_validation("ai_unavailable")
		var unavailable_response := str(unavailable_validation.get("response", ""))
		add_message(ROLE_ASSISTANT, unavailable_response)
		return _build_result(request_context, unavailable_validation)

	var raw_response := await AIManager.generate_async(normalized_message, request_context)
	_last_raw_response = raw_response
	var validation := validate_response(raw_response)
	var final_response := str(validation.get("response", ""))
	add_message(ROLE_ASSISTANT, final_response)
	return _build_result(request_context, validation)


func validate_response(response: String) -> Dictionary:
	var cleaned_response := response.strip_edges()
	if cleaned_response.is_empty():
		return _store_validation_result(_build_fallback_validation("empty_response"))

	var constraints := _read_response_constraints()
	var max_sentences := int(constraints.get("max_sentences", 0))
	var truncated := false
	if max_sentences > 0:
		var truncated_response := _truncate_to_sentence_limit(cleaned_response, max_sentences * 2)
		if truncated_response != cleaned_response:
			cleaned_response = truncated_response
			truncated = true

	if bool(constraints.get("always_in_character", false)) and _contains_character_breaker(cleaned_response):
		return _store_validation_result(_build_fallback_validation("character_break"))

	if _contains_forbidden_topic(cleaned_response):
		return _store_validation_result(_build_fallback_validation("forbidden_topic"))

	return _store_validation_result({
		"response": cleaned_response,
		"used_fallback": false,
		"reason": "accepted",
		"truncated": truncated,
	})


func get_debug_snapshot() -> Dictionary:
	return {
		"configured": is_configured(),
		"speaker_entity_id": _speaker_entity_id,
		"persona_id": _persona_id,
		"history_window_turns": _history_window_turns,
		"history": _duplicate_history(_history),
		"last_system_prompt": _last_system_prompt,
		"last_player_message": _last_player_message,
		"last_raw_response": _last_raw_response,
		"last_response": _last_response,
		"last_validation": _last_validation.duplicate(true),
	}


func _build_result(request_context: Dictionary, validation: Dictionary) -> Dictionary:
	var final_response := str(validation.get("response", ""))
	_last_response = final_response
	return {
		"response": final_response,
		"used_fallback": bool(validation.get("used_fallback", false)),
		"validation": validation.duplicate(true),
		"context": request_context.duplicate(true),
		"history": _duplicate_history(_history),
	}


func _store_validation_result(validation: Dictionary) -> Dictionary:
	_last_validation = validation.duplicate(true)
	_last_response = str(validation.get("response", ""))
	return validation


func _resolve_placeholder_tokens(template_text: String) -> String:
	var placeholder_values := _build_placeholder_values()
	var placeholder_pattern := RegEx.new()
	var compile_error := placeholder_pattern.compile("\\{([A-Za-z0-9_]+)\\}")
	if compile_error != OK:
		push_warning("AIChatService: failed to compile placeholder regex.")
		return template_text

	var resolved_text := template_text
	var matches := placeholder_pattern.search_all(template_text)
	for match in matches:
		var token := str(match.get_string(1))
		if placeholder_values.has(token):
			resolved_text = resolved_text.replace("{%s}" % token, str(placeholder_values.get(token, "")))
			continue
		push_warning("AIChatService: unrecognized system prompt token '{%s}' for persona '%s'." % [token, _persona_id])
	return resolved_text


func _build_placeholder_values() -> Dictionary:
	var speaker_display_name := str(_speaker_template.get("display_name", _humanize_identifier(_speaker_entity_id)))
	var description := str(_speaker_template.get("description", ""))
	var speaker_location_id := _resolve_speaker_location_id()
	var location_template := DataManager.get_location(speaker_location_id)
	var location_name := str(location_template.get("display_name", ""))
	var primary_faction_id := _resolve_primary_faction_id(speaker_location_id)
	var faction_template := DataManager.get_faction(primary_faction_id)
	var faction_name := str(faction_template.get("display_name", ""))
	return {
		"display_name": speaker_display_name,
		"description": description,
		"location_name": location_name,
		"faction_name": faction_name,
		"reputation_tier": _build_reputation_tier(primary_faction_id, faction_template),
		"player_name": _build_player_name(),
		"player_stats": _build_player_stats_summary(),
		"time_of_day": _build_time_of_day(),
		"active_quests": _build_active_quest_summary(),
		"knowledge_block": _build_knowledge_block(),
	}


func _build_player_name() -> String:
	var player := GameState.player as EntityInstance
	if player == null:
		return ""
	var player_template := player.get_template()
	return str(player_template.get("display_name", player.entity_id))


func _build_player_stats_summary() -> String:
	var player := GameState.player as EntityInstance
	if player == null:
		return ""

	var parts: Array[String] = []
	var stat_definitions := DataManager.get_definitions("stats")
	for stat_def_value in stat_definitions:
		if not stat_def_value is Dictionary:
			continue
		var stat_def: Dictionary = stat_def_value
		var stat_id := str(stat_def.get("id", ""))
		if stat_id.is_empty():
			continue
		var kind := str(stat_def.get("kind", "flat"))
		if kind == "capacity":
			continue
		if kind == "resource":
			var paired_capacity_id := str(stat_def.get("paired_capacity_id", "%s_max" % stat_id))
			parts.append("%s: %s/%s" % [
				stat_id,
				_format_number(player.get_stat(stat_id)),
				_format_number(player.get_stat(paired_capacity_id)),
			])
			continue
		var stat_value := player.get_stat(stat_id)
		if is_zero_approx(stat_value):
			continue
		parts.append("%s: %s" % [stat_id, _format_number(stat_value)])
	if parts.is_empty():
		for stat_key_value in player.stats.keys():
			var stat_key := str(stat_key_value)
			if stat_key.ends_with("_max"):
				continue
			parts.append("%s: %s" % [stat_key, _format_number(player.get_stat(stat_key))])
		parts.sort()
	return ", ".join(parts)


func _build_time_of_day() -> String:
	var ticks_per_day := 24
	if TimeKeeper != null and TimeKeeper.has_method("get_ticks_per_day"):
		ticks_per_day = int(TimeKeeper.get_ticks_per_day())
	if ticks_per_day <= 0:
		ticks_per_day = 24
	var ticks_into_day := 0
	if TimeKeeper != null and TimeKeeper.has_method("get_ticks_into_day"):
		ticks_into_day = int(TimeKeeper.get_ticks_into_day())
	var day_fraction := float(ticks_into_day) / float(ticks_per_day)
	var hour := int(floor(day_fraction * 24.0))
	if hour < 6:
		return "night"
	if hour < 12:
		return "morning"
	if hour < 18:
		return "afternoon"
	if hour < 22:
		return "evening"
	return "night"


func _build_active_quest_summary() -> String:
	var quest_names: Array[String] = []
	for quest_id_value in GameState.active_quests.keys():
		var quest_id := str(quest_id_value)
		if quest_id.is_empty():
			continue
		var quest_template := DataManager.get_quest(quest_id)
		var display_name := str(quest_template.get("display_name", quest_id))
		if display_name.is_empty():
			continue
		quest_names.append(display_name)
	quest_names.sort()
	return ", ".join(quest_names)


func _build_knowledge_block() -> String:
	if _persona.is_empty():
		return ""
	var scope_tags := _variant_to_string_array(_persona.get("knowledge_scope", []))
	if scope_tags.is_empty():
		return ""

	var lines: Array[String] = []
	var seen_lines: Dictionary = {}
	var speaker_location_id := _resolve_speaker_location_id()
	var primary_faction_id := _resolve_primary_faction_id(speaker_location_id)
	var faction_template := DataManager.get_faction(primary_faction_id)
	var location_template := DataManager.get_location(speaker_location_id)

	if not faction_template.is_empty() and _scope_matches(primary_faction_id, str(faction_template.get("display_name", "")), scope_tags):
		var faction_line := "%s: %s" % [
			str(faction_template.get("display_name", primary_faction_id)),
			str(faction_template.get("description", "")),
		]
		_append_unique_line(lines, seen_lines, faction_line)

	if not location_template.is_empty() and _scope_matches(speaker_location_id, str(location_template.get("display_name", "")), scope_tags):
		var location_line := "%s: %s" % [
			str(location_template.get("display_name", speaker_location_id)),
			str(location_template.get("description", "")),
		]
		_append_unique_line(lines, seen_lines, location_line)

	for quest_id_value in GameState.active_quests.keys():
		var quest_id := str(quest_id_value)
		if quest_id.is_empty():
			continue
		var quest_template := DataManager.get_quest(quest_id)
		if quest_template.is_empty():
			continue
		var quest_display_name := str(quest_template.get("display_name", quest_id))
		if not _scope_matches(quest_id, quest_display_name, scope_tags):
			continue
		var quest_line := "Quest - %s: %s" % [
			quest_display_name,
			str(quest_template.get("description", "")),
		]
		_append_unique_line(lines, seen_lines, quest_line)

	var unmatched_topics: Array[String] = []
	for scope_tag in scope_tags:
		if _scope_matches(primary_faction_id, str(faction_template.get("display_name", "")), [scope_tag]):
			continue
		if _scope_matches(speaker_location_id, str(location_template.get("display_name", "")), [scope_tag]):
			continue
		unmatched_topics.append(_humanize_identifier(scope_tag))
	if not unmatched_topics.is_empty():
		_append_unique_line(lines, seen_lines, "Relevant topics: %s." % ", ".join(unmatched_topics))

	return "\n".join(lines).strip_edges()


func _build_reputation_tier(primary_faction_id: String, faction_template: Dictionary) -> String:
	if primary_faction_id.is_empty():
		return ""
	var player := GameState.player as EntityInstance
	if player == null:
		return ""
	var reputation_score := player.get_reputation(primary_faction_id)
	var thresholds_value: Variant = faction_template.get("reputation_thresholds", {})
	if not thresholds_value is Dictionary:
		return _format_number(reputation_score)
	var thresholds: Dictionary = thresholds_value
	var best_label := ""
	var best_threshold := -INF
	var lowest_label := ""
	var lowest_threshold := INF
	for label_value in thresholds.keys():
		var label := str(label_value)
		var threshold_value: Variant = thresholds.get(label_value, 0.0)
		var threshold := float(threshold_value)
		if threshold < lowest_threshold:
			lowest_threshold = threshold
			lowest_label = label
		if reputation_score >= threshold and threshold >= best_threshold:
			best_threshold = threshold
			best_label = label
	if best_label.is_empty():
		best_label = lowest_label
	return _humanize_identifier(best_label)


func _resolve_speaker_location_id() -> String:
	var speaker_instance := GameState.get_entity_instance(_speaker_entity_id)
	if speaker_instance != null and not speaker_instance.location_id.is_empty():
		return speaker_instance.location_id
	var template_location_value: Variant = _speaker_template.get("location_id", "")
	var template_location_id := str(template_location_value)
	if not template_location_id.is_empty():
		return template_location_id
	return GameState.current_location_id


func _resolve_primary_faction_id(speaker_location_id: String) -> String:
	var direct_faction_value: Variant = _speaker_template.get("faction_id", "")
	var direct_faction_id := str(direct_faction_value)
	if not direct_faction_id.is_empty() and DataManager.has_faction(direct_faction_id):
		return direct_faction_id

	if not speaker_location_id.is_empty():
		var location_template := DataManager.get_location(speaker_location_id)
		var location_faction_value: Variant = location_template.get("faction_id", "")
		var location_faction_id := str(location_faction_value)
		if not location_faction_id.is_empty() and DataManager.has_faction(location_faction_id):
			return location_faction_id
		for faction_id_value in DataManager.factions.keys():
			var faction_id := str(faction_id_value)
			if faction_id.is_empty():
				continue
			var faction_template := DataManager.get_faction(faction_id)
			var territory := _variant_to_string_array(faction_template.get("territory", []))
			if territory.has(speaker_location_id):
				return faction_id
	return ""


func _read_response_constraints() -> Dictionary:
	var constraints_value: Variant = _persona.get("response_constraints", {})
	if constraints_value is Dictionary:
		return (constraints_value as Dictionary).duplicate(true)
	return {}


func _truncate_to_sentence_limit(text: String, max_sentences: int) -> String:
	if max_sentences <= 0:
		return text
	var sentences := _split_sentences(text)
	if sentences.size() <= max_sentences:
		return text
	var limited_sentences := sentences.slice(0, max_sentences)
	return " ".join(limited_sentences).strip_edges()


func _split_sentences(text: String) -> Array[String]:
	var sentences: Array[String] = []
	var buffer := ""
	for i in range(text.length()):
		var character := text.substr(i, 1)
		buffer += character
		if character == "." or character == "!" or character == "?":
			var sentence := buffer.strip_edges()
			if not sentence.is_empty():
				sentences.append(sentence)
			buffer = ""
	var trailing_text := buffer.strip_edges()
	if not trailing_text.is_empty():
		sentences.append(trailing_text)
	return sentences


func _contains_character_breaker(text: String) -> bool:
	var lowered_text := text.to_lower()
	for phrase_value in CHARACTER_BREAKER_PHRASES:
		var phrase := str(phrase_value)
		if lowered_text.contains(phrase):
			return true
	return false


func _contains_forbidden_topic(text: String) -> bool:
	var lowered_text := text.to_lower()
	var forbidden_topics := _variant_to_string_array(_persona.get("forbidden_topics", []))
	for forbidden_topic in forbidden_topics:
		if lowered_text.contains(forbidden_topic.to_lower()):
			return true
	return false


func _build_fallback_validation(reason: String) -> Dictionary:
	return {
		"response": _select_fallback_line(reason),
		"used_fallback": true,
		"reason": reason,
		"truncated": false,
	}


func _select_fallback_line(reason: String) -> String:
	var fallback_lines := _variant_to_string_array(_persona.get("fallback_lines", []))
	var cleaned_lines: Array[String] = []
	for fallback_line in fallback_lines:
		var cleaned_line := fallback_line.strip_edges()
		if not cleaned_line.is_empty():
			cleaned_lines.append(cleaned_line)
	if cleaned_lines.is_empty():
		return DEFAULT_FALLBACK_LINE

	if reason == "forbidden_topic":
		for cleaned_line in cleaned_lines:
			var lowered_line := cleaned_line.to_lower()
			if lowered_line.contains("business") or lowered_line.contains("ask") or lowered_line.contains("help"):
				return cleaned_line

	var line_index := posmod(_history.size(), cleaned_lines.size())
	return cleaned_lines[line_index]


func _scope_matches(candidate_id: String, display_name: String, scope_tags: Array[String]) -> bool:
	if candidate_id.is_empty() and display_name.is_empty():
		return false
	var candidate_id_tail := ""
	if not candidate_id.is_empty():
		candidate_id_tail = candidate_id.get_slice(":", candidate_id.get_slice_count(":") - 1).replace("_", " ").to_lower()
	var lowered_display_name := display_name.replace("_", " ").to_lower()
	for scope_tag in scope_tags:
		var normalized_tag := scope_tag.replace("_", " ").to_lower()
		if normalized_tag.is_empty():
			continue
		if candidate_id_tail.contains(normalized_tag) or lowered_display_name.contains(normalized_tag):
			return true
	return false


func _append_unique_line(lines: Array[String], seen_lines: Dictionary, line: String) -> void:
	var normalized_line := line.strip_edges()
	if normalized_line.is_empty() or seen_lines.has(normalized_line):
		return
	seen_lines[normalized_line] = true
	lines.append(normalized_line)


func _trim_history() -> void:
	var max_entries := maxi(_history_window_turns, 1) * 2
	while _history.size() > max_entries:
		_history.remove_at(0)


func _merge_context(base_context: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := base_context.duplicate(true)
	for key_value in overrides.keys():
		var key := str(key_value)
		var value: Variant = overrides.get(key_value, null)
		if value is Dictionary:
			merged[key] = (value as Dictionary).duplicate(true)
			continue
		if value is Array:
			merged[key] = (value as Array).duplicate(true)
			continue
		merged[key] = value
	return merged


func _duplicate_history(source_history: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source_history:
		result.append(entry.duplicate(true))
	return result


func _variant_to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	var value_array: Array = values
	for value in value_array:
		var normalized_value := str(value).strip_edges()
		if normalized_value.is_empty():
			continue
		result.append(normalized_value)
	return result


func _normalize_role(role: String) -> String:
	var normalized_role := role.strip_edges().to_lower()
	match normalized_role:
		ROLE_USER, ROLE_ASSISTANT, ROLE_SYSTEM:
			return normalized_role
		_:
			push_warning("AIChatService: unsupported history role '%s'. Falling back to 'user'." % role)
			return ROLE_USER


func _humanize_identifier(value: String) -> String:
	var normalized_value := value.strip_edges()
	if normalized_value.is_empty():
		return ""
	var namespaced_tail := normalized_value.get_slice(":", normalized_value.get_slice_count(":") - 1)
	var humanized_value := namespaced_tail.replace("_", " ")
	return humanized_value.substr(0, 1).to_upper() + humanized_value.substr(1)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.01))


func _reset_runtime_state() -> void:
	_speaker_entity_id = ""
	_speaker_template.clear()
	_persona_id = ""
	_persona.clear()
	_history.clear()
	_last_system_prompt = ""
	_last_player_message = ""
	_last_raw_response = ""
	_last_response = ""
	_last_validation.clear()
