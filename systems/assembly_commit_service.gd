## AssemblyCommitService -- Applies finalized assembly edits to runtime state.
## Emits equip/unequip events based on the committed entity diff so assembly
## backends do not need to hand-roll runtime change application.
extends RefCounted

class_name AssemblyCommitService


static func commit_entity(previous_entity: EntityInstance, committed_entity: EntityInstance, lookup_id: String = "") -> void:
	if committed_entity == null:
		return
	GameState.commit_entity_instance(committed_entity, lookup_id)
	var entity_id := committed_entity.entity_id
	var slot_ids: Array[String] = _collect_slot_ids(previous_entity, committed_entity)
	for slot_id in slot_ids:
		var previous_part := null if previous_entity == null else previous_entity.get_equipped(slot_id)
		var committed_part := committed_entity.get_equipped(slot_id)
		var previous_template_id := "" if previous_part == null else previous_part.template_id
		var committed_template_id := "" if committed_part == null else committed_part.template_id
		var previous_instance_id := "" if previous_part == null else previous_part.instance_id
		var committed_instance_id := "" if committed_part == null else committed_part.instance_id
		if previous_template_id == committed_template_id and previous_instance_id == committed_instance_id:
			continue
		if not previous_template_id.is_empty():
			GameEvents.part_unequipped.emit(entity_id, previous_template_id, slot_id)
			_invoke_part_hook(previous_entity, slot_id, "on_unequip")
		if not committed_template_id.is_empty():
			GameEvents.part_equipped.emit(entity_id, committed_template_id, slot_id)
			_invoke_part_hook(committed_entity, slot_id, "on_equip")
			_play_equip_sound(committed_part)


static func _collect_slot_ids(previous_entity: EntityInstance, committed_entity: EntityInstance) -> Array[String]:
	var slot_ids: Array[String] = []
	if previous_entity != null:
		for slot_value in previous_entity.equipped.keys():
			var slot_id := str(slot_value)
			if not slot_id in slot_ids:
				slot_ids.append(slot_id)
	if committed_entity != null:
		for slot_value in committed_entity.equipped.keys():
			var slot_id := str(slot_value)
			if not slot_id in slot_ids:
				slot_ids.append(slot_id)
	slot_ids.sort()
	return slot_ids


static func _invoke_part_hook(entity: EntityInstance, slot_id: String, method_name: String) -> void:
	if entity == null:
		return
	var part := entity.get_equipped(slot_id)
	if part == null and method_name == "on_unequip":
		var previous_part_data: Variant = entity.equipped.get(slot_id, null)
		part = previous_part_data as PartInstance
	if part == null:
		return
	var part_template := part.get_template()
	if part_template.is_empty():
		return
	ScriptHookService.invoke_template_hook(part_template, method_name, [entity.to_dict(), part.to_dict()])


static func _play_equip_sound(part: PartInstance) -> void:
	if part == null or AudioManager == null:
		return
	var part_template := part.get_template()
	if part_template.is_empty():
		return
	var equip_sound := str(part_template.get("equip_sound", ""))
	if equip_sound.is_empty():
		return
	AudioManager.play_sfx(equip_sound)
