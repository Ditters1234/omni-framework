## PartInstance — Runtime instance of a part template.
## A template defines what a part *is*; an instance is a specific copy
## owned by an entity, which may have instance-level stat overrides or flags.
## Serialized with A2J (not plain JSON).
extends RefCounted

class_name PartInstance

## Namespaced template id, e.g. "base:iron_sword"
var template_id: String = ""

## Unique runtime id for this specific instance (UUID or incrementing int).
var instance_id: String = ""

## Instance-level stat overrides: { stat_key → float }
## Merged on top of the template's `stats` block at runtime.
var stat_overrides: Dictionary = {}

## Arbitrary instance flags set by script hooks: { flag_key → Variant }
var flags: Dictionary = {}

## The slot this part is equipped in, or "" if in inventory.
var equipped_slot: String = ""

## Whether this part is currently equipped.
var is_equipped: bool = false

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Creates a PartInstance from a template dictionary.
static func from_template(template: Dictionary) -> PartInstance:
	var inst := PartInstance.new()
	inst.template_id = template.get("id", "")
	inst.instance_id = _generate_id()
	return inst


static func _generate_id() -> String:
	return str(randi())


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the full template dictionary from DataManager.
func get_template() -> Dictionary:
	return DataManager.get_part(template_id)


## Returns the effective stat modifier for a key,
## applying instance_overrides on top of the template value.
func get_stat_modifier(stat_key: String) -> float:
	if stat_overrides.has(stat_key):
		return float(stat_overrides[stat_key])
	var template := get_template()
	var mods: Dictionary = template.get("stats", template.get("stat_modifiers", {}))
	return float(mods.get(stat_key, 0.0))


# ---------------------------------------------------------------------------
# Serialization (A2J)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"template_id": template_id,
		"instance_id": instance_id,
		"stat_overrides": stat_overrides.duplicate(),
		"flags": flags.duplicate(),
		"equipped_slot": equipped_slot,
		"is_equipped": is_equipped,
	}


func from_dict(data: Dictionary) -> void:
	template_id = data.get("template_id", "")
	instance_id = data.get("instance_id", "")
	stat_overrides = data.get("stat_overrides", {})
	flags = data.get("flags", {})
	equipped_slot = data.get("equipped_slot", "")
	is_equipped = data.get("is_equipped", false)
