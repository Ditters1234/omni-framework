## StatBar view model contract:
## {
##   "stat_id": String,
##   "label": String,
##   "value": float,
##   "max_value": float,
##   "color_token": String
## }
extends PanelContainer

class_name StatBar

const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_INFO_COLOR := Color("#84a9ff")

@onready var _label: Label = $MarginContainer/VBoxContainer/HeaderRow/Label
@onready var _value_label: Label = $MarginContainer/VBoxContainer/HeaderRow/ValueLabel
@onready var _progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
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
	var stat_id := str(view_model.get("stat_id", ""))
	var label := str(view_model.get("label", _humanize_id(stat_id)))
	var value := float(view_model.get("value", 0.0))
	var max_value := float(view_model.get("max_value", 0.0))
	var color_token := str(view_model.get("color_token", "info"))
	var accent_color := _get_semantic_color(color_token, FALLBACK_INFO_COLOR)

	_label.text = label if not label.is_empty() else "Stat"
	_value_label.text = _build_value_text(value, max_value)
	_value_label.modulate = accent_color
	_apply_progress_theme(accent_color)

	if max_value > 0.0:
		_progress_bar.visible = true
		_progress_bar.max_value = max_value
		_progress_bar.value = clampf(value, 0.0, max_value)
	else:
		_progress_bar.visible = false


func _build_value_text(value: float, max_value: float) -> String:
	var value_text := _format_number(value)
	if max_value <= 0.0:
		return value_text
	return "%s / %s" % [value_text, _format_number(max_value)]


func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount


func _humanize_id(value: String) -> String:
	if value.is_empty():
		return ""
	var words := value.split("_", false)
	var formatted_words: Array[String] = []
	for word_value in words:
		var word := str(word_value)
		if word.is_empty():
			continue
		formatted_words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(formatted_words)


func _apply_progress_theme(accent_color: Color) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent_color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_bottom_left = 4
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = accent_color.darkened(0.7)
	background_style.corner_radius_top_left = 4
	background_style.corner_radius_top_right = 4
	background_style.corner_radius_bottom_right = 4
	background_style.corner_radius_bottom_left = 4
	_progress_bar.add_theme_stylebox_override("background", background_style)


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
