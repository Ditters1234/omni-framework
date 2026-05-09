extends RefCounted

class_name LocationPresenceService

const TASK_ACTIVITY_SUMMARY := preload("res://systems/task_activity_summary.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")


static func collect(location_id: String, location_template: Dictionary) -> Array[Dictionary]:
	var collected_entities: Array[Dictionary] = []
	var entity_ids := get_present_entity_ids(location_id, location_template)
	for entity_id in entity_ids:
		var entity_template := get_entity_template_for_presence(entity_id)
		if entity_template.is_empty():
			continue
		var display_name := str(entity_template.get("display_name", entity_id))
		var description := str(entity_template.get("description", ""))
		var interactions := read_entity_interactions(entity_template)
		var activity := TASK_ACTIVITY_SUMMARY.build_for_entity(entity_id)
		collected_entities.append({
			"entity_id": entity_id,
			"display_name": display_name,
			"description": description,
			"interactions": interactions,
			"activity": activity,
			"activity_text": str(activity.get("active_task_text", "Idle")),
			"activity_detail_text": str(activity.get("detail_text", "Idle")),
			"queued_task_count": int(activity.get("queued_task_count", 0)),
		})
	return collected_entities


static func get_present_entity_ids(location_id: String, location_template: Dictionary) -> Array[String]:
	var entity_ids: Array[String] = []
	var listed_entities_value: Variant = location_template.get("entities_present", [])
	if listed_entities_value is Array:
		var listed_entities: Array = listed_entities_value
		for entity_id_value in listed_entities:
			append_present_entity_id(entity_ids, str(entity_id_value))

	var located_entities := DataManager.query_entities({"location_id": location_id})
	for entity_template in located_entities:
		append_present_entity_id(entity_ids, str(entity_template.get("entity_id", "")))

	for instance_id_value in GameState.entity_instances.keys():
		var instance_id := str(instance_id_value)
		var entity := GameState.get_entity_instance(instance_id)
		if entity == null or entity.location_id != location_id:
			continue
		append_present_entity_id(entity_ids, entity.entity_id)
	return entity_ids


static func is_backend_entry_available(entry: Dictionary, default_source_entity_id: String = "") -> bool:
	var backend_class := str(entry.get("backend_class", ""))
	match backend_class:
		"LootBackend":
			return is_loot_entry_available(entry, default_source_entity_id)
	return true


static func is_loot_entry_available(entry: Dictionary, default_source_entity_id: String) -> bool:
	if not bool(entry.get("hide_when_empty", true)):
		return true
	var source_id := str(entry.get("source_entity_id", default_source_entity_id)).strip_edges()
	if source_id.begins_with("entity:"):
		source_id = source_id.trim_prefix("entity:")
	if source_id.is_empty():
		return true
	var source := GameState.get_entity_instance(source_id)
	if source == null:
		return true
	if entity_has_loose_inventory(source):
		return true
	if not bool(entry.get("include_currencies", true)):
		return false
	return entity_has_positive_currency(source)


static func append_present_entity_id(entity_ids: Array[String], entity_id: String) -> void:
	if entity_id.is_empty() or is_player_entity_id(entity_id) or entity_ids.has(entity_id):
		return
	entity_ids.append(entity_id)


static func is_player_entity_id(entity_id: String) -> bool:
	if entity_id == "player":
		return true
	var player := GameState.player as EntityInstance
	if player == null:
		return false
	return entity_id == player.entity_id


static func get_entity_template_for_presence(entity_id: String) -> Dictionary:
	var runtime_entity := GameState.get_entity_instance(entity_id)
	if runtime_entity != null:
		var runtime_template := runtime_entity.get_template()
		if not runtime_template.is_empty():
			return runtime_template
	return DataManager.get_entity(entity_id)


static func read_entity_interactions(entity_template: Dictionary) -> Array[Dictionary]:
	var interactions: Array[Dictionary] = []
	var interactions_value: Variant = entity_template.get("interactions", [])
	if not interactions_value is Array:
		return interactions
	var raw_interactions: Array = interactions_value
	for interaction_value in raw_interactions:
		if interaction_value is Dictionary:
			var interaction: Dictionary = interaction_value
			interactions.append(interaction.duplicate(true))
	return interactions


static func entity_has_loose_inventory(entity: EntityInstance) -> bool:
	for part_value in entity.inventory:
		var part := part_value as PartInstance
		if part != null and not part.is_equipped:
			return true
	return false


static func entity_has_positive_currency(entity: EntityInstance) -> bool:
	for currency_id_value in entity.currencies.keys():
		var currency_id := str(currency_id_value)
		if entity.get_currency(currency_id) > 0.0:
			return true
	return false
