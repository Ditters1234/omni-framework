## NotificationPopup view model contract:
## {
##   "message": String,
##   "level": String,
##   "icon": Variant,
##   "duration_ms": int
## }
extends PanelContainer

class_name NotificationPopup

const SEMANTIC_THEME_TYPE := "OmniSemantic"
const LEVEL_TO_COLOR := {
	"info": "info",
	"success": "positive",
	"positive": "positive",
	"warning": "warning",
	"error": "negative",
	"negative": "negative",
}
const FALLBACK_INFO_COLOR := Color("#84a9ff")

@onready var _icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var _message_label: Label = $MarginContainer/HBoxContainer/MessageLabel
@onready var _hide_timer: Timer = $HideTimer

var _pending_view_model: Dictionary = {}
var _active_tween: Tween = null


func _ready() -> void:
	visible = false
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	var message := str(view_model.get("message", ""))
	if message.is_empty():
		hide()
		return
	var level := str(view_model.get("level", "info"))
	var duration_ms := maxi(int(view_model.get("duration_ms", 2500)), 1)
	var accent_color := _get_level_color(level)

	_message_label.text = message
	_message_label.modulate = accent_color
	_apply_panel_style(accent_color)
	_apply_icon(view_model.get("icon", null))
	_present(duration_ms)


func _apply_icon(icon_value: Variant) -> void:
	if icon_value is Texture2D:
		var icon_texture: Texture2D = icon_value
		_icon_rect.texture = icon_texture
		_icon_rect.visible = icon_texture != null
		return
	var icon_path := str(icon_value)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		_icon_rect.texture = null
		_icon_rect.visible = false
		return
	_icon_rect.texture = load(icon_path) as Texture2D
	_icon_rect.visible = _icon_rect.texture != null


func _present(duration_ms: int) -> void:
	if _active_tween != null:
		_active_tween.kill()
	if _hide_timer.time_left > 0.0:
		_hide_timer.stop()
	show()
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_hide_timer.start(float(duration_ms) / 1000.0)


func _on_hide_timer_timeout() -> void:
	if _active_tween != null:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_active_tween.finished.connect(func() -> void:
		hide()
	)


func _get_level_color(level: String) -> Color:
	var color_name := str(LEVEL_TO_COLOR.get(level, "info"))
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return FALLBACK_INFO_COLOR


func _apply_panel_style(accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent_color.darkened(0.84)
	style.border_color = accent_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	add_theme_stylebox_override("panel", style)
