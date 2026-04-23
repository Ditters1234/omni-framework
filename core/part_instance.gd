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

## Instance-level custom values for template-declared custom fields.
var custom_values: Dictionary = {}

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
	inst.template_id = str(template.get("id", ""))
	inst.instance_id = _generate_id()
	inst.custom_values = _build_default_custom_values(template)
	return inst


static func _generate_id() -> String:
	# Use a combination of time + random to avoid collisions from randi() alone.
	return "%d_%d" % [Time.get_ticks_usec(), randi()]


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
	var mods: Dictionary = {}
	var mods_value: Variant = template.get("stats", template.get("stat_modifiers", {}))
	if mods_value is Dictionary:
		mods = mods_value
	return float(mods.get(stat_key, 0.0))


func get_custom_value(field_id: String, default_value: Variant = null) -> Variant:
	return custom_values.get(field_id, default_value)


func set_custom_value(field_id: String, value: Variant) -> void:
	if field_id.is_empty():
		return
	custom_values[field_id] = value


static func _build_default_custom_values(template: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var fields_value: Variant = template.get("custom_fields", null)
	if template.has("custom_fields") and fields_value is Array:
		var fields: Array = fields_value
		for field_value in fields:
			if not field_value is Dictionary:
				continue
			var field: Dictionary = field_value
			var field_id := str(field.get("id", ""))
			if field_id.is_empty():
				continue
			result[field_id] = field.get("default_value", "")
		return result
	var labels_value: Variant = template.get("custom_field_labels", null)
	if template.has("custom_field_labels") and labels_value is Array:
		var labels: Array = labels_value
		for label_value in labels:
			var label := str(label_value)
			var field_id := _custom_field_id_from_label(label)
			if not field_id.is_empty():
				result[field_id] = ""
	return result


static func _custom_field_id_from_label(label: String) -> String:
	var field_id := label.strip_edges().to_lower()
	field_id = field_id.replace(" ", "_")
	field_id = field_id.replace("-", "_")
	return field_id


# ---------------------------------------------------------------------------
# Serialization (A2J)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"template_id": template_id,
		"instance_id": instance_id,
		"stat_overrides": stat_overrides.duplicate(),
		"flags": flags.duplicate(),
		"custom_values": custom_values.duplicate(true),
		"equipped_slot": equipped_slot,
		"is_equipped": is_equipped,
	}


func from_dict(data: Dictionary) -> void:
	template_id = str(data.get("template_id", ""))
	instance_id = str(data.get("instance_id", ""))
	var stat_overrides_value: Variant = data.get("stat_overrides", {})
	if stat_overrides_value is Dictionary:
		stat_overrides = stat_overrides_value.duplicate(true)
	else:
		stat_overrides = {}
	var flags_value: Variant = data.get("flags", {})
	if flags_value is Dictionary:
		flags = flags_value.duplicate(true)
	else:
		flags = {}
	var custom_values_value: Variant = data.get("custom_values", {})
	custom_values = _build_default_custom_values(get_template())
	if data.has("custom_values") and custom_values_value is Dictionary:
		var saved_custom_values: Dictionary = custom_values_value
		for custom_key_value in saved_custom_values.keys():
			custom_values[custom_key_value] = saved_custom_values.get(custom_key_value)
	equipped_slot = str(data.get("equipped_slot", ""))
	is_equipped = bool(data.get("is_equipped", false))
