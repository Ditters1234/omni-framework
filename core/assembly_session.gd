## AssemblySession -- Draft assembly/economy wrapper for creator and workbench UIs.
## Holds a cloned entity, tracks build budget, and exposes projected stats.
extends RefCounted

class_name AssemblySession

var original_entity: EntityInstance = null
var draft_entity: EntityInstance = null
var budget_currency_id: String = ""
var starting_budget: float = 0.0
## Optional payer entity. When set, the budget is drawn from this entity
## instead of the target (e.g. a shipyard where the player pays but the
## ship receives the new parts). Set via initialize_from_entity's payer param.
var payer_entity: EntityInstance = null


## Initialises the session from source_entity.
## If payer is provided, the budget is read from payer's currency instead of
## source_entity's — useful for entity-to-entity scenarios (ripperdoc, shipyard).
func initialize_from_entity(source_entity: EntityInstance, preferred_currency_id: String = "credits", payer: EntityInstance = null) -> void:
	original_entity = _clone_entity(source_entity)
	draft_entity = _clone_entity(source_entity)
	var budget_source := payer if payer != null else source_entity
	budget_currency_id = _resolve_currency_id(budget_source, preferred_currency_id)
	starting_budget = 0.0 if budget_currency_id.is_empty() else budget_source.get_currency(budget_currency_id)
	payer_entity = _clone_entity(payer) if payer != null else null


func get_available_socket_definitions() -> Array[Dictionary]:
	if draft_entity == null:
		return []
	return draft_entity.get_available_socket_definitions()


func get_equipped_template_id(slot: String) -> String:
	if draft_entity == null:
		return ""
	return draft_entity.get_equipped_template_id(slot)


func get_budget_currency_id() -> String:
	return budget_currency_id


func can_equip_template_in_slot(slot: String, template_id: String) -> bool:
	if draft_entity == null:
		return false
	return draft_entity.can_equip_template_in_slot(slot, template_id)


func can_afford_template(slot: String, template_id: String) -> bool:
	if template_id.is_empty():
		return true
	var candidate := get_preview_entity(slot, template_id)
	if candidate == null:
		return false
	return _compute_total_cost(candidate) <= starting_budget


func apply_template(slot: String, template_id: String) -> bool:
	var candidate := get_preview_entity(slot, template_id)
	if candidate == null:
		return false
	if _compute_total_cost(candidate) > starting_budget:
		return false
	draft_entity = candidate
	return true


func clear_slot(slot: String) -> bool:
	var candidate := get_preview_entity(slot, "")
	if candidate == null:
		return false
	draft_entity = candidate
	return true


func get_total_cost() -> float:
	return _compute_total_cost(draft_entity)


func get_remaining_budget() -> float:
	return starting_budget - get_total_cost()


func get_current_effective_stats() -> Dictionary:
	if original_entity == null:
		return {}
	return StatManager.compute_effective_stats(original_entity)


func get_projected_effective_stats() -> Dictionary:
	if draft_entity == null:
		return {}
	return StatManager.compute_effective_stats(draft_entity)


func get_preview_entity(slot: String, template_id: String) -> EntityInstance:
	if draft_entity == null:
		return null
	var candidate := _clone_entity(draft_entity)
	if candidate == null:
		return null
	if template_id.is_empty():
		candidate.unequip(slot)
		return candidate
	if not candidate.set_equipped_template(slot, template_id):
		return null
	return candidate


func get_preview_effective_stats(slot: String, template_id: String) -> Dictionary:
	var candidate := get_preview_entity(slot, template_id)
	if candidate == null:
		return get_projected_effective_stats()
	return StatManager.compute_effective_stats(candidate)


func get_preview_total_cost(slot: String, template_id: String) -> float:
	var candidate := get_preview_entity(slot, template_id)
	if candidate == null:
		return get_total_cost()
	return _compute_total_cost(candidate)


func get_remaining_budget_after_preview(slot: String, template_id: String) -> float:
	return starting_budget - get_preview_total_cost(slot, template_id)


## Returns the finalized target entity. Currency is deducted here only when
## there is no separate payer — if payer_entity is set, use get_committed_payer()
## to get the payer with adjusted currency.
func get_committed_entity() -> EntityInstance:
	var committed := _clone_entity(draft_entity)
	if committed == null:
		return null
	if payer_entity == null and not budget_currency_id.is_empty():
		committed.currencies[budget_currency_id] = maxf(get_remaining_budget(), 0.0)
	return committed


## Returns the payer entity with the build cost deducted, or null if there is
## no separate payer (i.e. the target entity pays for itself).
func get_committed_payer() -> EntityInstance:
	if payer_entity == null:
		return null
	var committed := _clone_entity(payer_entity)
	if committed == null:
		return null
	if not budget_currency_id.is_empty():
		committed.currencies[budget_currency_id] = maxf(get_remaining_budget(), 0.0)
	return committed


func get_template_price(template: Dictionary) -> float:
	if budget_currency_id.is_empty():
		return 0.0
	var price_data: Variant = template.get("price", {})
	if not price_data is Dictionary:
		return 0.0
	var price: Dictionary = price_data
	return float(price.get(budget_currency_id, 0.0))


func _compute_total_cost(entity: EntityInstance) -> float:
	if entity == null or budget_currency_id.is_empty():
		return 0.0
	var total := 0.0
	for slot_value in entity.equipped.keys():
		var slot := str(slot_value)
		var part := entity.get_equipped(slot)
		if part == null:
			continue
		total += get_template_price(part.get_template())
	return total


func _clone_entity(source_entity: EntityInstance) -> EntityInstance:
	if source_entity == null:
		return null
	var clone := EntityInstance.new()
	clone.from_dict(source_entity.to_dict())
	return clone


func _resolve_currency_id(source_entity: EntityInstance, preferred_currency_id: String) -> String:
	if source_entity == null:
		return ""
	if not preferred_currency_id.is_empty() and source_entity.currencies.has(preferred_currency_id):
		return preferred_currency_id
	var currency_keys: Array = source_entity.currencies.keys()
	if currency_keys.is_empty():
		return ""
	currency_keys.sort()
	return str(currency_keys[0])
