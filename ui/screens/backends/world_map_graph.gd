extends Control

class_name OmniWorldMapGraph

signal location_selected(location_id: String)
signal viewport_changed(snapshot: Dictionary)

const NODE_SIZE := Vector2(164, 52)
const DEFAULT_EDGE_COLOR := Color(0.48, 0.56, 0.64, 0.7)
const CURRENT_EDGE_COLOR := Color(1.0, 0.82, 0.38, 0.95)
const BACKGROUND_COLOR := Color(0.045, 0.055, 0.065, 1.0)
const GRID_COLOR := Color(0.20, 0.25, 0.30, 0.28)
const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.9
const ZOOM_STEP := 1.18
const FULL_NODE_ZOOM := 0.88
const COMPACT_NODE_ZOOM := 0.56
const COST_LABEL_MIN_ZOOM := 0.7
const COMPACT_NODE_SIZE := Vector2(112, 40)
const MINIMAL_NODE_SIZE := Vector2(28, 28)
const MINIMAL_CURRENT_NODE_SIZE := Vector2(44, 28)
const FULL_NODE_FONT_SIZE := 14
const COMPACT_NODE_FONT_SIZE := 12
const RADIAL_CONTENT_SIZE := Vector2(1200, 780)
const LAYOUT_MARGIN := 120.0
const LAYER_GAP := 300.0
const LANE_GAP := 150.0

## Force-directed layout tuning.
const FORCE_ITERATIONS := 300
const FORCE_REPULSION := 200000.0
const FORCE_SPRING_K := 0.02
const FORCE_REST_LENGTH_PER_COST := 200.0
const FORCE_DAMPING := 0.85
const FORCE_MIN_SEPARATION_X := 200.0
const FORCE_MIN_SEPARATION_Y := 80.0
const FORCE_MAX_DISPLACEMENT := 30.0
const FORCE_COOLING_START := 0.9
const FORCE_COOLING_END := 0.1

const ORIENTATION_RADIAL := "radial"
const ORIENTATION_HORIZONTAL := "horizontal"
const ORIENTATION_VERTICAL := "vertical"

var _locations: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _buttons_by_id: Dictionary = {}
var _world_positions_by_id: Dictionary = {}
var _show_travel_costs: bool = true
var _orientation_mode: String = ORIENTATION_RADIAL
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _content_size: Vector2 = RADIAL_CONTENT_SIZE
var _has_user_view: bool = false
var _is_panning: bool = false
var _render_layout_refresh_pending: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)


func render(view_model: Dictionary) -> void:
	_locations = _read_dictionary_array(view_model.get("locations", []))
	_edges = _read_dictionary_array(view_model.get("edges", []))
	_show_travel_costs = bool(view_model.get("show_travel_costs", true))
	_rebuild_location_buttons()
	_rebuild_world_positions()
	if not _has_user_view:
		_fit_view_to_content(false)
	_layout_location_buttons()
	queue_redraw()
	_schedule_post_layout_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	_draw_grid()
	for edge in _edges:
		var from_id := str(edge.get("from_id", ""))
		var to_id := str(edge.get("to_id", ""))
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not _world_positions_by_id.has(from_id) or not _world_positions_by_id.has(to_id):
			continue
		var from_center := _world_to_screen(_read_world_position(from_id))
		var to_center := _world_to_screen(_read_world_position(to_id))
		var edge_color := CURRENT_EDGE_COLOR if bool(edge.get("is_current_exit", false)) else DEFAULT_EDGE_COLOR
		var edge_width := clampf(2.5 * _zoom, 1.5, 5.0)
		draw_line(from_center, to_center, edge_color, edge_width, true)
		draw_circle(from_center, 4.0, edge_color)
		draw_circle(to_center, 4.0, edge_color)
		if _show_travel_costs and _should_draw_travel_costs():
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
		button.tooltip_text = _build_tooltip_text(location)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		_apply_location_button_state(button, location)
		button.pressed.connect(_on_location_button_pressed.bind(location_id))
		add_child(button)
		_buttons_by_id[location_id] = button


