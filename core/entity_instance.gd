## EntityInstance — Runtime instance of an entity template.
## Holds live stats, inventory, equipped parts, and faction standing.
## Used for the player and all NPCs/vendors in the game world.
## Serialized with A2J (not plain JSON).
extends RefCounted

class_name EntityInstance

## Namespaced template id, e.g. "base:blacksmith"
var template_id: String = ""

## Unique runtime id.
var entity_id: String = ""

## Current stat values: { stat_key → float }
## Stats always come in pairs: "health" + "health_max".
var stats: Dictionary = {}

## Entity-owned currencies: { currency_key → float }
var currencies: Dictionary = {}

## Per-faction standing: { faction_id → float }
var reputation: Dictionary = {}

## Inventory: Array of PartInstance
var inventory: Array = []   # Array[PartInstance]

## Equipped parts: { slot_key → PartInstance }
var equipped: Dictionary = {}

## Arbitrary instance flags: { flag_key → Variant }
var flags: Dictionary = {}

## Locations this entity has discovered for travel/navigation purposes.
var discovered_locations: Array[String] = []

## Current location id.
var location_id: String = ""

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Creates a new EntityInstance from a template dictionary.
static func from_template(template: Dictionary) -> EntityInstance:
	var inst := EntityInstance.new()
	inst.template_id = template.get("entity_id", "")
	inst.entity_id = template.get("entity_id", _generate_id())
	inst.location_id = template.get("location_id", "")
	inst.currencies = template.get("currencies", {}).duplicate(true)
	inst.reputation = template.get("reputation", {}).duplicate(true)
	inst.flags = template.get("flags", {}).duplicate(true)
	inst.discovered_locations = inst._to_string_array(template.get("discovered_locations", []))
	inst._init_stats(template)
	inst._init_inventory(template)
	inst._init_equipped_from_template(template)
	return inst


static func _generate_id() -> String:
	return str(randi())


func get_template() -> Dictionary:
	return DataManager.get_entity(template_id)


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

## Initializes stats dict from the template's documented `stats` block,
## falling back to older field names during the transition.
func _init_stats(template: Dictionary) -> void:
	stats.clear()
	var stat_definitions: Array = DataManager.get_definitions("stats")
	for stat_def in stat_definitions:
		if stat_def is Dictionary:
			var stat_id := str(stat_def.get("id", ""))
			if stat_id.is_empty():
				continue
			var kind := str(stat_def.get("kind", "flat"))
			match kind:
				"flat":
					stats[stat_id] = float(stat_def.get("default_value", 0))
				"capacity":
					stats[stat_id] = float(stat_def.get("default_value", 0))
				"resource":
					var capacity_id := str(stat_def.get("paired_capacity_id", ""))
					if not capacity_id.is_empty() and not stats.has(capacity_id):
						stats[capacity_id] = float(stat_def.get("default_capacity_value", stat_def.get("default_value", 0)))
					stats[stat_id] = float(stat_def.get("default_value", stats.get(capacity_id, 0.0)))
		else:
			stats[str(stat_def)] = 0.0

	var template_stats: Dictionary = template.get("stats", template.get("base_stats", {}))
	for key in template_stats.keys():
		stats[key] = float(template_stats[key])
	StatManager.clamp_all_to_capacity(self)


## Returns a stat value, or 0.0 if not present.
func get_stat(stat_key: String) -> float:
	return float(stats.get(stat_key, 0.0))


## Sets a stat value and clamps base stats to their capacity.
func set_stat(stat_key: String, value: float) -> void:
	var old_value := get_stat(stat_key)
	if StatManager.is_capacity_stat(stat_key):
		stats[stat_key] = maxf(value, OmniConstants.STAT_MIN)
		var base_key := stat_key.trim_suffix(OmniConstants.CAPACITY_SUFFIX)
		if stats.has(base_key):
			stats[base_key] = clamp(stats[base_key], OmniConstants.STAT_MIN, stats[stat_key])
	else:
		var capacity_key := stat_key + OmniConstants.CAPACITY_SUFFIX
		if stats.has(capacity_key):
			stats[stat_key] = clamp(value, OmniConstants.STAT_MIN, get_stat(capacity_key))
		else:
			stats[stat_key] = maxf(value, OmniConstants.STAT_MIN)
	if GameEvents:
		GameEvents.entity_stat_changed.emit(entity_id, stat_key, old_value, stats[stat_key])
		if GameState.player == self:
			GameEvents.player_stat_changed.emit(stat_key, old_value, stats[stat_key])


## Modifies a stat by delta (positive or negative).
func modify_stat(stat_key: String, delta: float) -> void:
	set_stat(stat_key, get_stat(stat_key) + delta)


## Returns true if the entity has the stat key.
func has_stat(stat_key: String) -> bool:
	return stats.has(stat_key)


func effective_stat(stat_key: String) -> float:
	var effective_stats := StatManager.compute_effective_stats(self)
	return float(effective_stats.get(stat_key, 0.0))


