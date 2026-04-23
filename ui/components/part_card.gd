## PartCard view model contract:
## {
##   "template": Dictionary,
##   "default_sprite_paths": Dictionary,
##   "price_text": String,
##   "badges": Array,
##   "affordable": bool
## }
extends PanelContainer

class_name PartCard

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")
const FALLBACK_INFO_COLOR := Color("#84a9ff")

@onready var _texture_rect: TextureRect = $MarginContainer/HBoxContainer/VBoxContainer/TextureRect
@onready var _title_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var _template_id_label: Label = $MarginContainer/HBoxContainer/VBoxContainer2/TemplateIdLabel
@onready var _description_label: Label = $MarginContainer/HBoxContainer/VBoxContainer2/DescriptionLabel
@onready var _price_label: Label = $MarginContainer/HBoxContainer/VBoxContainer2/PriceLabel
@onready var _badges_container: HFlowContainer = $MarginContainer/HBoxContainer/VBoxContainer/BadgesContainer
@onready var _stats_label: RichTextLabel = $MarginContainer/HBoxContainer/VBoxContainer2/StatsLabel

var _pending_view_model: Dictionary = {}


func _ready() -> void:
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model.duplicate(true)
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	var template_value: Variant = view_model.get("template", {})
	var template: Dictionary = {}
	if template_value is Dictionary:
		template = template_value
	var default_sprite_paths_value: Variant = view_model.get("default_sprite_paths", {})
	var default_sprite_paths: Dictionary = {}
	if default_sprite_paths_value is Dictionary:
		default_sprite_paths = default_sprite_paths_value
	var price_text := str(view_model.get("price_text", _build_price_text(template)))
	var badges_value: Variant = view_model.get("badges", [])
	var affordable := bool(view_model.get("affordable", true))

	_title_label.text = str(template.get("display_name", "Unnamed Part"))
	_template_id_label.text = str(template.get("id", ""))
	_template_id_label.visible = not _template_id_label.text.is_empty()
	_description_label.text = str(template.get("description", "No part description is available."))
	_price_label.text = price_text
	_price_label.modulate = _get_semantic_color("positive", FALLBACK_POSITIVE_COLOR) if affordable else _get_semantic_color("negative", FALLBACK_NEGATIVE_COLOR)

	var sprite_path := BACKEND_HELPERS.resolve_part_sprite_path(template, default_sprite_paths)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_texture_rect.texture = load(sprite_path) as Texture2D
	else:
		_texture_rect.texture = null

	_render_badges(badges_value)
	_stats_label.text = "\n".join(_build_stat_lines(template))


func _render_badges(badges_value: Variant) -> void:
	for child in _badges_container.get_children():
		_badges_container.remove_child(child)
		child.queue_free()
	if not badges_value is Array:
		return
	var badges: Array = badges_value
	for badge_value in badges:
		var label := Label.new()
		var color_token := "info"
		if badge_value is Dictionary:
			var badge: Dictionary = badge_value
			label.text = str(badge.get("label", "Badge"))
			color_token = str(badge.get("color_token", "info"))
		else:
			label.text = str(badge_value)
		label.modulate = _get_semantic_color(color_token, FALLBACK_INFO_COLOR)
		_badges_container.add_child(label)


func _build_stat_lines(template: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var stats_value: Variant = template.get("stats", template.get("stat_modifiers", {}))
	if not stats_value is Dictionary:
		result.append("No stat modifiers.")
		return result
	var stats: Dictionary = stats_value
	if stats.is_empty():
		result.append("No stat modifiers.")
		return result
	var keys: Array = stats.keys()
	keys.sort()
	for key_value in keys:
		var stat_id := str(key_value)
		var amount := float(stats.get(key_value, 0.0))
		var amount_text := "%+.0f" % amount if absf(amount - roundf(amount)) < 0.001 else "%+.2f" % amount
		result.append("%s: %s" % [BACKEND_HELPERS.humanize_id(stat_id), amount_text])
	return result


func _build_price_text(template: Dictionary) -> String:
	var price_value: Variant = template.get("price", {})
	if not price_value is Dictionary:
		return ""
	var price: Dictionary = price_value
	if price.is_empty():
		return ""
	var keys: Array = price.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		parts.append("%s %s" % [str(price.get(key_value, 0)), BACKEND_HELPERS.humanize_id(str(key_value))])
	return "Price: %s" % ", ".join(parts)


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
