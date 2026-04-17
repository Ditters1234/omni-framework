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
		var previous_template_id := "" if previous_entity == null else previous_entity.get_equipped_template_id(slot_id)
		var committed_template_id := committed_entity.get_equipped_template_id(slot_id)
		if previous_template_id == committed_template_id:
			continue
		if not previous_template_id.is_empty():
			GameEvents.part_unequipped.emit(entity_id, previous_template_id, slot_id)
		if not committed_template_id.is_empty():
			GameEvents.part_equipped.emit(entity_id, committed_template_id, slot_id)


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