func _layout_location_buttons() -> void:
	for location in _locations:
		var location_id := str(location.get("location_id", ""))
		if location_id.is_empty():
			continue
		var button := _buttons_by_id.get(location_id) as Button
		if button == null:
			continue
		_apply_location_button_state(button, location)
		var center := _world_to_screen(_read_world_position(location_id))
		button.position = center - button.size * 0.5
		button.visible = true


func _rebuild_world_positions() -> void:
	_world_positions_by_id.clear()
	match _orientation_mode:
		ORIENTATION_HORIZONTAL:
			_rebuild_layered_world_positions(true)
		ORIENTATION_VERTICAL:
			_rebuild_layered_world_positions(false)
		_:
			_rebuild_radial_world_positions()


func _rebuild_radial_world_positions() -> void:
	var location_ids := _get_location_ids()
	if location_ids.is_empty():
		_content_size = RADIAL_CONTENT_SIZE
		return

	var total := location_ids.size()
	# Scale content area with node count so nodes have room to breathe
	var area_scale := maxf(float(total) / 5.0, 1.0)
	_content_size = Vector2(
		maxf(RADIAL_CONTENT_SIZE.x * area_scale, RADIAL_CONTENT_SIZE.x),
		maxf(RADIAL_CONTENT_SIZE.y * area_scale, RADIAL_CONTENT_SIZE.y)
	)

	# --- Seed positions: authored map_position or circular fallback ---
	var positions: Dictionary = {}
	var pinned: Dictionary = {}
	for index in range(total):
		var location_id := location_ids[index]
		var authored := _get_authored_position(location_id)
		if authored.x >= 0.0:
			positions[location_id] = Vector2(
				authored.x * _content_size.x,
				authored.y * _content_size.y
			)
			pinned[location_id] = true
		else:
			# Spread initial seeds on a wider ellipse to reduce early collisions
			var angle := (TAU * float(index) / float(total)) - (PI * 0.5)
			positions[location_id] = Vector2(
				_content_size.x * (0.5 + cos(angle) * 0.4),
				_content_size.y * (0.5 + sin(angle) * 0.4)
			)
			pinned[location_id] = false

	# --- Build edge data with travel costs ---
	var edge_data: Array[Dictionary] = []
	var seen_pairs: Dictionary = {}
	for edge in _edges:
		var from_id := str(edge.get("from_id", ""))
		var to_id := str(edge.get("to_id", ""))
		if from_id.is_empty() or to_id.is_empty():
			continue
		if not positions.has(from_id) or not positions.has(to_id):
			continue
		var pair_key := from_id + "|" + to_id if from_id < to_id else to_id + "|" + from_id
		if seen_pairs.has(pair_key):
			continue
		seen_pairs[pair_key] = true
		var cost := maxi(int(edge.get("travel_cost", 1)), 1)
		edge_data.append({
			"from": from_id,
			"to": to_id,
			"rest_length": float(cost) * FORCE_REST_LENGTH_PER_COST,
		})

	# --- Force-directed simulation with cooling ---
	var velocities: Dictionary = {}
	for location_id in location_ids:
		velocities[location_id] = Vector2.ZERO

	for iteration in range(FORCE_ITERATIONS):
		# Temperature decreases linearly from COOLING_START to COOLING_END
		var t := float(iteration) / float(FORCE_ITERATIONS)
		var temperature := lerpf(FORCE_COOLING_START, FORCE_COOLING_END, t)

		var forces: Dictionary = {}
		for location_id in location_ids:
			forces[location_id] = Vector2.ZERO

		# --- Repulsion: all pairs push apart (Coulomb-like) ---
		for i in range(total):
			var id_a := location_ids[i]
			var pos_a: Vector2 = positions[id_a]
			for j in range(i + 1, total):
				var id_b := location_ids[j]
				var pos_b: Vector2 = positions[id_b]
				var delta := pos_a - pos_b
				var dist_sq := maxf(delta.length_squared(), 400.0)
				var repulsion_force := delta.normalized() * (FORCE_REPULSION / dist_sq)
				forces[id_a] += repulsion_force
				forces[id_b] -= repulsion_force

		# --- Spring attraction: connected nodes pull toward ideal distance ---
		for ed in edge_data:
			var from_id: String = ed["from"]
			var to_id: String = ed["to"]
			var rest_length: float = ed["rest_length"]
			var pos_from: Vector2 = positions[from_id]
			var pos_to: Vector2 = positions[to_id]
			var delta := pos_to - pos_from
			var dist := maxf(delta.length(), 1.0)
			var displacement := dist - rest_length
			var spring_force := delta.normalized() * (FORCE_SPRING_K * displacement)
			forces[from_id] += spring_force
			forces[to_id] -= spring_force

		# --- Rectangular overlap repulsion (accounts for actual node size) ---
		for i in range(total):
			var id_a := location_ids[i]
			var pos_a: Vector2 = positions[id_a]
			for j in range(i + 1, total):
				var id_b := location_ids[j]
				var pos_b: Vector2 = positions[id_b]
				var dx := absf(pos_a.x - pos_b.x)
				var dy := absf(pos_a.y - pos_b.y)
				var overlap_x := FORCE_MIN_SEPARATION_X - dx
				var overlap_y := FORCE_MIN_SEPARATION_Y - dy
				if overlap_x > 0.0 and overlap_y > 0.0:
					# Push apart along the axis with less overlap (cheaper escape)
					var push: Vector2
					if overlap_x < overlap_y:
						var dir_x := 1.0 if pos_a.x >= pos_b.x else -1.0
						push = Vector2(dir_x * overlap_x * 0.6, 0.0)
					else:
						var dir_y := 1.0 if pos_a.y >= pos_b.y else -1.0
						push = Vector2(0.0, dir_y * overlap_y * 0.6)
					forces[id_a] += push
					forces[id_b] -= push

		# --- Gentle centering pull to prevent drift ---
		var center_target := _content_size * 0.5
		for location_id in location_ids:
			if pinned[location_id]:
				continue
			var pos: Vector2 = positions[location_id]
			var to_center := center_target - pos
			forces[location_id] += to_center * 0.0005

		# --- Apply forces with damping, temperature, and displacement cap ---
		for location_id in location_ids:
			if pinned[location_id]:
				continue
			var vel: Vector2 = velocities[location_id]
			vel = (vel + forces[location_id]) * FORCE_DAMPING * temperature
			var max_disp := FORCE_MAX_DISPLACEMENT * temperature
			if vel.length() > max_disp:
				vel = vel.normalized() * max_disp
			velocities[location_id] = vel
			var pos: Vector2 = positions[location_id]
			pos += vel
			pos.x = clampf(pos.x, LAYOUT_MARGIN, _content_size.x - LAYOUT_MARGIN)
			pos.y = clampf(pos.y, LAYOUT_MARGIN, _content_size.y - LAYOUT_MARGIN)
			positions[location_id] = pos

	# --- Final overlap resolution pass (deterministic, no physics) ---
	_resolve_remaining_overlaps(positions, pinned, location_ids)

	for location_id in location_ids:
		_world_positions_by_id[location_id] = positions[location_id]


