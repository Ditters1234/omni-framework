extends ScriptHook

const TEMPLATE_ID := "base:task_flavor"
const SYSTEM_PROMPT := "Write concise in-world task flavor. Return exactly one short sentence."


func queue_task_flavor_generation(task_template: Dictionary, context: Dictionary = {}) -> void:
	var template_id := str(task_template.get("template_id", "")).strip_edges()
	if template_id.is_empty():
		return
	_generate_task_flavor_async(task_template.duplicate(true), context.duplicate(true))


func _generate_task_flavor_async(task_template: Dictionary, context: Dictionary) -> void:
	var template_id := str(task_template.get("template_id", "")).strip_edges()
	if template_id.is_empty():
		return
	var ai_template := DataManager.get_ai_template(TEMPLATE_ID)
	if ai_template.is_empty():
		ScriptHookService.store_task_flavor(template_id, "")
		return
	var tokens := _build_tokens(task_template, context)
	var prompt := resolve_template_tokens(str(ai_template.get("prompt_template", "")), tokens)
	if prompt.is_empty():
		ScriptHookService.store_task_flavor(template_id, "")
		return
	var flavor_text := await generate_ai_async(prompt, {
		"system_prompt": SYSTEM_PROMPT,
	})
	var final_flavor_text := flavor_text.strip_edges()
	if final_flavor_text.is_empty():
		final_flavor_text = resolve_template_tokens(str(ai_template.get("fallback", "")), tokens).strip_edges()
	ScriptHookService.store_task_flavor(template_id, final_flavor_text)


func _build_tokens(task_template: Dictionary, context: Dictionary) -> Dictionary:
	var template_id := str(task_template.get("template_id", ""))
	var display_name := str(task_template.get("display_name", task_template.get("title", template_id)))
	var faction_id := str(context.get("faction_id", ""))
	var faction := DataManager.get_faction(faction_id)
	var faction_name := str(faction.get("display_name", faction_id))
	var location_name := _resolve_location_name(task_template)
	return {
		"display_name": display_name,
		"task_type": str(task_template.get("type", "")),
		"location_name": location_name,
		"faction_name": faction_name,
		"reward_summary": _build_reward_summary(task_template.get("reward", {})),
	}


func _resolve_location_name(task_template: Dictionary) -> String:
	var target_id := str(task_template.get("target", "")).strip_edges()
	if not target_id.is_empty() and DataManager.has_location(target_id):
		var target_location := DataManager.get_location(target_id)
		return str(target_location.get("display_name", target_id))
	var current_location_id := str(GameState.current_location_id)
	if current_location_id.is_empty():
		return "the district"
	var current_location := DataManager.get_location(current_location_id)
	return str(current_location.get("display_name", current_location_id))


func _build_reward_summary(reward_value: Variant) -> String:
	if not reward_value is Dictionary:
		return "no listed reward"
	var reward: Dictionary = reward_value
	if reward.is_empty():
		return "no listed reward"
	var keys: Array = reward.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		parts.append("%s %s" % [str(reward.get(key_value, "")), str(key_value)])
	return ", ".join(parts)
