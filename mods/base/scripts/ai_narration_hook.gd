extends ScriptHook

const TEMPLATE_BY_SIGNAL := {
	"quest_completed": "base:event_narration_quest_completed",
	"location_changed": "base:event_narration_location_changed",
	"day_advanced": "base:event_narration_day_advanced",
}
const SYSTEM_PROMPT := "Write concise in-world event narration. Return exactly one short sentence."


func queue_event_narration_generation(signal_name: String, args: Array = []) -> void:
	if not TEMPLATE_BY_SIGNAL.has(signal_name):
		return
	_generate_event_narration_async(signal_name, args.duplicate(true))


func _generate_event_narration_async(signal_name: String, args: Array) -> void:
	var template_id := str(TEMPLATE_BY_SIGNAL.get(signal_name, "")).strip_edges()
	if template_id.is_empty():
		return
	var ai_template := DataManager.get_ai_template(template_id)
	if ai_template.is_empty():
		return
	var source_key := _resolve_source_key(signal_name, args)
	if source_key.is_empty():
		return
	var prompt := resolve_template_tokens(str(ai_template.get("prompt_template", "")), _build_tokens(signal_name, args))
	if prompt.is_empty():
		return
	var narration := await generate_ai_async(prompt, {
		"system_prompt": SYSTEM_PROMPT,
	})
	var final_narration := narration.strip_edges()
	if final_narration.is_empty():
		final_narration = resolve_template_tokens(str(ai_template.get("fallback", "")), _build_tokens(signal_name, args)).strip_edges()
	if final_narration.is_empty():
		return
	GameEvents.add_event_narration(signal_name, source_key, final_narration)
	GameEvents.emit_dynamic("event_narrated", [signal_name, source_key, final_narration])


func _build_tokens(signal_name: String, args: Array) -> Dictionary:
	match signal_name:
		"quest_completed":
			var quest_id := _read_arg(args, 0)
			var quest := DataManager.get_quest(quest_id)
			return {
				"quest_id": quest_id,
				"quest_name": str(quest.get("display_name", quest_id)),
			}
		"location_changed":
			var old_location_id := _read_arg(args, 0)
			var new_location_id := _read_arg(args, 1)
			return {
				"old_location_id": old_location_id,
				"old_location_name": _get_location_name(old_location_id),
				"new_location_id": new_location_id,
				"new_location_name": _get_location_name(new_location_id),
			}
		"day_advanced":
			var day := _read_arg(args, 0)
			var current_location_id := str(GameState.current_location_id)
			return {
				"day": day,
				"location_id": current_location_id,
				"location_name": _get_location_name(current_location_id),
			}
		_:
			return {}


func _resolve_source_key(signal_name: String, args: Array) -> String:
	match signal_name:
		"location_changed":
			return _read_arg(args, 1)
		_:
			return _read_arg(args, 0)


func _get_location_name(location_id: String) -> String:
	var location := DataManager.get_location(location_id)
	return str(location.get("display_name", location_id))


func _read_arg(args: Array, index: int) -> String:
	if index < 0 or index >= args.size():
		return ""
	return str(args[index]).strip_edges()
