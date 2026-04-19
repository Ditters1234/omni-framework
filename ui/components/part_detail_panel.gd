extends PanelContainer

class_name PartDetailPanel

const ROOT_FALLBACK := "res://mods/base/assets/images/fallbacks/root_fallback.png"
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")

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
	var default_sprite_paths_data: Variant = view_model.get("default_sprite_paths", {})
	var default_sprite_paths: Dictionary = {}
	if default_sprite_paths_data is Dictionary:
		default_sprite_paths = default_sprite_paths_data

	_slot_label.text = slot_label
	_title_label.text = preview_name
	_subtitle_label.text = "Current: %s" % current_name
	_description_label.text = description
	_price_label.text = price_text
	_price_label.modulate = _get_semantic_color("positive", FALLBACK_POSITIVE_COLOR) if affordable else _get_semantic_color("negative", FALLBACK_NEGATIVE_COLOR)
	var sprite_path := _resolve_sprite_path(part_template_data, default_sprite_paths)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_texture_rect.texture = load(sprite_path) as Texture2D
	else:
		_texture_rect.texture = null
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


func _resolve_sprite_path(part_template: Variant, default_sprite_paths: Dictionary) -> String:
	if not part_template is Dictionary:
		return ROOT_FALLBACK
	var template: Dictionary = part_template
	var explicit_sprite := str(template.get("sprite", ""))
	if not explicit_sprite.is_empty() and ResourceLoader.exists(explicit_sprite):
		return explicit_sprite

	var tags := _read_tags(template)
	var configured_sprite := _resolve_configured_default_sprite(tags, default_sprite_paths)
	if not configured_sprite.is_empty():
		return configured_sprite
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


func _read_tags(part_template: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var tags_data: Variant = part_template.get("tags", [])
	if not tags_data is Array:
		return tags
	var raw_tags: Array = tags_data
	for raw_tag in raw_tags:
		var tag_text := str(raw_tag)
		if not tag_text.is_empty():
			tags.append(tag_text)
	return tags


func _resolve_configured_default_sprite(tags: Array[String], configured_sprites: Dictionary) -> String:
	for tag in tags:
		if not configured_sprites.has(tag):
			continue
		var sprite_path := str(configured_sprites.get(tag, ""))
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			return sprite_path
	var fallback_path := str(configured_sprites.get("default", ""))
	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		return fallback_path
	return ""


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
