extends Control

const WORLD_MAP_BACKEND := preload("res://ui/screens/backends/world_map_backend.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _orientation_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/ControlRow/OrientationButton
@onready var _zoom_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ControlRow/ZoomLabel
@onready var _graph: Control = $MarginContainer/PanelContainer/VBoxContainer/MapPanel/MarginContainer/WorldMapGraph
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

const ORIENTATION_MODES := ["radial", "horizontal", "vertical"]
const ORIENTATION_LABELS := ["Radial", "Horizontal", "Vertical"]

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
	_setup_controls()
	_connect_graph_signals()
	_connect_runtime_signals()
	_initialize_backend()
	_refresh_state()


func get_debug_snapshot() -> Dictionary:
	var snapshot := _last_view_model.duplicate(true)
	if _graph.has_method("get_viewport_snapshot"):
		var viewport_value: Variant = _graph.call("get_viewport_snapshot")
		if viewport_value is Dictionary:
			var viewport: Dictionary = viewport_value
			snapshot["viewport"] = viewport.duplicate(true)
	return snapshot


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
	_sync_zoom_label()


func _setup_controls() -> void:
	if _orientation_button.item_count > 0:
		return
	for index in range(ORIENTATION_LABELS.size()):
		_orientation_button.add_item(ORIENTATION_LABELS[index], index)
		_orientation_button.set_item_metadata(index, ORIENTATION_MODES[index])
	_orientation_button.select(0)


func _connect_graph_signals() -> void:
	var select_callable := Callable(self, "_on_graph_location_selected")
	if not _graph.is_connected("location_selected", select_callable):
		_graph.connect("location_selected", select_callable)
	var viewport_callable := Callable(self, "_on_graph_viewport_changed")
	if not _graph.is_connected("viewport_changed", viewport_callable):
		_graph.connect("viewport_changed", viewport_callable)


func _connect_runtime_signals() -> void:
	var location_changed_callable := Callable(self, "_on_location_changed")
	if not GameEvents.is_connected("location_changed", location_changed_callable):
		GameEvents.location_changed.connect(_on_location_changed)


func _on_graph_location_selected(location_id: String) -> void:
	var result_value: Variant = _backend.call("travel_to", location_id)
	if result_value is Dictionary:
		var result: Dictionary = result_value
		_status_override = str(result.get("message", ""))
	else:
		_status_override = ""
	_refresh_state()


func _on_back_button_pressed() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh_state()


func _on_graph_viewport_changed(snapshot: Dictionary) -> void:
	_sync_zoom_label(snapshot)


func _sync_zoom_label(snapshot: Dictionary = {}) -> void:
	var viewport := snapshot
	if viewport.is_empty() and _graph.has_method("get_viewport_snapshot"):
		var viewport_value: Variant = _graph.call("get_viewport_snapshot")
		if viewport_value is Dictionary:
			var viewport_dictionary: Dictionary = viewport_value
			viewport = viewport_dictionary
	var zoom := float(viewport.get("zoom", 1.0))
	_zoom_label.text = "%d%%" % int(round(zoom * 100.0))


func _on_zoom_out_button_pressed() -> void:
	if _graph.has_method("zoom_out"):
		_graph.call("zoom_out")


func _on_zoom_in_button_pressed() -> void:
	if _graph.has_method("zoom_in"):
		_graph.call("zoom_in")


func _on_fit_button_pressed() -> void:
	if _graph.has_method("fit_view"):
		_graph.call("fit_view")


func _on_current_button_pressed() -> void:
	if _graph.has_method("center_current"):
		_graph.call("center_current")


func _on_reset_button_pressed() -> void:
	if _graph.has_method("reset_view"):
		_graph.call("reset_view")
	_orientation_button.select(0)


func _on_orientation_button_item_selected(index: int) -> void:
	if index < 0 or index >= _orientation_button.item_count:
		return
	var mode_value: Variant = _orientation_button.get_item_metadata(index)
	var mode := str(mode_value)
	if _graph.has_method("set_orientation"):
		_graph.call("set_orientation", mode)
