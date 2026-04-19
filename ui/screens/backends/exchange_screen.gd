extends Control

const EXCHANGE_BACKEND := preload("res://ui/screens/backends/exchange_backend.gd")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")
const CURRENCY_DISPLAY_SCENE := preload("res://ui/components/currency_display.tscn")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _card_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/Sidebar/CardHost
@onready var _currency_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/Sidebar/CurrencyHost
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniExchangeBackend = EXCHANGE_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _part_card: Control = null
var _currency_display: Control = null
var _last_view_model: Dictionary = {}

func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_initialize_backend()
	if is_node_ready():
		_refresh_state()

func _ready() -> void:
	_initialize_backend()
	_refresh_state()

func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)

func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_pending_params = {}
	_backend_initialized = true

func _refresh_state() -> void:
	if not _backend_initialized:
		return
	var view_model: Dictionary = _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_title_label.text = str(view_model.get("title", "Exchange"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_confirm_button.text = str(view_model.get("confirm_label", "Buy Selected"))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])))
	_render_selected_card(_read_dictionary(view_model.get("selected_card", {})))
	_render_currency_display(_read_dictionary(view_model.get("currency_display", {})))

func _render_rows(rows: Array[Dictionary]) -> void:
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = str(_last_view_model.get("empty_label", "Nothing is available."))
		_rows_container.add_child(empty_label)
		return
	for row in rows:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bool(row.get("selected", false))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [
			str(row.get("display_name", "Unnamed Item")),
			str(row.get("price_text", "")),
		]
		button.pressed.connect(_on_row_pressed.bind(str(row.get("instance_id", ""))))
		_rows_container.add_child(button)

func _render_selected_card(view_model: Dictionary) -> void:
	if _part_card == null:
		var part_card_value: Variant = PART_CARD_SCENE.instantiate()
		if part_card_value is Control:
			_part_card = part_card_value
			_card_host.add_child(_part_card)
	if _part_card != null:
		_part_card.call("render", view_model)

func _render_currency_display(view_model: Dictionary) -> void:
	if _currency_display == null:
		var currency_display_value: Variant = CURRENCY_DISPLAY_SCENE.instantiate()
		if currency_display_value is Control:
			_currency_display = currency_display_value
			_currency_host.add_child(_currency_display)
	if _currency_display != null:
		_currency_display.call("render", view_model)

func _on_row_pressed(instance_id: String) -> void:
	_backend.select_row(instance_id)
	_refresh_state()

func _on_confirm_button_pressed() -> void:
	var action: Dictionary = _backend.confirm()
	BACKEND_NAVIGATION_HELPER.dispatch_action(action)
	_refresh_state()

func _on_back_button_pressed() -> void:
	BACKEND_NAVIGATION_HELPER.close_surface()

func _read_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var values: Array = value
	for item in values:
		if item is Dictionary:
			var dictionary_item: Dictionary = item
			result.append(dictionary_item.duplicate(true))
	return result

func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