func get_currency(currency_key: String) -> float:
	return float(currencies.get(currency_key, 0.0))


func add_currency(currency_key: String, amount: float) -> void:
	var old_amount := get_currency(currency_key)
	currencies[currency_key] = old_amount + amount
	if GameEvents:
		GameEvents.entity_currency_changed.emit(entity_id, currency_key, old_amount, get_currency(currency_key))
		if GameState.player == self:
			GameEvents.currency_changed.emit(currency_key, old_amount, get_currency(currency_key))


func spend_currency(currency_key: String, amount: float) -> bool:
	if get_currency(currency_key) < amount:
		return false
	add_currency(currency_key, -amount)
	return true


func get_reputation(faction_id: String) -> float:
	return float(reputation.get(faction_id, 0.0))


func add_reputation(faction_id: String, amount: float) -> void:
	reputation[faction_id] = get_reputation(faction_id) + amount


func set_flag(flag_key: String, value: Variant) -> void:
	flags[flag_key] = value
	if GameEvents:
		GameEvents.flag_changed.emit(entity_id, flag_key, value)


func get_flag(flag_key: String, default_value: Variant = null) -> Variant:
	return flags.get(flag_key, default_value)


func has_flag(flag_key: String) -> bool:
	return flags.has(flag_key)


func discover_location(discovered_location_id: String) -> void:
	if discovered_location_id.is_empty() or discovered_location_id in discovered_locations:
		return
	discovered_locations.append(discovered_location_id)


func has_discovered_location(discovered_location_id: String) -> bool:
	return discovered_location_id in discovered_locations


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

## Adds a PartInstance to inventory.
func add_part(part: PartInstance) -> void:
	inventory.append(part)


## Removes a PartInstance from inventory by instance_id. Returns true if found.
func remove_part(instance_id: String) -> bool:
	for i in inventory.size():
		if inventory[i].instance_id == instance_id:
			inventory.remove_at(i)
			return true
	return false


## Returns a PartInstance from inventory by instance_id, or null.
func get_inventory_part(instance_id: String) -> PartInstance:
	return _find_inventory_part(instance_id)


# ---------------------------------------------------------------------------
# Assembly — socket queries
# ---------------------------------------------------------------------------

## Returns all socket definitions available on this entity:
## sockets from the entity template plus sockets exposed by each equipped part.
## Part-provided sockets use "{slot}" in their id, which is resolved to the
## actual equipped slot key before being returned.
func get_available_socket_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var template := get_template()
	var entity_sockets: Array = template.get("provides_sockets", [])
	for socket_def_value in entity_sockets:
		if socket_def_value is Dictionary:
			result.append(socket_def_value.duplicate(true))
	for slot_value in equipped.keys():
		var slot := str(slot_value)
		var part: PartInstance = equipped.get(slot, null)
		if part == null:
			continue
		var part_template := part.get_template()
		var part_sockets: Array = part_template.get("provides_sockets", [])
		for socket_def_value in part_sockets:
			if not socket_def_value is Dictionary:
				continue
			var socket_def: Dictionary = socket_def_value.duplicate(true)
			var raw_id := str(socket_def.get("id", ""))
			socket_def["id"] = raw_id.replace("{slot}", slot)
			result.append(socket_def)
	return result


## Returns the template_id of the part currently equipped in slot, or "".
func get_equipped_template_id(slot: String) -> String:
	var part: PartInstance = equipped.get(slot, null)
	if part == null:
		return ""
	return part.template_id


## Returns the PartInstance currently in slot, or null.
func get_equipped(slot: String) -> PartInstance:
	return equipped.get(slot, null) as PartInstance


# ---------------------------------------------------------------------------
# Assembly — equip / unequip
# ---------------------------------------------------------------------------

## Equips a new PartInstance built from part_template_id into slot.
## Returns false if the template is not found in DataManager.
func set_equipped_template(slot: String, part_template_id: String) -> bool:
	if part_template_id.is_empty():
		return false
	var template: Variant = DataManager.get_part(part_template_id)
	if not template is Dictionary:
		return false
	var tmpl: Dictionary = template
	if tmpl.is_empty():
		return false
	var part := PartInstance.new()
	part.template_id = part_template_id
	part.instance_id = PartInstance._generate_id()
	part.equipped_slot = slot
	part.is_equipped = true
	equipped[slot] = part
	return true


## Equips an existing inventory part into the given slot.
## Returns false if the part is missing or cannot fit the socket.
func equip(instance_id: String, slot: String) -> bool:
	if instance_id.is_empty() or slot.is_empty():
		return false
	var part := _find_inventory_part(instance_id)
	if part == null:
		return false
	if not can_equip_template_in_slot(slot, part.template_id):
		return false
	if equipped.has(slot):
		unequip(slot)
	if not remove_part(instance_id):
		return false
	part.equipped_slot = slot
	part.is_equipped = true
	equipped[slot] = part
	return true


