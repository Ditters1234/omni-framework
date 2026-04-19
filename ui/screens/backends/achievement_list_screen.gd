extends Control

const ACHIEVEMENT_LIST_BACKEND := preload("res://ui/screens/backends/achievement_list_backend.gd")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/RowsScroll/RowsContainer
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = ACHIEVEMENT_LIST_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
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
	_title_label.text = str(view_model.get("title", "Achievements"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])), str(view_model.get("empty_label", "No achievements are available.")))

func _render_rows(rows: Array[Dictionary], empty_label: String) -> void:
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = empty_label
		_rows_container.add_child(empty)
		return
	for row in rows:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _build_row_text(row)
		_rows_container.add_child(label)

func _build_row_text(row: Dictionary) -> String:
	var status := "Unlocked" if bool(row.get("unlocked", false)) else "Locked"
	var description := str(row.get("description", ""))
	var progress := str(row.get("progress_text", status))
	var text := "%s [%s]\n%s" % [
		str(row.get("display_name", row.get("achievement_id", "Achievement"))),
		status,
		progress,
	]
	if not description.is_empty():
		text += "\n%s" % description
	return text

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
