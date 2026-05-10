extends Control

const LOOT_BACKEND := preload("res://ui/screens/backends/loot_backend.gd")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _detail_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/DetailHost
@onready var _currency_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/DetailHost/CurrencyRows
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _take_selected_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/TakeSelectedButton
@onready var _take_all_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/TakeAllButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = LOOT_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _part_card: Control = null
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
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
	_last_view_model["opened_from_gameplay_shell"] = _opened_from_gameplay_shell
	_title_label.text = str(view_model.get("title", "Loot"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_take_selected_button.text = str(view_model.get("confirm_label", "Take Selected"))
	_take_selected_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_take_all_button.text = str(view_model.get("take_all_label", "Take All"))
	_take_all_button.disabled = not bool(view_model.get("take_all_enabled", false))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])))
	_render_detail(_read_dictionary(view_model.get("selected_detail", {})))
	_render_currency_rows(_read_dictionary_array(view_model.get("currency_rows", [])))


func _render_rows(rows: Array[Dictionary]) -> void:
	_clear_children(_rows_container)
	if rows.is_empty():
		_add_wrapped_label(_rows_container, str(_last_view_model.get("empty_label", "Nothing is available.")))
		return
	for row in rows:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bool(row.get("selected", false))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [
			str(row.get("display_name", "Unnamed Item")),
			str(row.get("detail_text", "")),
		]
		button.pressed.connect(_on_row_pressed.bind(str(row.get("instance_id", ""))))
		_rows_container.add_child(button)


func _render_detail(view_model: Dictionary) -> void:
	if _part_card == null:
		var part_card_value: Variant = PART_CARD_SCENE.instantiate()
		if part_card_value is Control:
			_part_card = part_card_value
			_detail_host.add_child(_part_card)
	if _part_card != null:
		_part_card.call("render", view_model)


func _render_currency_rows(rows: Array[Dictionary]) -> void:
	_clear_children(_currency_rows)
	if rows.is_empty():
		_add_wrapped_label(_currency_rows, "No currency balances.")
		return
	_add_wrapped_label(_currency_rows, "Currencies")
	for row in rows:
		_add_wrapped_label(_currency_rows, "%s: %s" % [str(row.get("display_name", "")), str(row.get("detail_text", ""))])


func _on_row_pressed(instance_id: String) -> void:
	_backend.select_row(instance_id)
	_refresh_state()


func _on_take_selected_button_pressed() -> void:
	_execute_navigation_action(_backend.take_selected())
	_refresh_state()


func _on_take_all_button_pressed() -> void:
	_execute_navigation_action(_backend.take_all())
	_refresh_state()


func _on_back_button_pressed() -> void:
	_navigate_back()


func _navigate_back() -> void:
	BACKEND_NAVIGATION_HELPER.go_back(_opened_from_gameplay_shell)


func _execute_navigation_action(action: Dictionary) -> void:
	BACKEND_NAVIGATION_HELPER.execute_navigation_action(action, _opened_from_gameplay_shell)


func _add_wrapped_label(host: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(label)
	return label


func _clear_children(host: Node) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


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