## Iterative sweep to fix any overlaps the simulation didn't fully resolve.
func _resolve_remaining_overlaps(positions: Dictionary, pinned: Dictionary, location_ids: Array[String]) -> void:
	var total := location_ids.size()
	for _pass in range(20):
		var had_overlap := false
		for i in range(total):
			var id_a := location_ids[i]
			var pos_a: Vector2 = positions[id_a]
			for j in range(i + 1, total):
				var id_b := location_ids[j]
				var pos_b: Vector2 = positions[id_b]
				var dx := absf(pos_a.x - pos_b.x)
				var dy := absf(pos_a.y - pos_b.y)
				var overlap_x := FORCE_MIN_SEPARATION_X - dx
				var overlap_y := FORCE_MIN_SEPARATION_Y - dy
				if overlap_x > 0.0 and overlap_y > 0.0:
					had_overlap = true
					var a_pinned := bool(pinned.get(id_a, false))
					var b_pinned := bool(pinned.get(id_b, false))
					if a_pinned and b_pinned:
						continue
					# Resolve along the cheaper axis
					if overlap_x < overlap_y:
						var dir_x := 1.0 if pos_a.x >= pos_b.x else -1.0
						var shift := overlap_x * 0.55
						if a_pinned:
							pos_b.x -= dir_x * shift * 2.0
						elif b_pinned:
							pos_a.x += dir_x * shift * 2.0
						else:
							pos_a.x += dir_x * shift
							pos_b.x -= dir_x * shift
					else:
						var dir_y := 1.0 if pos_a.y >= pos_b.y else -1.0
						var shift := overlap_y * 0.55
						if a_pinned:
							pos_b.y -= dir_y * shift * 2.0
						elif b_pinned:
							pos_a.y += dir_y * shift * 2.0
						else:
							pos_a.y += dir_y * shift
							pos_b.y -= dir_y * shift
					pos_a.x = clampf(pos_a.x, LAYOUT_MARGIN, _content_size.x - LAYOUT_MARGIN)
					pos_a.y = clampf(pos_a.y, LAYOUT_MARGIN, _content_size.y - LAYOUT_MARGIN)
					pos_b.x = clampf(pos_b.x, LAYOUT_MARGIN, _content_size.x - LAYOUT_MARGIN)
					pos_b.y = clampf(pos_b.y, LAYOUT_MARGIN, _content_size.y - LAYOUT_MARGIN)
					positions[id_a] = pos_a
					positions[id_b] = pos_b
		if not had_overlap:
			break


