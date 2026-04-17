extends RefCounted

class_name OmniThemeApplier

const THEME_PATH := "res://ui/theme/omni_theme.tres"
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const DEFAULT_PRIMARY_COLOR := Color("#4fb3ff")
const DEFAULT_SECONDARY_COLOR := Color("#7dd3a7")
const DEFAULT_BACKGROUND_COLOR := Color("#11161f")
const DEFAULT_TEXT_COLOR := Color("#f3f7ff")
const DEFAULT_MUTED_TEXT_COLOR := Color("#9aa8bf")
const DEFAULT_POSITIVE_COLOR := Color("#7dd97d")
const DEFAULT_NEGATIVE_COLOR := Color("#ff7a7a")
const DEFAULT_WARNING_COLOR := Color("#f7c66b")
const DEFAULT_INFO_COLOR := Color("#84a9ff")
const DEFAULT_FONT_SIZE := 16


static func build_theme() -> Theme:
	var loaded_theme := load(THEME_PATH) as Theme
	var theme := Theme.new()
	if loaded_theme != null:
		var duplicated_theme := loaded_theme.duplicate(true) as Theme
		if duplicated_theme != null:
			theme = duplicated_theme

	var theme_config := _get_theme_config()
	_apply_palette(theme, theme_config)
	_apply_fonts(theme, theme_config)
	return theme


static func _get_theme_config() -> Dictionary:
	var theme_config_data: Variant = DataManager.get_config_value("ui.theme", {})
	if theme_config_data is Dictionary:
		var theme_config: Dictionary = theme_config_data
		return theme_config
	return {}


static func _apply_palette(theme: Theme, theme_config: Dictionary) -> void:
	var primary_color := _read_color(theme_config, "primary_color", DEFAULT_PRIMARY_COLOR)
	var secondary_color := _read_color(theme_config, "secondary_color", DEFAULT_SECONDARY_COLOR)
	var background_color := _read_color(theme_config, "bg_color", DEFAULT_BACKGROUND_COLOR)
	var text_color := _read_color(theme_config, "text_color", DEFAULT_TEXT_COLOR)
	var muted_text_color := _read_color(theme_config, "text_muted", DEFAULT_MUTED_TEXT_COLOR)
	var positive_color := _read_color(theme_config, "color_positive", DEFAULT_POSITIVE_COLOR)
	var negative_color := _read_color(theme_config, "color_negative", DEFAULT_NEGATIVE_COLOR)
	var warning_color := _read_color(theme_config, "color_warning", DEFAULT_WARNING_COLOR)
	var info_color := _read_color(theme_config, "color_info", DEFAULT_INFO_COLOR)

	var panel_fill := background_color.lightened(0.08)
	var panel_border := primary_color.darkened(0.15)
	var button_fill := background_color.lightened(0.16)
	var button_hover := primary_color.lerp(button_fill, 0.45)
	var button_pressed := primary_color.lerp(background_color, 0.25)
	var button_disabled := background_color.lightened(0.03)
	var button_text_pressed := background_color.lightened(0.45)

	theme.default_font_size = DEFAULT_FONT_SIZE
	theme.set_color("font_color", "Label", text_color)
	theme.set_color("font_outline_color", "Label", background_color.darkened(0.3))
	theme.set_constant("outline_size", "Label", 1)
	theme.set_color("default_color", "RichTextLabel", text_color)
	theme.set_color("font_color", "Button", text_color)
	theme.set_color("font_hover_color", "Button", text_color)
	theme.set_color("font_pressed_color", "Button", button_text_pressed)
	theme.set_color("font_disabled_color", "Button", muted_text_color)
	theme.set_color("font_focus_color", "Button", text_color)

	theme.set_stylebox("panel", "PanelContainer", _build_panel_style(panel_fill, panel_border))
	theme.set_stylebox("normal", "Button", _build_button_style(button_fill, panel_border))
	theme.set_stylebox("hover", "Button", _build_button_style(button_hover, primary_color))
	theme.set_stylebox("pressed", "Button", _build_button_style(button_pressed, secondary_color))
	theme.set_stylebox("disabled", "Button", _build_button_style(button_disabled, panel_border.darkened(0.25)))
	theme.set_stylebox("focus", "Button", _build_focus_style(primary_color))

	theme.set_color("primary", SEMANTIC_THEME_TYPE, primary_color)
	theme.set_color("secondary", SEMANTIC_THEME_TYPE, secondary_color)
	theme.set_color("background", SEMANTIC_THEME_TYPE, background_color)
	theme.set_color("text", SEMANTIC_THEME_TYPE, text_color)
	theme.set_color("muted_text", SEMANTIC_THEME_TYPE, muted_text_color)
	theme.set_color("positive", SEMANTIC_THEME_TYPE, positive_color)
	theme.set_color("negative", SEMANTIC_THEME_TYPE, negative_color)
	theme.set_color("warning", SEMANTIC_THEME_TYPE, warning_color)
	theme.set_color("info", SEMANTIC_THEME_TYPE, info_color)


static func _apply_fonts(theme: Theme, theme_config: Dictionary) -> void:
	var main_font := _load_font(theme_config.get("font_main", ""))
	if main_font != null:
		theme.default_font = main_font
		theme.set_font("main_font", SEMANTIC_THEME_TYPE, main_font)
	var mono_font := _load_font(theme_config.get("font_mono", ""))
	if mono_font != null:
		theme.set_font("mono_font", SEMANTIC_THEME_TYPE, mono_font)


static func _build_panel_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 18.0
	style.content_margin_top = 18.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 18.0
	return style


static func _build_button_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	return style


static func _build_focus_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color.lightened(0.15)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


static func _load_font(path_data: Variant) -> Font:
	var font_path := str(path_data)
	if font_path.is_empty():
		return null
	if not ResourceLoader.exists(font_path):
		return null
	return load(font_path) as Font


static func _read_color(theme_config: Dictionary, key: String, fallback: Color) -> Color:
	if not theme_config.has(key):
		return fallback
	var color_value: Variant = theme_config.get(key, "")
	if color_value is String:
		var color_text := str(color_value)
		if color_text.is_empty():
			return fallback
		return Color(color_text)
	return fallback