## Removes the part from slot and returns it to inventory.
func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	var part: PartInstance = equipped.get(slot, null)
	if part != null:
		part.equipped_slot = ""
		part.is_equipped = false
		if not _has_inventory_part(part.instance_id):
			inventory.append(part)
	equipped.erase(slot)


## Returns true if part_template_id's tags satisfy the slot's accepted_tags.
func can_equip_template_in_slot(slot: String, part_template_id: String) -> bool:
	if part_template_id.is_empty():
		return false
	var socket_def := _find_socket_def(slot)
	if socket_def.is_empty():
		return false
	var accepted_tags_data: Variant = socket_def.get("accepted_tags", [])
	if not accepted_tags_data is Array:
		return true
	var accepted_tags: Array = accepted_tags_data
	if accepted_tags.is_empty():
		return true
	var template: Variant = DataManager.get_part(part_template_id)
	if not template is Dictionary:
		return false
	var tmpl: Dictionary = template
	if tmpl.is_empty():
		return false
	var part_tags_data: Variant = tmpl.get("tags", [])
	if not part_tags_data is Array:
		return false
	var part_tags: Array = part_tags_data
	for tag in accepted_tags:
		if part_tags.has(tag):
			return true
	return false


# ---------------------------------------------------------------------------
# Assembly — private helpers
# ---------------------------------------------------------------------------

func _init_inventory(template: Dictionary) -> void:
	inventory.clear()
	var inv_data: Array = template.get("inventory", [])
	for entry in inv_data:
		if not entry is Dictionary:
			continue
		var tmpl_id := str(entry.get("template_id", ""))
		if tmpl_id.is_empty():
			continue
		var part := PartInstance.new()
		part.template_id = tmpl_id
		part.instance_id = str(entry.get("instance_id", PartInstance._generate_id()))
		inventory.append(part)


func _init_equipped_from_template(template: Dictionary) -> void:
	equipped.clear()
	var socket_map: Dictionary = template.get("assembly_socket_map", {})
	for slot_value in socket_map.keys():
		var slot := str(slot_value)
		var instance_id := str(socket_map[slot_value])
		var part := _find_inventory_part(instance_id)
		if part != null:
			part.equipped_slot = slot
			part.is_equipped = true
			equipped[slot] = part


func _find_inventory_part(instance_id: String) -> PartInstance:
	for part in inventory:
		if part is PartInstance and part.instance_id == instance_id:
			return part
	return null


func _has_inventory_part(instance_id: String) -> bool:
	return _find_inventory_part(instance_id) != null


func _find_socket_def(slot: String) -> Dictionary:
	for socket_def in get_available_socket_definitions():
		if socket_def.get("id", "") == slot:
			return socket_def
	return {}


func duplicate_instance() -> EntityInstance:
	var clone := EntityInstance.new()
	clone.from_dict(to_dict())
	return clone


# ---------------------------------------------------------------------------
# Serialization (manual dict round-trip for AssemblySession cloning)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var inventory_list: Array = []
	for part in inventory:
		if part is PartInstance:
			inventory_list.append(part.to_dict())
	var equipped_map: Dictionary = {}
	for slot_value in equipped.keys():
		var slot := str(slot_value)
		var part: PartInstance = equipped.get(slot, null)
		if part != null:
			equipped_map[slot] = part.to_dict()
	return {
		"template_id": template_id,
		"entity_id": entity_id,
		"stats": stats.duplicate(),
		"currencies": currencies.duplicate(),
		"reputation": reputation.duplicate(),
		"inventory": inventory_list,
		"equipped": equipped_map,
		"flags": flags.duplicate(),
		"discovered_locations": discovered_locations.duplicate(),
		"location_id": location_id,
	}


func from_dict(data: Dictionary) -> void:
	template_id = data.get("template_id", "")
	entity_id = data.get("entity_id", "")
	stats = data.get("stats", {}).duplicate(true)
	currencies = data.get("currencies", {}).duplicate(true)
	reputation = data.get("reputation", {}).duplicate(true)
	flags = data.get("flags", {}).duplicate(true)
	discovered_locations = _to_string_array(data.get("discovered_locations", []))
	location_id = data.get("location_id", "")
	inventory.clear()
	var inv_data: Array = data.get("inventory", [])
	for entry in inv_data:
		if not entry is Dictionary:
			continue
		var part := PartInstance.new()
		part.from_dict(entry)
		inventory.append(part)
	equipped.clear()
	var eq_data: Variant = data.get("equipped", {})
	if eq_data is Dictionary:
		for slot_value in eq_data.keys():
			var slot := str(slot_value)
			var part_data: Variant = eq_data[slot_value]
			if not part_data is Dictionary:
				continue
			var part := PartInstance.new()
			part.from_dict(part_data)
			equipped[slot] = part


func _to_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(str(value))
	return result