## Returns the authored map_position for a location, or Vector2(-1, -1) if none.
func _get_authored_position(location_id: String) -> Vector2:
	for location in _locations:
		if str(location.get("location_id", "")) != location_id:
			continue
		var pos_value: Variant = location.get("position", {})
		if not pos_value is Dictionary:
			return Vector2(-1.0, -1.0)
		var pos_dict: Dictionary = pos_value
		if not bool(pos_dict.get("authored", false)):
			return Vector2(-1.0, -1.0)
		var x_val: Variant = pos_dict.get("x", -1.0)
		var y_val: Variant = pos_dict.get("y", -1.0)
		if (x_val is int or x_val is float) and (y_val is int or y_val is float):
			return Vector2(clampf(float(x_val), 0.05, 0.95), clampf(float(y_val), 0.05, 0.95))
		return Vector2(-1.0, -1.0)
	return Vector2(-1.0, -1.0)


func _rebuild_layered_world_positions(horizontal: bool) -> void:
	var location_ids := _get_location_ids()
	if location_ids.is_empty():
		_content_size = RADIAL_CONTENT_SIZE
		return
	var depths := _build_graph_depths(location_ids)
	var groups: Dictionary = {}
	var max_depth := 0
	for location_id in location_ids:
		var depth := int(depths.get(location_id, 0))
		max_depth = maxi(max_depth, depth)
		if not groups.has(depth):
			groups[depth] = []
		var group_value: Variant = groups.get(depth, [])
		if not group_value is Array:
			continue
		var group: Array = group_value
		group.append(location_id)

	var max_group_size := 1
	for group_value in groups.values():
		if not group_value is Array:
			continue
		var group: Array = group_value
		group.sort()
		max_group_size = maxi(max_group_size, group.size())

	var width := maxf(LAYOUT_MARGIN * 2.0 + float(max_depth) * LAYER_GAP, 900.0)
	var height := maxf(LAYOUT_MARGIN * 2.0 + float(max_group_size - 1) * LANE_GAP, 620.0)
	_content_size = Vector2(width, height) if horizontal else Vector2(height, width)

	for depth_value in groups.keys():
		var depth := int(depth_value)
		var group_value: Variant = groups.get(depth, [])
		if not group_value is Array:
			continue
		var group: Array = group_value
		var lane_count := group.size()
		for index in range(lane_count):
			var location_id := str(group[index])
			var lane_offset := (float(index) - float(lane_count - 1) * 0.5) * LANE_GAP
			if horizontal:
				_world_positions_by_id[location_id] = Vector2(
					LAYOUT_MARGIN + float(depth) * LAYER_GAP,
					_content_size.y * 0.5 + lane_offset
				)
			else:
				_world_positions_by_id[location_id] = Vector2(
					_content_size.x * 0.5 + lane_offset,
					LAYOUT_MARGIN + float(depth) * LAYER_GAP
				)


