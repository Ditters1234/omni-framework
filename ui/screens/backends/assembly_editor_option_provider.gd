extends RefCounted

class_name OmniAssemblyEditorOptionProvider

var _session: AssemblySession = null
var _source_entity: EntityInstance = null
var _option_tags: Array[String] = []
var _option_template_ids: Array[String] = []


func initialize(
	session: AssemblySession,
	source_entity: EntityInstance,
	option_tags: Array[String],
	option_template_ids: Array[String]
) -> void:
	_session = session
	_source_entity = source_entity
	_option_tags = option_tags.duplicate()
	_option_template_ids = option_template_ids.duplicate()


func get_options_for_slot(slot_id: String) -> Array[Dictionary]:
	if _session == null:
		return []
	if _source_entity != null:
		return _get_inventory_options_for_slot(slot_id)
	return _get_catalog_options_for_slot(slot_id)


func get_inventory_template_counts() -> Dictionary:
	var counts: Dictionary = {}
	if _source_entity == null:
		return counts
	for inventory_part in _source_entity.inventory:
		var part: PartInstance = inventory_part as PartInstance
		if part == null or part.is_equipped:
			continue
		var template_id := part.template_id
		if template_id.is_empty():
			continue
		counts[template_id] = int(counts.get(template_id, 0)) + 1
	return counts


func _get_catalog_options_for_slot(slot_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_template_ids: Dictionary = {}
	for template_id in _option_template_ids:
		var template := _get_part_template(template_id)
		if template.is_empty():
			continue
		if not _session.can_equip_template_in_slot(slot_id, template_id):
			continue
		results.append(template)
		seen_template_ids[template_id] = true
	for tag in _option_tags:
		var parts_data: Variant = PartsRegistry.get_by_category(tag)
		if not parts_data is Array:
			continue
		var parts: Array = parts_data
		for part_data in parts:
			if not part_data is Dictionary:
				continue
			var part: Dictionary = part_data
			var template_id := str(part.get("id", ""))
			if template_id.is_empty() or seen_template_ids.has(template_id):
				continue
			if not _session.can_equip_template_in_slot(slot_id, template_id):
				continue
			results.append(part)
			seen_template_ids[template_id] = true
	results.sort_custom(_sort_options_by_display_name)
	return results


func _get_inventory_options_for_slot(slot_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if _source_entity == null:
		return results
	var counts := get_inventory_template_counts()
	for inventory_part in _source_entity.inventory:
		var part: PartInstance = inventory_part as PartInstance
		if part == null or part.is_equipped:
			continue
		var template_id := part.template_id
		if template_id.is_empty():
			continue
		if not _session.can_equip_template_in_slot(slot_id, template_id):
			continue
		if not _option_template_ids.is_empty() and not _option_template_ids.has(template_id):
			continue
		var template := _get_part_template(template_id)
		if template.is_empty():
			continue
		if not _matches_tag_filters(template):
			continue
		var option_template := template.duplicate(true)
		option_template["_part_instance_id"] = part.instance_id
		option_template["_source_kind"] = "inventory"
		option_template["_custom_values"] = part.custom_values.duplicate(true)
		option_template["_inventory_count"] = int(counts.get(template_id, 0))
		results.append(option_template)
	results.sort_custom(_sort_options_by_display_name)
	return results


func _matches_tag_filters(template: Dictionary) -> bool:
	if _option_tags.is_empty():
		return true
	var tags_data: Variant = template.get("tags", [])
	if not tags_data is Array:
		return false
	var tags: Array = tags_data
	for option_tag in _option_tags:
		if tags.has(option_tag):
			return true
	return false


func _sort_options_by_display_name(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("display_name", a.get("id", "")))
	var b_name := str(b.get("display_name", b.get("id", "")))
	var name_compare := a_name.naturalnocasecmp_to(b_name)
	if name_compare != 0:
		return name_compare < 0
	var a_instance_id := str(a.get("_part_instance_id", ""))
	var b_instance_id := str(b.get("_part_instance_id", ""))
	return a_instance_id.naturalnocasecmp_to(b_instance_id) < 0


func _get_part_template(template_id: String) -> Dictionary:
	if template_id.is_empty():
		return {}
	var template_data: Variant = DataManager.get_part(template_id)
	if template_data is Dictionary:
		var template: Dictionary = template_data
		return template
	return {}
