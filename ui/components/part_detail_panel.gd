extends PanelContainer

class_name PartDetailPanel

const ROOT_FALLBACK := "res://mods/base/assets/images/fallbacks/root_fallback.png"

@onready var _slot_label: Label = $MarginContainer/VBoxContainer/SlotLabel
@onready var _texture_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _price_label: Label = $MarginContainer/VBoxContainer/PriceLabel
@onready var _stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel


func render(view_model: Dictionary) -> void:
	var slot_label := str(view_model.get("slot_label", "Selection"))
	var current_name := str(view_model.get("current_name", "<empty>"))
	var preview_name := str(view_model.get("preview_name", current_name))
	var description := str(view_model.get("description", "No part selected."))
	var price_text := str(view_model.get("price_text", "Price: 0"))
	var stats_lines_data: Variant = view_model.get("stats_lines", [])
	var affordable := bool(view_model.get("affordable", true))
	var part_template_data: Variant = view_model.get("part_template", {})

	_slot_label.text = slot_label
	_title_label.text = preview_name
	_subtitle_label.text = "Current: %s" % current_name
	_description_label.text = description
	_price_label.text = price_text
	_price_label.modulate = Color("8fd18f") if affordable else Color("e07a7a")
	_texture_rect.texture = load(_resolve_sprite_path(part_template_data)) as Texture2D
	_stats_label.text = "\n".join(_normalize_lines(stats_lines_data))


func _normalize_lines(lines: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if not lines is Array:
		result.append("No stat changes.")
		return result
	for line in lines:
		result.append(str(line))
	if result.is_empty():
		result.append("No stat changes.")
	return result


func _resolve_sprite_path(part_template: Variant) -> String:
	if not part_template is Dictionary:
		return ROOT_FALLBACK
	var template: Dictionary = part_template
	var explicit_sprite := str(template.get("sprite", ""))
	if not explicit_sprite.is_empty() and ResourceLoader.exists(explicit_sprite):
		return explicit_sprite

	var tags_data: Variant = template.get("tags", [])
	if tags_data is Array:
		var tags: Array = tags_data
		if "head" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_head.png"
		if "hair" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_hat.png"
		if "torso" in tags or "body_core" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_torso.png"
		if "arm" in tags or "wing" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_arm.png"
		if "leg" in tags or "tail" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_leg.png"
		if "hand" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_hand.png"
		if "foot" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_foot.png"
		if "nose_cone" in tags or "fin" in tags or "thruster" in tags or "vehicle_core" in tags or "rocket_core" in tags:
			return "res://mods/base/assets/images/fallbacks/generic_cyberware.png"

	return ROOT_FALLBACK
