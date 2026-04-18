## LocationViewScreen — Hub screen for a single location.
## Displays the location's name, description, and interactive screens as buttons.
## Pushing a screen button routes to the matching backend via UIRouter.
##
## Params accepted by initialize():
##   location_id: String  — optional; defaults to GameState.current_location_id
##
## Each entry in location.screens becomes one button. The button's pressed
## signal passes all screen-entry fields as params to the backend screen.
extends Control

class_name LocationViewScreen

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_MUTED_TEXT_COLOR := Color(0.6, 0.6, 0.6)
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")

const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _screens_container: VBoxContainer = $MarginContainer/VBoxContainer/ScreensScroll/ScreensContainer
@onready var _connections_container: HBoxContainer = $MarginContainer/VBoxContainer/ConnectionsContainer
@onready var _back_button: Button = $MarginContainer/VBoxContainer/NavRow/BackButton
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _location_id: String = ""
var _location_template: Dictionary = {}
var _last_view_model: Dictionary = {}


func initialize(params: Dictionary = {}) -> void:
	_location_id = str(params.get("location_id", GameState.current_location_id))
	_load_location()


func _ready() -> void:
	_back_button.pressed.connect(_on_back_button_pressed)
	GameEvents.location_changed.connect(_on_location_changed)
	if _location_id.is_empty():
		_location_id = GameState.current_location_id
	_load_location()


# ---------------------------------------------------------------------------
# Load & render
# ---------------------------------------------------------------------------

func _load_location() -> void:
	if _location_id.is_empty():
		_show_error("No active location.")
		return
	_location_template = LocationGraph.get_location(_location_id)
	if _location_template.is_empty():
		_show_error("Location '%s' not found." % _location_id)
		return
	_render_location()


func _render_location() -> void:
	var title_text := str(_location_template.get("display_name", _location_id))
	var description_text := str(_location_template.get("description", ""))
	_title_label.text = title_text
	_description_label.text = description_text

	_clear_container(_screens_container)
	_clear_container(_connections_container)

	var screen_entries: Array[Dictionary] = []
	var screens: Variant = _location_template.get("screens", [])
	if screens is Array and not screens.is_empty():
		for screen_entry in screens:
			if screen_entry is Dictionary:
				screen_entries.append((screen_entry as Dictionary).duplicate(true))
				_add_screen_button(screen_entry)
	else:
		var empty_label := Label.new()
		empty_label.text = "Nothing to do here yet."
		empty_label.modulate = _get_semantic_color("muted_text", FALLBACK_MUTED_TEXT_COLOR)
		_screens_container.add_child(empty_label)

	var connection_entries := _render_connections()
	_refresh_nav_state()
	_status_label.text = ""
	_status_label.modulate = _get_semantic_color("muted_text", FALLBACK_MUTED_TEXT_COLOR)
	_last_view_model = {
		"screen_id": "location_view",
		"location_id": _location_id,
		"title": title_text,
		"description": description_text,
		"screens": screen_entries,
		"connections": connection_entries,
		"status_text": "",
		"back_enabled": not _back_button.disabled,
	}


func _add_screen_button(screen_entry: Dictionary) -> void:
	var display_name: String = str(screen_entry.get("display_name", "Unnamed"))
	var description: String = str(screen_entry.get("description", ""))
	var backend_class: String = str(screen_entry.get("backend_class", ""))
	var screen_id: String = UI_ROUTE_CATALOG.get_screen_id_for_backend(backend_class)

	var btn := Button.new()
	btn.text = display_name
	btn.tooltip_text = description
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if screen_id.is_empty():
		btn.disabled = true
		btn.tooltip_text += "\n[backend '%s' not mapped]" % backend_class
	elif not UIRouter.is_registered(screen_id):
		btn.disabled = true
		btn.tooltip_text += "\n[screen '%s' not yet built]" % screen_id
	else:
		# Capture params for closure — pass the full screen entry as params
		var push_params: Dictionary = screen_entry.duplicate(true)
		if not push_params.has("cancel_screen_id"):
			push_params["cancel_screen_id"] = ""
		btn.pressed.connect(_on_screen_button_pressed.bind(screen_id, push_params))

	_screens_container.add_child(btn)


func _render_connections() -> Array[Dictionary]:
	var rendered_connections: Array[Dictionary] = []
	var connections: Dictionary = LocationGraph.get_connections(_location_id)
	if connections.is_empty():
		return rendered_connections

	var label := Label.new()
	label.text = "Travel:"
	_connections_container.add_child(label)

	for direction in connections.keys():
		var dest_id: String = str(connections[direction])
		var dest_template: Dictionary = LocationGraph.get_location(dest_id)
		var dest_name: String = str(dest_template.get("display_name", dest_id))
		rendered_connections.append({
			"direction": str(direction),
			"destination_id": dest_id,
			"destination_name": dest_name,
		})
		var btn := Button.new()
		btn.text = "%s -> %s" % [str(direction).capitalize(), dest_name]
		btn.pressed.connect(_on_travel_button_pressed.bind(dest_id))
		_connections_container.add_child(btn)
	return rendered_connections


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _show_error(message: String) -> void:
	_title_label.text = "Error"
	_description_label.text = message
	_status_label.text = message
	_status_label.modulate = _get_semantic_color("negative", FALLBACK_NEGATIVE_COLOR)
	_refresh_nav_state()
	_clear_container(_screens_container)
	_clear_container(_connections_container)
	_last_view_model = {
		"screen_id": "location_view",
		"location_id": _location_id,
		"title": "Error",
		"description": message,
		"screens": [],
		"connections": [],
		"status_text": message,
		"back_enabled": not _back_button.disabled,
	}


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_screen_button_pressed(screen_id: String, params: Dictionary) -> void:
	UIRouter.push(screen_id, params)


func _on_travel_button_pressed(dest_location_id: String) -> void:
	GameState.travel_to(dest_location_id)
	_location_id = dest_location_id
	_load_location()


func _on_back_button_pressed() -> void:
	if UIRouter.stack_depth() <= 1:
		return
	UIRouter.pop()


func _on_location_changed(_old_id: String, new_id: String) -> void:
	# If external code changes location (e.g. via GameState.travel_to from
	# elsewhere), refresh the view to reflect the new location.
	if new_id != _location_id:
		_location_id = new_id
		_load_location()


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback


func _refresh_nav_state() -> void:
	_back_button.disabled = UIRouter.stack_depth() <= 1


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)
