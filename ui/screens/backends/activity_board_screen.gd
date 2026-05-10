extends Control

const ACTIVITY_BOARD_BACKEND := preload("res://ui/screens/backends/activity_board_backend.gd")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _datetime_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DateTimeLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _detail_title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailTitleLabel
@onready var _detail_meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailMetaLabel
@onready var _detail_description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailDescriptionLabel
@onready var _detail_flavor_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailFlavorLabel
@onready var _preview_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/PreviewContainer
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = ACTIVITY_BOARD_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()


func _ready() -> void:
	_connect_activity_signals()
	_initialize_backend()
	_refresh_state()


func _exit_tree() -> void:
	_disconnect_activity_signals()


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
	_title_label.text = str(view_model.get("title", "Activities"))
	_description_label.text = str(view_model.get("description", ""))
	_datetime_label.text = str(view_model.get("datetime_text", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_confirm_button.text = str(view_model.get("confirm_label", "Start"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])))
	_render_detail(_read_dictionary(view_model.get("selected_row", {})))


func _render_rows(rows: Array[Dictionary]) -> void:
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = str(_last_view_model.get("empty_label", "No activities are available right now."))
		_rows_container.add_child(empty_label)
		return
	for row in rows:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bool(row.get("selected", false))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _build_row_text(row)
		button.pressed.connect(_on_row_pressed.bind(str(row.get("activity_id", ""))))
		_rows_container.add_child(button)


func _render_detail(row: Dictionary) -> void:
	_detail_title_label.text = str(row.get("display_name", "Select an activity"))
	_detail_meta_label.text = _build_detail_meta_text(row)
	_detail_description_label.text = str(row.get("description", ""))
	_detail_flavor_label.text = str(row.get("ai_flavor_text", ""))
	_render_preview_effects(_read_array(row.get("preview_effects", [])))


func _render_preview_effects(preview_effects: Array) -> void:
	for child in _preview_container.get_children():
		_preview_container.remove_child(child)
		child.queue_free()
	if preview_effects.is_empty():
		return
	for effect_value in preview_effects:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _format_preview_effect(effect_value)
		_preview_container.add_child(label)


func _on_row_pressed(activity_id: String) -> void:
	_backend.select_row(activity_id)
	_refresh_state()


func _on_confirm_button_pressed() -> void:
	var action: Dictionary = _backend.confirm()
	BACKEND_NAVIGATION_HELPER.execute_navigation_action(action, _opened_from_gameplay_shell)
	_refresh_state()


func _on_back_button_pressed() -> void:
	BACKEND_NAVIGATION_HELPER.go_back(_opened_from_gameplay_shell)


func _build_row_text(row: Dictionary) -> String:
	var lines: Array[String] = [
		str(row.get("display_name", "Unnamed Activity")),
		"%s | %s | %s" % [
			str(row.get("category_label", "")),
			str(row.get("time_text", "")),
			str(row.get("duration_text", "")),
		],
	]
	var location_name := str(row.get("location_name", "")).strip_edges()
	if not location_name.is_empty():
		lines.append(location_name)
	var reason := str(row.get("reason", "")).strip_edges()
	if not reason.is_empty():
		lines.append(reason)
	var flavor_text := str(row.get("ai_flavor_text", "")).strip_edges()
	if not flavor_text.is_empty():
		lines.append(flavor_text)
	return "\n".join(lines).strip_edges()


func _build_detail_meta_text(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var parts: Array[String] = []
	for field_name in ["category_label", "status", "time_text", "duration_text", "location_name", "provider_name"]:
		var value := str(row.get(field_name, "")).strip_edges()
		if value.is_empty():
			continue
		parts.append(value)
	return " | ".join(parts)


func _format_preview_effect(effect_value: Variant) -> String:
	if effect_value is Dictionary:
		var effect: Dictionary = effect_value
		return str(effect.get("label", effect.get("description", effect)))
	return str(effect_value)


func _connect_activity_signals() -> void:
	if GameEvents == null:
		return
	var narration_callback := Callable(self, "_on_event_narrated")
	if GameEvents.has_signal("event_narrated") and not GameEvents.is_connected("event_narrated", narration_callback):
		GameEvents.event_narrated.connect(_on_event_narrated)
	var completed_callback := Callable(self, "_on_activity_completed")
	if GameEvents.has_signal("activity_completed") and not GameEvents.is_connected("activity_completed", completed_callback):
		GameEvents.activity_completed.connect(_on_activity_completed)


func _disconnect_activity_signals() -> void:
	if GameEvents == null:
		return
	var narration_callback := Callable(self, "_on_event_narrated")
	if GameEvents.has_signal("event_narrated") and GameEvents.is_connected("event_narrated", narration_callback):
		GameEvents.event_narrated.disconnect(_on_event_narrated)
	var completed_callback := Callable(self, "_on_activity_completed")
	if GameEvents.has_signal("activity_completed") and GameEvents.is_connected("activity_completed", completed_callback):
		GameEvents.activity_completed.disconnect(_on_activity_completed)


func _on_event_narrated(source_signal: String, _source_key: String, _narration: String) -> void:
	if source_signal != "activity_flavor":
		return
	_refresh_state()


func _on_activity_completed(_payload: Dictionary) -> void:
	_refresh_state()


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


func _read_array(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	return []