func _draw_travel_cost(edge: Dictionary, midpoint: Vector2, color: Color) -> void:
	var travel_cost := int(edge.get("travel_cost", 0))
	if travel_cost <= 0:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var font_scale := _node_zoom_blend(COMPACT_NODE_ZOOM, FULL_NODE_ZOOM)
	var font_size := int(round(lerpf(11.0, 13.0, font_scale)))
	var text := str(travel_cost)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var rect := Rect2(midpoint - text_size * 0.5 - Vector2(5, 3), text_size + Vector2(10, 6))
	draw_rect(rect, Color(0.05, 0.07, 0.09, 0.84), true, -1.0)
	draw_rect(rect, color, false, 1.0)
	draw_string(font, midpoint + Vector2(-text_size.x * 0.5, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_grid() -> void:
	var spacing := 96.0 * _zoom
	if spacing < 28.0:
		spacing *= 2.0
	if spacing <= 0.0:
		return
	var start_x := fposmod(_pan_offset.x, spacing) - spacing
	var start_y := fposmod(_pan_offset.y, spacing) - spacing
	var x := start_x
	while x <= size.x + spacing:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += spacing
	var y := start_y
	while y <= size.y + spacing:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += spacing


func _apply_location_button_state(button: Button, location: Dictionary) -> void:
	var is_current := bool(location.get("is_current", false))
	var compact_mode := _zoom < FULL_NODE_ZOOM
	var minimal_mode := _zoom < COMPACT_NODE_ZOOM
	var node_size := _get_button_size(location)
	button.text = _build_button_text(location)
	button.custom_minimum_size = node_size
	button.size = node_size
	button.autowrap_mode = TextServer.AUTOWRAP_OFF if minimal_mode else TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override(
		"font_size",
		COMPACT_NODE_FONT_SIZE if compact_mode else FULL_NODE_FONT_SIZE
	)
	_apply_button_style(button, str(location.get("faction_color", "#7d8fa3")), is_current, compact_mode)


func _build_button_text(location: Dictionary) -> String:
	var label := str(location.get("display_name", location.get("location_id", "Location")))
	var is_current := bool(location.get("is_current", false))
	if _zoom < COMPACT_NODE_ZOOM:
		return "Here" if is_current else ""
	if _zoom < FULL_NODE_ZOOM:
		return label
	if is_current:
		return "%s\nCurrent" % label
	return label


func _build_tooltip_text(location: Dictionary) -> String:
	var parts: Array[String] = [str(location.get("display_name", location.get("location_id", "Location")))]
	var description := str(location.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	if bool(location.get("is_current", false)):
		parts.append("Current location")
	var faction_name := str(location.get("faction_name", ""))
	if not faction_name.is_empty():
		parts.append("Faction: %s" % faction_name)
	parts.append("Connections: %s" % str(int(location.get("connection_count", 0))))
	if not bool(location.get("can_enter", true)):
		var locked_message := str(location.get("locked_message", "You cannot enter this location right now."))
		if not locked_message.is_empty():
			parts.append(locked_message)
	if bool(location.get("is_discovered", false)):
		parts.append("Discovered")
	return "\n".join(parts)


func _apply_button_style(button: Button, color_text: String, is_current: bool, compact_mode: bool) -> void:
	var base_color := Color.from_string(color_text, Color(0.49, 0.56, 0.64, 1.0))
	var normal := _build_node_style(base_color, is_current, 1.0, compact_mode)
	var hover := _build_node_style(base_color.lightened(0.14), is_current, 1.0, compact_mode)
	var pressed := _build_node_style(base_color.darkened(0.12), is_current, 1.0, compact_mode)
	var focus := _build_node_style(base_color.lightened(0.22), true, 1.0, compact_mode)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", _readable_text_color(base_color))
	button.add_theme_color_override("font_hover_color", _readable_text_color(base_color.lightened(0.14)))
	button.add_theme_color_override("font_pressed_color", _readable_text_color(base_color.darkened(0.12)))


func _build_node_style(color: Color, is_current: bool, alpha: float, compact_mode: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.border_width_left = 3 if is_current else 1
	style.border_width_top = 3 if is_current else 1
	style.border_width_right = 3 if is_current else 1
	style.border_width_bottom = 3 if is_current else 1
	style.border_color = Color(1.0, 0.91, 0.55, 1.0) if is_current else color.lightened(0.28)
	var corner_radius := 14 if compact_mode else 6
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	if compact_mode:
		style.content_margin_left = 6
		style.content_margin_top = 4
		style.content_margin_right = 6
		style.content_margin_bottom = 4
	else:
		style.content_margin_left = 8
		style.content_margin_top = 6
		style.content_margin_right = 8
		style.content_margin_bottom = 6
	return style


func _get_button_size(location: Dictionary) -> Vector2:
	if _zoom < COMPACT_NODE_ZOOM:
		return MINIMAL_CURRENT_NODE_SIZE if bool(location.get("is_current", false)) else MINIMAL_NODE_SIZE
	var zoom_blend := _node_zoom_blend(COMPACT_NODE_ZOOM, FULL_NODE_ZOOM)
	return COMPACT_NODE_SIZE.lerp(NODE_SIZE, zoom_blend)


func _node_zoom_blend(min_zoom: float, max_zoom: float) -> float:
	var zoom_range := maxf(max_zoom - min_zoom, 0.001)
	return clampf((_zoom - min_zoom) / zoom_range, 0.0, 1.0)


func _should_draw_travel_costs() -> bool:
	return _zoom >= COST_LABEL_MIN_ZOOM


func _readable_text_color(color: Color) -> Color:
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return Color(0.04, 0.05, 0.06, 1.0) if luminance > 0.58 else Color(0.96, 0.98, 1.0, 1.0)


func _read_normalized_position(value: Variant) -> Vector2:
	if value is Dictionary:
		var pos_dict: Dictionary = value
		var x_value: Variant = pos_dict.get("x", 0.5)
		var y_value: Variant = pos_dict.get("y", 0.5)
		if (x_value is int or x_value is float) and (y_value is int or y_value is float):
			return Vector2(clampf(float(x_value), 0.05, 0.95), clampf(float(y_value), 0.05, 0.95))
	return Vector2(0.5, 0.5)


func _read_world_position(location_id: String) -> Vector2:
	var position_value: Variant = _world_positions_by_id.get(location_id, _content_size * 0.5)
	if position_value is Vector2:
		return position_value
	return _content_size * 0.5


func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position * _zoom + _pan_offset


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - _pan_offset) / _zoom


func _is_screen_position_near_viewport(screen_position: Vector2) -> bool:
	var margin := maxf(NODE_SIZE.x, NODE_SIZE.y) * 1.5
	var viewport_size := _get_effective_viewport_size()
	var bounds := Rect2(Vector2(-margin, -margin), viewport_size + Vector2(margin * 2.0, margin * 2.0))
	return bounds.has_point(screen_position)


func _get_location_ids() -> Array[String]:
	var location_ids: Array[String] = []
	for location in _locations:
		var location_id := str(location.get("location_id", ""))
		if not location_id.is_empty():
			location_ids.append(location_id)
	location_ids.sort()
	return location_ids


func _build_graph_depths(location_ids: Array[String]) -> Dictionary:
	var start_id := _get_current_location_id()
	if start_id.is_empty() or not location_ids.has(start_id):
		start_id = location_ids[0]
	var adjacency := _build_adjacency(location_ids)
	var depths: Dictionary = {}
	var queue: Array[String] = [start_id]
	depths[start_id] = 0
	while not queue.is_empty():
		var current_id := str(queue.pop_front())
		var current_depth := int(depths.get(current_id, 0))
		var neighbors_value: Variant = adjacency.get(current_id, [])
		if not neighbors_value is Array:
			continue
		var neighbors: Array = neighbors_value
		for neighbor_value in neighbors:
			var neighbor_id := str(neighbor_value)
			if neighbor_id.is_empty() or depths.has(neighbor_id):
				continue
			depths[neighbor_id] = current_depth + 1
			queue.append(neighbor_id)
	var fallback_depth := _max_depth(depths) + 1
	for location_id in location_ids:
		if not depths.has(location_id):
			depths[location_id] = fallback_depth
	return depths


func _build_adjacency(location_ids: Array[String]) -> Dictionary:
	var allowed_ids: Dictionary = {}
	var adjacency: Dictionary = {}
	for location_id in location_ids:
		allowed_ids[location_id] = true
		adjacency[location_id] = []
	for edge in _edges:
		var from_id := str(edge.get("from_id", ""))
		var to_id := str(edge.get("to_id", ""))
		if not allowed_ids.has(from_id) or not allowed_ids.has(to_id):
			continue
		var from_neighbors_value: Variant = adjacency.get(from_id, [])
		var to_neighbors_value: Variant = adjacency.get(to_id, [])
		if not from_neighbors_value is Array or not to_neighbors_value is Array:
			continue
		var from_neighbors: Array = from_neighbors_value
		var to_neighbors: Array = to_neighbors_value
		if not from_neighbors.has(to_id):
			from_neighbors.append(to_id)
		if not to_neighbors.has(from_id):
			to_neighbors.append(from_id)
	for location_id in location_ids:
		var neighbors_value: Variant = adjacency.get(location_id, [])
		if not neighbors_value is Array:
			continue
		var neighbors: Array = neighbors_value
		neighbors.sort()
	return adjacency


func _max_depth(depths: Dictionary) -> int:
	var max_depth := 0
	for depth_value in depths.values():
		max_depth = maxi(max_depth, int(depth_value))
	return max_depth


func _get_current_location_id() -> String:
	for location in _locations:
		if bool(location.get("is_current", false)):
			return str(location.get("location_id", ""))
	return ""


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


func zoom_in() -> void:
	_zoom_about(_get_effective_viewport_size() * 0.5, _zoom * ZOOM_STEP, true)


func zoom_out() -> void:
	_zoom_about(_get_effective_viewport_size() * 0.5, _zoom / ZOOM_STEP, true)


func fit_view() -> void:
	_fit_view_to_content(true)


func reset_view() -> void:
	_orientation_mode = ORIENTATION_RADIAL
	_has_user_view = false
	_rebuild_world_positions()
	_fit_view_to_content(false)
	_layout_location_buttons()
	queue_redraw()
	_emit_viewport_changed()


func center_current() -> void:
	var current_id := _get_current_location_id()
	if current_id.is_empty():
		_fit_view_to_content(true)
		return
	_center_on_world_position(_read_world_position(current_id), true)


func set_orientation(mode: String) -> void:
	if mode != ORIENTATION_RADIAL and mode != ORIENTATION_HORIZONTAL and mode != ORIENTATION_VERTICAL:
		return
	_orientation_mode = mode
	_rebuild_world_positions()
	_fit_view_to_content(true)


func get_viewport_snapshot() -> Dictionary:
	return {
		"zoom": _zoom,
		"pan": {"x": _pan_offset.x, "y": _pan_offset.y},
		"orientation": _orientation_mode,
		"content_size": {"x": _content_size.x, "y": _content_size.y},
	}


func _fit_view_to_content(mark_user_view: bool) -> void:
	var bounds := _get_world_bounds()
	var graph_size := _get_effective_viewport_size()
	var padded_size := bounds.size + NODE_SIZE + Vector2(120.0, 120.0)
	var zoom_x := graph_size.x / maxf(padded_size.x, 1.0)
	var zoom_y := graph_size.y / maxf(padded_size.y, 1.0)
	_zoom = clampf(minf(zoom_x, zoom_y), MIN_ZOOM, MAX_ZOOM)
	_center_on_world_position(bounds.get_center(), mark_user_view, false, graph_size)
	_layout_location_buttons()
	queue_redraw()
	_emit_viewport_changed()


func _center_on_world_position(world_position: Vector2, mark_user_view: bool, redraw: bool = true, viewport_size: Vector2 = Vector2.ZERO) -> void:
	var target_size := viewport_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = _get_effective_viewport_size()
	_pan_offset = target_size * 0.5 - world_position * _zoom
	if mark_user_view:
		_has_user_view = true
	if redraw:
		_layout_location_buttons()
		queue_redraw()
		_emit_viewport_changed()


func _get_effective_viewport_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	return RADIAL_CONTENT_SIZE


func _schedule_post_layout_refresh() -> void:
	if _render_layout_refresh_pending:
		return
	_render_layout_refresh_pending = true
	call_deferred("_run_post_layout_refresh")


func _run_post_layout_refresh() -> void:
	_render_layout_refresh_pending = false
	if not is_inside_tree():
		return
	if not _has_user_view:
		_fit_view_to_content(false)
	else:
		_layout_location_buttons()
		queue_redraw()


func _get_world_bounds() -> Rect2:
	if _world_positions_by_id.is_empty():
		return Rect2(Vector2.ZERO, _content_size)
	var first := true
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for position_value in _world_positions_by_id.values():
		if not position_value is Vector2:
			continue
		var pos_vec: Vector2 = position_value
		if first:
			bounds = Rect2(pos_vec, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(pos_vec)
	if first:
		return Rect2(Vector2.ZERO, _content_size)
	return bounds


func _zoom_about(anchor: Vector2, target_zoom: float, mark_user_view: bool) -> void:
	var old_zoom := _zoom
	var new_zoom := clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var anchor_world := _screen_to_world(anchor)
	_zoom = new_zoom
	_pan_offset = anchor - anchor_world * _zoom
	if mark_user_view:
		_has_user_view = true
	_layout_location_buttons()
	queue_redraw()
	_emit_viewport_changed()


func _gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		_handle_mouse_button(mouse_button)
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null:
		_handle_mouse_motion(mouse_motion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_about(event.position, _zoom * ZOOM_STEP, true)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_about(event.position, _zoom / ZOOM_STEP, true)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
		_is_panning = event.pressed
		if _is_panning:
			mouse_default_cursor_shape = Control.CURSOR_DRAG
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_panning:
		return
	_pan_offset += event.relative
	_has_user_view = true
	_layout_location_buttons()
	queue_redraw()
	_emit_viewport_changed()
	accept_event()


func _emit_viewport_changed() -> void:
	viewport_changed.emit(get_viewport_snapshot())


func _on_location_button_pressed(location_id: String) -> void:
	location_selected.emit(location_id)


func _on_resized() -> void:
	if not _has_user_view:
		_fit_view_to_content(false)
	_layout_location_buttons()
	queue_redraw()
	_emit_viewport_changed()
