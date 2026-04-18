## AssemblySlotRow view model contract:
## {
##   "slot_id": String,
##   "slot_label": String,
##   "current_name": String,
##   "preview_name": String,
##   "has_options": bool,
##   "can_apply": bool,
##   "can_clear": bool,
##   "selected": bool
## }
extends PanelContainer

class_name AssemblySlotRow

const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_PRIMARY_COLOR := Color("#4fb3ff")
const FALLBACK_MUTED_COLOR := Color("#9aa8bf")

signal previous_requested(slot_id: String)
signal next_requested(slot_id: String)
signal apply_requested(slot_id: String)
signal clear_requested(slot_id: String)
signal selected(slot_id: String)

@onready var _slot_label: Label = $MarginContainer/VBoxContainer/HeaderRow/SlotLabel
@onready var _selection_state_label: Label = $MarginContainer/VBoxContainer/HeaderRow/SelectionStateLabel
@onready var _current_label: Label = $MarginContainer/VBoxContainer/CurrentLabel
@onready var _preview_label: Label = $MarginContainer/VBoxContainer/PreviewLabel
@onready var _previous_button: Button = $MarginContainer/VBoxContainer/ButtonRow/PreviousButton
@onready var _next_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NextButton
@onready var _apply_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ApplyButton
@onready var _clear_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ClearButton

var _pending_view_model: Dictionary = {}
var _slot_id: String = ""


func _ready() -> void:
	_previous_button.pressed.connect(_on_previous_button_pressed)
	_next_button.pressed.connect(_on_next_button_pressed)
	_apply_button.pressed.connect(_on_apply_button_pressed)
	_clear_button.pressed.connect(_on_clear_button_pressed)
	gui_input.connect(_on_gui_input)
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model.duplicate(true)
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	_slot_id = str(view_model.get("slot_id", ""))
	var slot_label := str(view_model.get("slot_label", _slot_id))
	var current_name := str(view_model.get("current_name", "<empty>"))
	var preview_name := str(view_model.get("preview_name", current_name))
	var has_options := bool(view_model.get("has_options", false))
	var can_apply := bool(view_model.get("can_apply", false))
	var can_clear := bool(view_model.get("can_clear", false))
	var is_selected := bool(view_model.get("selected", false))
	var has_pending_change := preview_name != current_name

	_slot_label.text = slot_label if not slot_label.is_empty() else "Socket"
	_selection_state_label.text = "Selected" if is_selected else "Available"
	_selection_state_label.modulate = _get_semantic_color("primary", FALLBACK_PRIMARY_COLOR) if is_selected else _get_semantic_color("muted_text", FALLBACK_MUTED_COLOR)
	_current_label.text = "Current: %s" % current_name
	_preview_label.text = "Preview: %s" % preview_name
	_preview_label.modulate = _get_semantic_color("primary", FALLBACK_PRIMARY_COLOR) if has_pending_change else _get_semantic_color("muted_text", FALLBACK_MUTED_COLOR)
	_previous_button.disabled = not has_options
	_next_button.disabled = not has_options
	_apply_button.disabled = not can_apply
	_clear_button.disabled = not can_clear
	_apply_panel_style(is_selected)


func _apply_panel_style(is_selected: bool) -> void:
	var accent_color := _get_semantic_color("primary", FALLBACK_PRIMARY_COLOR)
	var border_color := accent_color if is_selected else accent_color.darkened(0.45)
	var style := StyleBoxFlat.new()
	style.bg_color = border_color.darkened(0.82)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", style)


func _on_previous_button_pressed() -> void:
	if _slot_id.is_empty():
		return
	previous_requested.emit(_slot_id)


func _on_next_button_pressed() -> void:
	if _slot_id.is_empty():
		return
	next_requested.emit(_slot_id)


func _on_apply_button_pressed() -> void:
	if _slot_id.is_empty():
		return
	apply_requested.emit(_slot_id)


func _on_clear_button_pressed() -> void:
	if _slot_id.is_empty():
		return
	clear_requested.emit(_slot_id)


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _slot_id.is_empty():
		return
	selected.emit(_slot_id)


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
