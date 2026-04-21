extends PanelContainer

class_name StatDeltaSheet

const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel

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
	_title_label.text = str(view_model.get("title", "Projected Stats"))
	var current_stats_data: Variant = view_model.get("current_stats", {})
	var projected_stats_data: Variant = view_model.get("projected_stats", {})
	var current_stats: Dictionary = {}
	var projected_stats: Dictionary = {}
	if current_stats_data is Dictionary:
		current_stats = current_stats_data
	if projected_stats_data is Dictionary:
		projected_stats = projected_stats_data
	_stats_label.bbcode_enabled = true
	_stats_label.text = "\n".join(_build_lines(current_stats, projected_stats))


func _build_lines(current_stats: Dictionary, projected_stats: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var stat_keys: Array = projected_stats.keys()
	for key in current_stats.keys():
		if not key in stat_keys:
			stat_keys.append(key)
	stat_keys.sort()
	for key in stat_keys:
		var stat_id := str(key)
		var current_value := float(current_stats.get(stat_id, 0.0))
		var projected_value := float(projected_stats.get(stat_id, 0.0))
		var delta := projected_value - current_value
		var delta_text := ""
		if absf(delta) > 0.001:
			delta_text = " %s" % _format_delta(delta)
		result.append("%s: %.0f -> %.0f%s" % [stat_id, current_value, projected_value, delta_text])
	if result.is_empty():
		result.append("No stats available.")
	return result


func _format_delta(delta: float) -> String:
	var color_name := "positive" if delta > 0.0 else "negative"
	var fallback := FALLBACK_POSITIVE_COLOR if delta > 0.0 else FALLBACK_NEGATIVE_COLOR
	var color_hex := _get_semantic_color(color_name, fallback).to_html(false)
	return "[color=#%s](%+.0f)[/color]" % [color_hex, delta]


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
