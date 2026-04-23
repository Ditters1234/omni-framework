## TransactionService -- Shared runtime helper for currency and inventory transfers.
## Keeps cross-entity economy side effects out of UI backends and draft sessions.
extends RefCounted

class_name TransactionService


static func transfer_currency(
	buyer: EntityInstance,
	seller: EntityInstance,
	currency_id: String,
	amount: float,
	part_id: String = "",
	emit_event: bool = true
) -> bool:
	if buyer == null or seller == null:
		return false
	if currency_id.is_empty() or amount <= 0.0:
		return true
	if buyer.entity_id == seller.entity_id:
		return true
	if not buyer.spend_currency(currency_id, amount):
		return false
	seller.add_currency(currency_id, amount)
	if emit_event and GameEvents:
		GameEvents.transaction_completed.emit(buyer.entity_id, seller.entity_id, part_id, amount)
	return true


static func spend_currency(entity: EntityInstance, currency_id: String, amount: float) -> bool:
	if entity == null:
		return false
	if currency_id.is_empty() or amount <= 0.0:
		return true
	return entity.spend_currency(currency_id, amount)


static func remove_one_inventory_template(entity: EntityInstance, template_id: String) -> bool:
	if entity == null or template_id.is_empty():
		return false
	for i in range(entity.inventory.size()):
		var part_data: Variant = entity.inventory[i]
		var part := part_data as PartInstance
		if part == null:
			continue
		if part.template_id != template_id or part.is_equipped:
			continue
		entity.inventory.remove_at(i)
		if GameEvents:
			GameEvents.part_removed.emit(entity.entity_id, template_id)
		return true
	return false


static func count_inventory_template(entity: EntityInstance, template_id: String, include_equipped: bool = false) -> int:
	if entity == null or template_id.is_empty():
		return 0
	var count := 0
	for part_data in entity.inventory:
		var part := part_data as PartInstance
		if part == null:
			continue
		if part.template_id != template_id:
			continue
		if part.is_equipped and not include_equipped:
			continue
		count += 1
	return count


static func remove_inventory_template_count(entity: EntityInstance, template_id: String, count: int) -> bool:
	if entity == null or template_id.is_empty() or count <= 0:
		return false
	if count_inventory_template(entity, template_id) < count:
		return false
	var removed := 0
	while removed < count:
		if not remove_one_inventory_template(entity, template_id):
			return false
		removed += 1
	return true


static func add_part_template_count(entity: EntityInstance, template_id: String, count: int) -> Array[PartInstance]:
	var added_parts: Array[PartInstance] = []
	if entity == null or template_id.is_empty() or count <= 0:
		return added_parts
	var template := DataManager.get_part(template_id)
	if template.is_empty():
		return added_parts
	for _i in range(count):
		var part := PartInstance.from_template(template)
		entity.add_part(part)
		added_parts.append(part)
		if GameEvents:
			GameEvents.part_acquired.emit(entity.entity_id, part.template_id)
	return added_parts
