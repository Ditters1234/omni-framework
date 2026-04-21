extends PanelContainer

class_name CurrencySummaryPanel

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _available_label: Label = $MarginContainer/VBoxContainer/AvailableLabel
@onready var _spent_label: Label = $MarginContainer/VBoxContainer/SpentLabel
@onready var _remaining_label: Label = $MarginContainer/VBoxContainer/RemainingLabel

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
	var currency_id := str(view_model.get("currency_id", "credits"))
	var budget := float(view_model.get("budget", 0.0))
	var spent := float(view_model.get("spent", 0.0))
	var remaining := float(view_model.get("remaining", budget - spent))
	var currency_symbol := str(view_model.get("currency_symbol", ""))

	_title_label.text = "%s Budget" % currency_id.capitalize()
	_available_label.text = "Starting: %s" % _format_amount(budget, currency_symbol)
	_spent_label.text = "Spent: %s" % _format_amount(spent, currency_symbol)
	_remaining_label.text = "Remaining: %s" % _format_amount(remaining, currency_symbol)


func _format_amount(amount: float, currency_symbol: String) -> String:
	if currency_symbol.is_empty():
		return "%.0f" % amount
	return "%s%.0f" % [currency_symbol, amount]
