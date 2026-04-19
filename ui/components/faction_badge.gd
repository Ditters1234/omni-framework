## FactionBadge view model contract:
## {
##   "faction_id": String,
##   "emblem_path": String,
##   "emblem_id": String,
##   "reputation_tier": String,
##   "reputation_value": float,
##   "color": Variant
## }
extends PanelContainer

class_name FactionBadge

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_SECONDARY_COLOR := Color("#7dd3a7")

@onready var _emblem_rect: TextureRect = $MarginContainer/HBoxContainer/EmblemRect
@onready var _name_label: Label = $MarginContainer/HBoxContainer/TextColumn/NameLabel
@onready var _reputation_label: Label = $MarginContainer/HBoxContainer/TextColumn/ReputationLabel

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
	var faction_id := str(view_model.get("faction_id", ""))
	var emblem_id := str(view_model.get("emblem_id", ""))
	var emblem_path := str(view_model.get("emblem_path", ""))
	var reputation_tier := str(view_model.get("reputation_tier", ""))
	var reputation_value := float(view_model.get("reputation_value", 0.0))
	var accent_color := _resolve_color(view_model.get("color", null))

	_name_label.text = _humanize_id(faction_id) if not faction_id.is_empty() else "Faction"
	_reputation_label.text = _build_reputation_text(reputation_tier, reputation_value)
	_reputation_label.visible = not _reputation_label.text.is_empty()
	_name_label.modulate = accent_color
	_reputation_label.modulate = accent_color.lightened(0.1)
	_apply_panel_style(accent_color)
	_apply_emblem(emblem_id, emblem_path)


func _apply_emblem(emblem_id: String, emblem_path: String) -> void:
	var resolved_path := BACKEND_HELPERS.resolve_visual_resource_path(emblem_id)
	if resolved_path.is_empty():
		resolved_path = emblem_path
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		_emblem_rect.texture = null
		_emblem_rect.visible = false
		return
	_emblem_rect.texture = load(resolved_path) as Texture2D
	_emblem_rect.visible = _emblem_rect.texture != null


func _build_reputation_text(reputation_tier: String, reputation_value: float) -> String:
	var tier_text := reputation_tier.strip_edges()
	if tier_text.is_empty():
		return "" if absf(reputation_value) < 0.001 else _format_reputation_value(reputation_value)
	if absf(reputation_value) < 0.001:
		return tier_text
	return "%s (%s)" % [tier_text, _format_reputation_value(reputation_value)]


func _format_reputation_value(value: float) -> String:
	if absf(value - roundf(value)) < 0.001:
		return "%+d" % int(roundf(value))
	return "%+.1f" % value


func _resolve_color(color_value: Variant) -> Color:
	if color_value is Color:
		return color_value
	if color_value is String:
		var color_text := str(color_value)
		if not color_text.is_empty():
			if color_text.begins_with("#"):
				return Color(color_text)
			if has_theme_color(color_text, SEMANTIC_THEME_TYPE):
				return get_theme_color(color_text, SEMANTIC_THEME_TYPE)
	if has_theme_color("secondary", SEMANTIC_THEME_TYPE):
		return get_theme_color("secondary", SEMANTIC_THEME_TYPE)
	return FALLBACK_SECONDARY_COLOR


func _apply_panel_style(accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent_color.darkened(0.8)
	style.border_color = accent_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", style)


func _humanize_id(value: String) -> String:
	if value.is_empty():
		return ""
	var trimmed := value.get_slice(":", value.get_slice_count(":") - 1)
	var words := trimmed.split("_", false)
	var formatted_words: Array[String] = []
	for word_value in words:
		var word := str(word_value)
		if word.is_empty():
			continue
		formatted_words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(formatted_words)
