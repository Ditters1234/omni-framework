extends Control

const SCHEDULE_BACKEND := preload("res://ui/screens/backends/schedule_backend.gd")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _range_label: Label = $MarginContainer/PanelContainer/VBoxContainer/RangeLabel
@onready var _datetime_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DateTimeLabel
@onready var _groups_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/SlotsScroll/GroupsContainer
@onready var _detail_title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailTitleLabel
@onready var _detail_meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailMetaLabel
@onready var _detail_description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailDescriptionLabel
@onready var _detail_reason_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailScroll/Detail/DetailReasonLabel
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = SCHEDULE_BACKEND.new()
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
	_title_label.text = str(view_model.get("title", "Schedule"))
	_range_label.text = str(view_model.get("range_text", ""))
	_datetime_label.text = str(view_model.get("datetime_text", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_groups(_read_dictionary_array(view_model.get("groups", [])))
	_render_detail(_read_dictionary(view_model.get("selected_slot", {})))


func _render_groups(groups: Array[Dictionary]) -> void:
	for child in _groups_container.get_children():
		_groups_container.remove_child(child)
		child.queue_free()
	if groups.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = str(_last_view_model.get("empty_label", "No scheduled activities are visible for this view."))
		_groups_container.add_child(empty_label)
		return
	for group in groups:
		var group_label := Label.new()
		group_label.text = str(group.get("label", "Schedule"))
		_groups_container.add_child(group_label)
		var slots := _read_dictionary_array(group.get("slots", []))
		for slot in slots:
			var button := Button.new()
			button.toggle_mode = true
			button.button_pressed = bool(slot.get("selected", false))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.text = _build_slot_text(slot)
			button.pressed.connect(_on_slot_pressed.bind(str(slot.get("slot_id", ""))))
			_groups_container.add_child(button)


func _render_detail(slot: Dictionary) -> void:
	_detail_title_label.text = str(slot.get("display_name", "Select a schedule slot"))
	_detail_meta_label.text = _build_detail_meta_text(slot)
	_detail_description_label.text = str(slot.get("description", ""))
	_detail_reason_label.text = str(slot.get("reason", ""))


func _on_slot_pressed(slot_id: String) -> void:
	_backend.select_slot(slot_id)
	_refresh_state()


func _on_back_button_pressed() -> void:
	BACKEND_NAVIGATION_HELPER.go_back(_opened_from_gameplay_shell)


func _build_slot_text(slot: Dictionary) -> String:
	var lines: Array[String] = [
		str(slot.get("display_name", "Unnamed Activity")),
		"%s | %s | %s" % [
			str(slot.get("status", "")),
			str(slot.get("time_text", "")),
			str(slot.get("duration_text", "")),
		],
	]
	var location_name := str(slot.get("location_name", "")).strip_edges()
	if not location_name.is_empty():
		lines.append(location_name)
	var reason := str(slot.get("reason", "")).strip_edges()
	if not reason.is_empty():
		lines.append(reason)
	return "\n".join(lines).strip_edges()


func _build_detail_meta_text(slot: Dictionary) -> String:
	if slot.is_empty():
		return ""
	var parts: Array[String] = []
	for field_name in ["date_text", "category_label", "status", "time_text", "duration_text", "location_name", "provider_name"]:
		var value := str(slot.get(field_name, "")).strip_edges()
		if value.is_empty():
			continue
		parts.append(value)
	return " | ".join(parts)


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
