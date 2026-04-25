extends ScriptHook

const ENTITY_TEMPLATE_ID := "base:entity_lore"
const PART_TEMPLATE_ID := "base:part_lore"
const SYSTEM_PROMPT := "Write concise in-world lore. Return exactly two short sentences."


func queue_entity_lore_generation(entity_template: Dictionary, context: Dictionary = {}) -> void:
	var template_id := str(entity_template.get("entity_id", "")).strip_edges()
	if template_id.is_empty():
		return
	_generate_entity_lore_async(entity_template.duplicate(true), context.duplicate(true))


func queue_part_lore_generation(part_template: Dictionary, context: Dictionary = {}) -> void:
	var template_id := str(part_template.get("id", "")).strip_edges()
	if template_id.is_empty():
		return
	_generate_part_lore_async(part_template.duplicate(true), context.duplicate(true))


func _generate_entity_lore_async(entity_template: Dictionary, context: Dictionary) -> void:
	var template_id := str(entity_template.get("entity_id", "")).strip_edges()
	if template_id.is_empty():
		return
	var ai_template := DataManager.get_ai_template(ENTITY_TEMPLATE_ID)
	if ai_template.is_empty():
		ScriptHookService.store_entity_lore(template_id, "")
		return
	var tokens := _build_entity_tokens(entity_template, context)
	var prompt := _resolve_tokens(str(ai_template.get("prompt_template", "")), tokens)
	if prompt.is_empty():
		ScriptHookService.store_entity_lore(template_id, "")
		return
	var lore_text := await generate_ai_async(prompt, {
		"system_prompt": SYSTEM_PROMPT,
	})
	var final_lore_text := lore_text.strip_edges()
	if final_lore_text.is_empty():
		final_lore_text = _resolve_tokens(str(ai_template.get("fallback", "")), tokens).strip_edges()
	ScriptHookService.store_entity_lore(template_id, final_lore_text)


func _generate_part_lore_async(part_template: Dictionary, context: Dictionary) -> void:
	var template_id := str(part_template.get("id", "")).strip_edges()
	if template_id.is_empty():
		return
	var ai_template := DataManager.get_ai_template(PART_TEMPLATE_ID)
	if ai_template.is_empty():
		ScriptHookService.store_part_lore(template_id, "")
		return
	var tokens := _build_part_tokens(part_template, context)
	var prompt := _resolve_tokens(str(ai_template.get("prompt_template", "")), tokens)
	if prompt.is_empty():
		ScriptHookService.store_part_lore(template_id, "")
		return
	var lore_text := await generate_ai_async(prompt, {
		"system_prompt": SYSTEM_PROMPT,
	})
	var final_lore_text := lore_text.strip_edges()
	if final_lore_text.is_empty():
		final_lore_text = _resolve_tokens(str(ai_template.get("fallback", "")), tokens).strip_edges()
	ScriptHookService.store_part_lore(template_id, final_lore_text)


func _build_entity_tokens(entity_template: Dictionary, context: Dictionary) -> Dictionary:
	var entity_id := str(entity_template.get("entity_id", ""))
	var location_id := str(entity_template.get("location_id", ""))
	var location_name := "the city"
	if not location_id.is_empty() and DataManager.has_location(location_id):
		var location := DataManager.get_location(location_id)
		location_name = str(location.get("display_name", location_id))
	var faction_name := str(context.get("faction_name", ""))
	return {
		"entity_id": entity_id,
		"display_name": str(entity_template.get("display_name", entity_id)),
		"description": str(entity_template.get("description", "")),
		"location_name": location_name,
		"faction_name": faction_name,
	}


func _build_part_tokens(part_template: Dictionary, _context: Dictionary) -> Dictionary:
	var template_id := str(part_template.get("id", ""))
	var tags_value: Variant = part_template.get("tags", [])
	var tags: Array[String] = []
	if tags_value is Array:
		var raw_tags: Array = tags_value
		for tag_value in raw_tags:
			var tag_text := str(tag_value).strip_edges()
			if tag_text.is_empty():
				continue
			tags.append(tag_text)
	return {
		"template_id": template_id,
		"display_name": str(part_template.get("display_name", template_id)),
		"description": str(part_template.get("description", "")),
		"tag_summary": ", ".join(tags),
	}


func _resolve_tokens(template_text: String, tokens: Dictionary) -> String:
	var resolved_text := template_text
	for token_key_value in tokens.keys():
		var token_key := str(token_key_value)
		resolved_text = resolved_text.replace("{%s}" % token_key, str(tokens.get(token_key_value, "")))
	return resolved_text.strip_edges()
