extends Control

class_name OmniWorldMapGraph

signal location_selected(location_id: String)

const NODE_SIZE := Vector2(164, 52)
const DEFAULT_EDGE_COLOR := Color(0.48, 0.56, 0.64, 0.7)
const CURRENT_EDGE_COLOR := Color(1.0, 0.82, 0.38, 0.95)

var _locations: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _buttons_by_id: Dictionary = {}
var _show_travel_costs: bool = true


func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)


func render(view_model: Dictionary) -> void:
	_locations = _read_dictionary_array(view_model.get("locations", []))
	_edges = _read_dictionary_array(view_model.get("edges", []))
	_show_travel_costs = bool(view_model.get("show_travel_costs", true))
	_rebuild_location_buttons()
	_layout_location_buttons()
	queue_redraw()


func _draw() -> void:
	for edge in _edges:
		var from_id := str(edge.get("from_id", ""))
		var to_id := str(edge.get("to_id", ""))
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not _buttons_by_id.has(from_id) or not _buttons_by_id.has(to_id):
			continue
		var from_button := _buttons_by_id.get(from_id) as Button
		var to_button := _buttons_by_id.get(to_id) as Button
		if from_button == null or to_button == null:
			continue
		var from_center := from_button.position + from_button.size * 0.5
		var to_center := to_button.position + to_button.size * 0.5
		var edge_color := CURRENT_EDGE_COLOR if bool(edge.get("is_current_exit", false)) else DEFAULT_EDGE_COLOR
		draw_line(from_center, to_center, edge_color, 3.0, true)
		if _show_travel_costs:
			_draw_travel_cost(edge, from_center.lerp(to_center, 0.5), edge_color)


func _rebuild_location_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons_by_id.clear()

	for location in _locations:
		var location_id := str(location.get("location_id", ""))
		if location_id.is_empty():
			continue
		var button := Button.new()
		button.text = _build_button_text(location)
		button.tooltip_text = _build_tooltip_text(location)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.focus_mode = Control.FOCUS_ALL
		_apply_button_style(button, str(location.get("faction_color", "#7d8fa3")), bool(location.get("is_current", false)))
		button.pressed.connect(_on_location_button_pressed.bind(location_id))
		add_child(button)
		_buttons_by_id[location_id] = button


func _layout_location_buttons() -> void:
	var graph_size := size
	if graph_size.x <= 0.0 or graph_size.y <= 0.0:
		graph_size = custom_minimum_size
	var padding := Vector2(12, 12)
	var usable_size := Vector2(
		maxf(graph_size.x - padding.x * 2.0, NODE_SIZE.x),
		maxf(graph_size.y - padding.y * 2.0, NODE_SIZE.y)
	)
	for location in _locations:
		var location_id := str(location.get("location_id", ""))
		if location_id.is_empty():
			continue
		var button := _buttons_by_id.get(location_id) as Button
		if button == null:
			continue
		var position_value: Variant = location.get("position", {})
		var normalized_position := _read_normalized_position(position_value)
		var center := padding + Vector2(normalized_position.x * usable_size.x, normalized_position.y * usable_size.y)
		button.position = center - button.size * 0.5


func _draw_travel_cost(edge: Dictionary, midpoint: Vector2, color: Color) -> void:
	var travel_cost := int(edge.get("travel_cost", 0))
	if travel_cost <= 0:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var font_size := 13
	var text := str(travel_cost)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var rect := Rect2(midpoint - text_size * 0.5 - Vector2(5, 3), text_size + Vector2(10, 6))
	draw_rect(rect, Color(0.05, 0.07, 0.09, 0.84), true, -1.0)
	draw_rect(rect, color, false, 1.0)
	draw_string(font, midpoint + Vector2(-text_size.x * 0.5, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _build_button_text(location: Dictionary) -> String:
	var label := str(location.get("display_name", location.get("location_id", "Location")))
	if bool(location.get("is_current", false)):
		return "%s\nCurrent" % label
	return label


func _build_tooltip_text(location: Dictionary) -> String:
	var parts: Array[String] = []
	var description := str(location.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	var faction_name := str(location.get("faction_name", ""))
	if not faction_name.is_empty():
		parts.append("Faction: %s" % faction_name)
	parts.append("Connections: %s" % str(int(location.get("connection_count", 0))))
	if bool(location.get("is_discovered", false)):
		parts.append("Discovered")
	return "\n".join(parts)


func _apply_button_style(button: Button, color_text: String, is_current: bool) -> void:
	var base_color := Color.from_string(color_text, Color(0.49, 0.56, 0.64, 1.0))
	var normal := _build_node_style(base_color, is_current, 1.0)
	var hover := _build_node_style(base_color.lightened(0.14), is_current, 1.0)
	var pressed := _build_node_style(base_color.darkened(0.12), is_current, 1.0)
	var focus := _build_node_style(base_color.lightened(0.22), true, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", _readable_text_color(base_color))
	button.add_theme_color_override("font_hover_color", _readable_text_color(base_color.lightened(0.14)))
	button.add_theme_color_override("font_pressed_color", _readable_text_color(base_color.darkened(0.12)))


func _build_node_style(color: Color, is_current: bool, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.border_width_left = 3 if is_current else 1
	style.border_width_top = 3 if is_current else 1
	style.border_width_right = 3 if is_current else 1
	style.border_width_bottom = 3 if is_current else 1
	style.border_color = Color(1.0, 0.91, 0.55, 1.0) if is_current else color.lightened(0.28)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _readable_text_color(color: Color) -> Color:
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return Color(0.04, 0.05, 0.06, 1.0) if luminance > 0.58 else Color(0.96, 0.98, 1.0, 1.0)


func _read_normalized_position(value: Variant) -> Vector2:
	if value is Dictionary:
		var position: Dictionary = value
		var x_value: Variant = position.get("x", 0.5)
		var y_value: Variant = position.get("y", 0.5)
		if (x_value is int or x_value is float) and (y_value is int or y_value is float):
			return Vector2(clampf(float(x_value), 0.05, 0.95), clampf(float(y_value), 0.05, 0.95))
	return Vector2(0.5, 0.5)


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


func _on_location_button_pressed(location_id: String) -> void:
	location_selected.emit(location_id)


func _on_resized() -> void:
	_layout_location_buttons()
	queue_redraw()
