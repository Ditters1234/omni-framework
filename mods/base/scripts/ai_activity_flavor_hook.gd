extends ScriptHook

const TEMPLATE_ID := "base:activity_flavor"
const SYSTEM_PROMPT := "Write concise in-world activity flavor. Return exactly one short sentence."


func queue_activity_flavor_generation(activity_template: Dictionary, context: Dictionary = {}) -> void:
	var activity_id := str(activity_template.get("activity_id", "")).strip_edges()
	if activity_id.is_empty():
		return
	_generate_activity_flavor_async(activity_template.duplicate(true), context.duplicate(true))


func _generate_activity_flavor_async(activity_template: Dictionary, context: Dictionary) -> void:
	var activity_id := str(activity_template.get("activity_id", "")).strip_edges()
	if activity_id.is_empty():
		return
	var ai_template := DataManager.get_ai_template(TEMPLATE_ID)
	if ai_template.is_empty():
		ScriptHookService.store_activity_flavor(activity_id, "")
		return
	var tokens := _build_tokens(activity_template, context)
	var prompt := resolve_template_tokens(str(ai_template.get("prompt_template", "")), tokens)
	if prompt.is_empty():
		ScriptHookService.store_activity_flavor(activity_id, "")
		return
	var flavor_text := await generate_ai_async(prompt, {
		"system_prompt": SYSTEM_PROMPT,
	})
	var final_flavor_text := flavor_text.strip_edges()
	if final_flavor_text.is_empty():
		final_flavor_text = resolve_template_tokens(str(ai_template.get("fallback", "")), tokens).strip_edges()
	ScriptHookService.store_activity_flavor(activity_id, final_flavor_text)


func _build_tokens(activity_template: Dictionary, context: Dictionary) -> Dictionary:
	var activity_id := str(activity_template.get("activity_id", ""))
	var location_id := str(activity_template.get("location_id", context.get("current_location_id", ""))).strip_edges()
	if location_id.is_empty():
		location_id = str(GameState.current_location_id).strip_edges()
	var provider_entity_id := str(activity_template.get("provider_entity_id", context.get("provider_entity_id", ""))).strip_edges()
	return {
		"activity_id": activity_id,
		"display_name": str(activity_template.get("display_name", activity_id)),
		"description": str(activity_template.get("description", "")),
		"category": str(activity_template.get("category", "")),
		"kind": str(activity_template.get("kind", "standard")),
		"location_name": _resolve_location_name(location_id),
		"provider_name": _resolve_entity_name(provider_entity_id),
		"duration_ticks": str(activity_template.get("duration_ticks", 0)),
		"outcome_id": str(context.get("outcome_id", "")).strip_edges(),
	}


func _resolve_location_name(location_id: String) -> String:
	var normalized_location_id := location_id.strip_edges()
	if not normalized_location_id.is_empty() and DataManager.has_location(normalized_location_id):
		var location := DataManager.get_location(normalized_location_id)
		return str(location.get("display_name", normalized_location_id))
	if not GameState.current_location_id.is_empty() and DataManager.has_location(GameState.current_location_id):
		var current_location := DataManager.get_location(GameState.current_location_id)
		return str(current_location.get("display_name", GameState.current_location_id))
	return "the area"


func _resolve_entity_name(entity_id: String) -> String:
	var normalized_entity_id := entity_id.strip_edges()
	if normalized_entity_id.is_empty():
		return "local contacts"
	if DataManager.has_entity(normalized_entity_id):
		var entity := DataManager.get_entity(normalized_entity_id)
		return str(entity.get("display_name", normalized_entity_id))
	var runtime_entity := GameState.get_entity_instance(normalized_entity_id)
	if runtime_entity != null:
		var runtime_template := DataManager.get_entity(runtime_entity.template_id)
		return str(runtime_template.get("display_name", normalized_entity_id))
	return normalized_entity_id
