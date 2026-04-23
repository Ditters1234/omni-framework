extends GutTest

const WORLD_MAP_GRAPH := preload("res://ui/screens/backends/world_map_graph.gd")


func test_initial_render_before_layout_centers_all_locations_in_fallback_viewport() -> void:
	var graph: Control = WORLD_MAP_GRAPH.new()
	graph.custom_minimum_size = Vector2(720.0, 460.0)

	graph.call("render", {
		"locations": [
			{"location_id": "base:test_hub", "display_name": "Diagnostics Hub", "position": {"x": 0.5, "y": 0.12}},
			{"location_id": "base:hub_safehouse", "display_name": "Safehouse", "position": {"x": 0.5, "y": 0.88}},
		],
		"edges": [
			{"from_id": "base:test_hub", "to_id": "base:hub_safehouse", "travel_cost": 1},
		],
	})

	var buttons_value: Variant = graph.get("_buttons_by_id")
	assert_true(buttons_value is Dictionary)
	if not buttons_value is Dictionary:
		graph.free()
		return
	var buttons: Dictionary = buttons_value
	assert_true(buttons.has("base:test_hub"))
	assert_true(buttons.has("base:hub_safehouse"))

	var viewport_bounds := Rect2(Vector2.ZERO, graph.custom_minimum_size)
	for location_id_value in buttons.keys():
		var button := buttons.get(location_id_value) as Button
		assert_not_null(button)
		if button == null:
			continue
		var button_center := button.position + button.size * 0.5
		assert_true(
			viewport_bounds.has_point(button_center),
			"%s should be centered inside the initial graph viewport." % str(location_id_value)
		)

	graph.free()
