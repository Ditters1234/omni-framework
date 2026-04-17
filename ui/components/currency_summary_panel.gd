extends PanelContainer

class_name CurrencySummaryPanel

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _available_label: Label = $MarginContainer/VBoxContainer/AvailableLabel
@onready var _spent_label: Label = $MarginContainer/VBoxContainer/SpentLabel
@onready var _remaining_label: Label = $MarginContainer/VBoxContainer/RemainingLabel


func render(view_model: Dictionary) -> void:
	var currency_id := str(view_model.get("currency_id", "credits")).capitalize()
	var budget := float(view_model.get("budget", 0.0))
	var spent := float(view_model.get("spent", 0.0))
	var remaining := float(view_model.get("remaining", budget - spent))

	_title_label.text = "%s Budget" % currency_id
	_available_label.text = "Starting: %.0f" % budget
	_spent_label.text = "Spent: %.0f" % spent
	_remaining_label.text = "Remaining: %.0f" % remaining
