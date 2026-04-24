## ScriptHookService -- Shared runtime helper for invoking template hooks.
## Systems call this with template dictionaries so hook lookup stays centralized.
extends RefCounted

class_name ScriptHookService


static func invoke_template_hook(template: Dictionary, method_name: String, args: Array = []) -> void:
	if template.is_empty() or method_name.is_empty():
		return
	var script_path := _extract_script_path(template)
	if script_path.is_empty():
		return
	var hook := ModLoader.get_script_hook(script_path)
	if hook == null or not hook.has_method(method_name):
		return
	hook.callv(method_name, args)


static func invoke_part_tick_hooks(tick: int) -> void:
	var entity_ids: Array[String] = []
	for entity_id_value in GameState.entity_instances.keys():
		var entity_id := str(entity_id_value)
		if entity_id.is_empty():
			continue
		entity_ids.append(entity_id)
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity := GameState.get_entity_instance(entity_id)
		if entity == null:
			continue
		var carried_parts := _collect_carried_parts(entity)
		if carried_parts.is_empty():
			continue
		var entity_payload := entity.to_dict()
		for part in carried_parts:
			if part == null:
				continue
			var template := part.get_template()
			if template.is_empty():
				continue
			invoke_template_hook(template, "on_tick", [entity_payload.duplicate(true), part.to_dict(), tick])


static func _extract_script_path(template: Dictionary) -> String:
	return str(template.get("script_path", template.get("script_hook", "")))


static func _collect_carried_parts(entity: EntityInstance) -> Array[PartInstance]:
	var parts: Array[PartInstance] = []
	var seen_instance_ids: Dictionary = {}
	if entity == null:
		return parts
	for part_value in entity.inventory:
		var inventory_part := part_value as PartInstance
		_append_unique_part(parts, seen_instance_ids, inventory_part)
	var slot_ids: Array = entity.equipped.keys()
	slot_ids.sort()
	for slot_id_value in slot_ids:
		var slot_id := str(slot_id_value)
		_append_unique_part(parts, seen_instance_ids, entity.get_equipped(slot_id))
	return parts


static func _append_unique_part(parts: Array[PartInstance], seen_instance_ids: Dictionary, part: PartInstance) -> void:
	if part == null:
		return
	var instance_id := part.instance_id
	if not instance_id.is_empty() and seen_instance_ids.has(instance_id):
		return
	if not instance_id.is_empty():
		seen_instance_ids[instance_id] = true
	parts.append(part)
