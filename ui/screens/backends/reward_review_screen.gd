extends Control

const REWARD_REVIEW_BACKEND := preload("res://ui/screens/backends/reward_review_backend.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/RowsScroll/RowsContainer
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = REWARD_REVIEW_BACKEND.new()
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
	_title_label.text = str(view_model.get("title", "Reward Review"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])), str(view_model.get("empty_label", "No completed rewards have been recorded.")))


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
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_container.add_child(label)


func _build_row_text(row: Dictionary) -> String:
	var lines: Array[String] = [
		"#%s %s" % [str(row.get("sequence", 0)), str(row.get("title", "Reward"))],
		"Day %s, Tick %s - %s" % [str(row.get("day", 1)), str(row.get("tick", 0)), str(row.get("event_type", ""))],
		"Rewards: %s" % str(row.get("reward_summary", "No rewards")),
	]
	var description := str(row.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append(description)
	return "\n".join(lines)


func _on_back_button_pressed() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()


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
