extends Control

const WORLD_MAP_BACKEND := preload("res://ui/screens/backends/world_map_backend.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _graph: Control = $MarginContainer/PanelContainer/VBoxContainer/MapPanel/MarginContainer/WorldMapGraph
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = WORLD_MAP_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false
var _status_override: String = ""


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()


func _ready() -> void:
	_connect_graph_signals()
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
	_title_label.text = str(view_model.get("title", "World Map"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = _status_override if not _status_override.is_empty() else str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	if _graph.has_method("render"):
		_graph.call("render", view_model)


func _connect_graph_signals() -> void:
	var select_callable := Callable(self, "_on_graph_location_selected")
	if not _graph.is_connected("location_selected", select_callable):
		_graph.connect("location_selected", select_callable)


func _on_graph_location_selected(location_id: String) -> void:
	var result_value: Variant = _backend.call("travel_to", location_id)
	var status := ""
	if result_value is Dictionary:
		var result: Dictionary = result_value
		status = str(result.get("status", ""))
		_status_override = str(result.get("message", ""))
	else:
		_status_override = ""
	if _opened_from_gameplay_shell and status == "ok":
		return
	_refresh_state()


func _on_back_button_pressed() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()
