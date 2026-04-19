extends Control

const LIST_BACKEND := preload("res://ui/screens/backends/list_backend.gd")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")
const QUEST_CARD_SCENE := preload("res://ui/components/quest_card.tscn")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _detail_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailHost
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniListBackend = LIST_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _detail_control: Control = null
var _detail_kind: String = ""
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
	_title_label.text = str(view_model.get("title", "List View"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_confirm_button.text = str(view_model.get("confirm_label", "Use Selected"))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])))
	_render_detail(str(view_model.get("detail_kind", "")), _read_dictionary(view_model.get("selected_detail", {})))


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
			str(row.get("detail_text", "")),
		]
		button.pressed.connect(_on_row_pressed.bind(str(row.get("row_id", ""))))
		_rows_container.add_child(button)


func _render_detail(detail_kind: String, detail_view_model: Dictionary) -> void:
	if _detail_control != null and _detail_kind != detail_kind:
		_detail_host.remove_child(_detail_control)
		_detail_control.queue_free()
		_detail_control = null
	_detail_kind = detail_kind
	if _detail_control == null:
		match detail_kind:
			"part_card":
				var part_card_value: Variant = PART_CARD_SCENE.instantiate()
				if part_card_value is Control:
					_detail_control = part_card_value
			"quest_card":
				var quest_card_value: Variant = QUEST_CARD_SCENE.instantiate()
				if quest_card_value is Control:
					_detail_control = quest_card_value
			_:
				var label := Label.new()
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_detail_control = label
		if _detail_control != null:
			_detail_host.add_child(_detail_control)
	if _detail_control == null:
		return
	if _detail_control.has_method("render"):
		_detail_control.call("render", detail_view_model)
		return
	var label_control := _detail_control as Label
	if label_control != null:
		label_control.text = str(detail_view_model.get("text", "Select a row to inspect it."))


func _on_row_pressed(row_id: String) -> void:
	_backend.select_row(row_id)
	_refresh_state()


func _on_confirm_button_pressed() -> void:
	var action: Dictionary = _backend.confirm()
	_execute_navigation_action(action)
	_refresh_state()


func _on_back_button_pressed() -> void:
	UIRouter.pop()


func _execute_navigation_action(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	match action_type:
		"pop":
			UIRouter.pop()
		"replace_all":
			UIRouter.replace_all(str(action.get("screen_id", "")), _read_dictionary(action.get("params", {})))
		"push":
			UIRouter.push(str(action.get("screen_id", "")), _read_dictionary(action.get("params", {})))
		_:
			pass


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
