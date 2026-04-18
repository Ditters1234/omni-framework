extends Control

const ASSEMBLY_SLOT_ROW_SCENE := preload("res://ui/components/assembly_slot_row.tscn")
const ASSEMBLY_EDITOR_BACKEND := preload("res://ui/screens/backends/assembly_editor_backend.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _cancel_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BeginButton

var _currency_summary_panel: CurrencySummaryPanel = null
var _part_detail_panel: PartDetailPanel = null
var _stat_delta_sheet: StatDeltaSheet = null
var _slot_rows: Dictionary = {}
var _backend: RefCounted = ASSEMBLY_EDITOR_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_initialize_backend()
	if is_node_ready():
		_refresh_editor_state()


func _ready() -> void:
	_initialize_backend()
	_refresh_editor_state()


func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_backend_initialized = true
	_pending_params = {}


func _refresh_editor_state() -> void:
	if not _backend_initialized:
		return
	var view_model: Dictionary = _backend.build_view_model()
	_title_label.text = str(view_model.get("title", "Assembly Editor"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_cancel_button.text = str(view_model.get("cancel_label", "Cancel"))
	_confirm_button.text = str(view_model.get("confirm_label", "Confirm"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_refresh_editor_rows(_read_row_view_models(view_model))
	_refresh_currency_panel(_read_dictionary(view_model.get("currency_summary", {})))
	_refresh_part_detail_panel(_read_dictionary(view_model.get("part_detail", {})))
	_refresh_stat_sheet(_read_dictionary(view_model.get("stat_delta", {})))
	_status_label.text = str(view_model.get("status_text", ""))


func _refresh_editor_rows(row_view_models: Array[Dictionary]) -> void:
	var active_slots: Dictionary = {}
	var display_index := 0
	for row_view_model in row_view_models:
		var slot_id := str(row_view_model.get("slot_id", ""))
		if slot_id.is_empty():
			continue
		active_slots[slot_id] = true
		var row := _ensure_row_state(slot_id)
		if row == null:
			continue
		_rows_container.move_child(row, display_index)
		display_index += 1
		row.call("render", row_view_model)
	_remove_stale_rows(active_slots)


func _ensure_row_state(slot_id: String) -> Control:
	var existing_row_data: Variant = _slot_rows.get(slot_id, null)
	var existing_row := existing_row_data as Control
	if existing_row != null:
		return existing_row
	var row_value: Variant = ASSEMBLY_SLOT_ROW_SCENE.instantiate()
	if not row_value is Control:
		return null
	var row: Control = row_value
	_rows_container.add_child(row)
	row.connect("previous_requested", _on_cycle_pressed.bind(-1))
	row.connect("next_requested", _on_cycle_pressed.bind(1))
	row.connect("apply_requested", _on_apply_pressed)
	row.connect("clear_requested", _on_clear_pressed)
	row.connect("selected", _on_row_selected)
	_slot_rows[slot_id] = row
	return row


func _remove_stale_rows(active_slots: Dictionary) -> void:
	var stale_slots: Array[String] = []
	for slot_value in _slot_rows.keys():
		var slot_id := str(slot_value)
		if active_slots.has(slot_id):
			continue
		stale_slots.append(slot_id)
	for slot_id in stale_slots:
		var row_data: Variant = _slot_rows.get(slot_id, null)
		var row := row_data as Control
		if row != null:
			row.queue_free()
		_slot_rows.erase(slot_id)


func _get_currency_summary_panel() -> CurrencySummaryPanel:
	if _currency_summary_panel == null:
		_currency_summary_panel = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/CurrencySummaryPanel") as CurrencySummaryPanel
	return _currency_summary_panel


func _get_part_detail_panel() -> PartDetailPanel:
	if _part_detail_panel == null:
		_part_detail_panel = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/PartDetailPanel") as PartDetailPanel
	return _part_detail_panel


func _get_stat_delta_sheet() -> StatDeltaSheet:
	if _stat_delta_sheet == null:
		_stat_delta_sheet = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/StatDeltaSheet") as StatDeltaSheet
	return _stat_delta_sheet


func _refresh_currency_panel(view_model: Dictionary) -> void:
	var panel := _get_currency_summary_panel()
	if panel == null:
		return
	panel.render(view_model)


func _refresh_part_detail_panel(view_model: Dictionary) -> void:
	var panel := _get_part_detail_panel()
	if panel == null:
		return
	panel.render(view_model)


func _refresh_stat_sheet(view_model: Dictionary) -> void:
	var panel := _get_stat_delta_sheet()
	if panel == null:
		return
	panel.render(view_model)


func _on_cycle_pressed(slot_id: String, direction: int) -> void:
	_backend.cycle_slot(slot_id, direction)
	_refresh_editor_state()


func _on_apply_pressed(slot_id: String) -> void:
	_backend.apply_slot(slot_id)
	_refresh_editor_state()


func _on_clear_pressed(slot_id: String) -> void:
	_backend.clear_slot(slot_id)
	_refresh_editor_state()


func _on_row_selected(slot_id: String) -> void:
	_backend.select_slot(slot_id)
	_refresh_editor_state()


func _on_back_button_pressed() -> void:
	_execute_navigation_action(_backend.build_cancel_action())


func _on_begin_button_pressed() -> void:
	var navigation_action: Dictionary = _backend.confirm()
	if navigation_action.is_empty():
		_refresh_editor_state()
		return
	_execute_navigation_action(navigation_action)


func _execute_navigation_action(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	match action_type:
		"pop":
			UIRouter.pop()
		"replace_all":
			UIRouter.replace_all(
				str(action.get("screen_id", "")),
				_read_dictionary(action.get("params", {}))
			)
		_:
			pass


func _read_row_view_models(view_model: Dictionary) -> Array[Dictionary]:
	var rows_value: Variant = view_model.get("rows", [])
	var result: Array[Dictionary] = []
	if not rows_value is Array:
		return result
	var rows: Array = rows_value
	for row_value in rows:
		if row_value is Dictionary:
			var row_view_model: Dictionary = row_value
			result.append(row_view_model)
	return result


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
