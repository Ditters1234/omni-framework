## CurrencyDisplay view model contract:
## {
##   "currency_id": String,
##   "label": String,
##   "amount": float,
##   "symbol": String,
##   "color_token": String
## }
extends PanelContainer

class_name CurrencyDisplay

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_PRIMARY_COLOR := Color("#4fb3ff")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _value_label: Label = $MarginContainer/VBoxContainer/ValueLabel
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
	var currency_id := str(view_model.get("currency_id", ""))
	var label := str(view_model.get("label", BACKEND_HELPERS.humanize_id(currency_id)))
	var amount := float(view_model.get("amount", 0.0))
	var symbol := str(view_model.get("symbol", ""))
	var color_token := str(view_model.get("color_token", "primary"))

	_title_label.text = label if not label.is_empty() else "Currency"
	_value_label.text = _format_amount(amount, symbol)
	_value_label.modulate = _get_semantic_color(color_token, FALLBACK_PRIMARY_COLOR)


func _format_amount(amount: float, symbol: String) -> String:
	var formatted_amount := _format_number(amount)
	if symbol.is_empty():
		return formatted_amount
	return "%s%s" % [symbol, formatted_amount]


func _format_number(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.001:
		return str(int(roundf(amount)))
	return "%.2f" % amount


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
