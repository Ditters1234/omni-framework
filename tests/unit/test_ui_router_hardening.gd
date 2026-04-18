extends GutTest


const UI_ROUTER_SCRIPT := preload("res://autoloads/ui_router.gd")
const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const TEST_INVALID_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_invalid_screen.tscn"

var _router: OmniUIRouter = null
var _screen_container: CanvasLayer = null


func before_each() -> void:
	GameEvents.clear_event_history()
	_router = UI_ROUTER_SCRIPT.new()
	_screen_container = CanvasLayer.new()
	get_tree().root.add_child(_screen_container)
	get_tree().root.add_child(_router)


func after_each() -> void:
	if is_instance_valid(_router):
		_router.free()
	if is_instance_valid(_screen_container):
		_screen_container.free()


func test_push_and_pop_manage_visibility_hooks_and_ui_events() -> void:
	_router.initialize(_screen_container)
	_register_default_screens()

	_router.push("first", {"source": "boot"})
	_router.push("second", {"source": "submenu"})

	var first := _get_screen_at(0)
	var second := _get_screen_at(1)
	assert_not_null(first)
	assert_not_null(second)
	assert_false(first.visible)
	assert_true(second.visible)
	assert_eq(int(first.get("hidden_count")), 1)
	assert_eq(int(first.get("revealed_count")), 1)

	var pushed_events := GameEvents.get_event_history(10, "ui", "ui_screen_pushed")
	assert_eq(pushed_events.size(), 2)
	assert_eq(str(pushed_events[0].get("args", [""])[0]), "first")
	assert_eq(str(pushed_events[1].get("args", [""])[0]), "second")

	_router.pop()
	await get_tree().process_frame

	assert_eq(_router.current_screen_id(), "first")
	assert_eq(_router.stack_depth(), 1)
	assert_true(first.visible)
	assert_eq(int(first.get("revealed_count")), 2)
	assert_eq(_screen_container.get_child_count(), 1)

	var popped_events := GameEvents.get_event_history(10, "ui", "ui_screen_popped")
	assert_eq(popped_events.size(), 1)
	assert_eq(str(popped_events[0].get("args", [""])[0]), "second")


func test_replace_all_preserves_current_stack_when_target_route_is_invalid() -> void:
	_router.initialize(_screen_container)
	_register_default_screens()
	_router.push("first", {"seed": 1})

	_router.replace_all("missing")
	assert_push_error("UIRouter: Unknown screen 'missing'.")

	assert_eq(_router.current_screen_id(), "first")
	assert_eq(_router.stack_depth(), 1)
	assert_eq(_screen_container.get_child_count(), 1)

	var popped_events := GameEvents.get_event_history(10, "ui", "ui_screen_popped")
	assert_eq(popped_events.size(), 0)

	var snapshot := _router.get_debug_snapshot()
	var errors_value: Variant = snapshot.get("recent_errors", [])
	assert_true(errors_value is Array)
	var errors: Array = errors_value
	assert_true(_array_contains_text(errors, "Unknown screen 'missing'"))


func test_replace_all_emits_pop_events_for_each_removed_screen() -> void:
	_router.initialize(_screen_container)
	_register_default_screens()

	_router.push("first")
	_router.push("second")
	_router.replace_all("third", {"mode": "reset"})
	await get_tree().process_frame

	assert_eq(_router.current_screen_id(), "third")
	assert_eq(_router.stack_depth(), 1)
	assert_eq(_screen_container.get_child_count(), 1)

	var pushed_events := GameEvents.get_event_history(10, "ui", "ui_screen_pushed")
	var popped_events := GameEvents.get_event_history(10, "ui", "ui_screen_popped")
	assert_eq(pushed_events.size(), 3)
	assert_eq(popped_events.size(), 2)
	assert_eq(str(popped_events[0].get("args", [""])[0]), "second")
	assert_eq(str(popped_events[1].get("args", [""])[0]), "first")


func test_push_requires_initialized_container_and_records_debug_state() -> void:
	_register_default_screens()

	_router.push("first")
	assert_push_error("UIRouter: push('first') called before initialize() set a valid screen container.")

	assert_false(_router.has_screen())
	assert_eq(_router.stack_depth(), 0)

	var snapshot := _router.get_debug_snapshot()
	assert_false(bool(snapshot.get("has_container", true)))
	assert_false(bool(snapshot.get("container_valid", true)))


func test_router_debug_snapshot_tracks_registered_screens_params_and_visibility() -> void:
	_router.initialize(_screen_container)
	_register_default_screens()
	var params := {
		"screen_id": "first",
		"nested": {"value": 7},
	}

	_router.push("first", params)
	params["nested"]["value"] = 99

	var snapshot := _router.get_debug_snapshot()
	assert_eq(int(snapshot.get("registered_screen_count", 0)), 3)
	assert_eq(str(snapshot.get("current_screen_id", "")), "first")
	assert_eq(int(snapshot.get("stack_depth", 0)), 1)

	var current_params_value: Variant = snapshot.get("current_screen_params", {})
	assert_true(current_params_value is Dictionary)
	var current_params: Dictionary = current_params_value
	var nested_value: Variant = current_params.get("nested", {})
	assert_true(nested_value is Dictionary)
	var nested: Dictionary = nested_value
	assert_eq(int(nested.get("value", 0)), 7)

	var stack_value: Variant = snapshot.get("stack", [])
	assert_true(stack_value is Array)
	var stack_entries: Array = stack_value
	assert_eq(stack_entries.size(), 1)
	assert_eq(str(stack_entries[0].get("screen_id", "")), "first")
	assert_true(bool(stack_entries[0].get("visible", false)))

	var screen := _get_screen_at(0)
	assert_not_null(screen)
	var initialize_calls_value: Variant = screen.get("initialize_calls")
	assert_true(initialize_calls_value is Array)
	var initialize_calls: Array = initialize_calls_value
	assert_eq(initialize_calls.size(), 1)
	var recorded_params_value: Variant = initialize_calls[0]
	assert_true(recorded_params_value is Dictionary)
	var recorded_params: Dictionary = recorded_params_value
	var recorded_nested_value: Variant = recorded_params.get("nested", {})
	assert_true(recorded_nested_value is Dictionary)
	var recorded_nested: Dictionary = recorded_nested_value
	assert_eq(int(recorded_nested.get("value", 0)), 7)


func test_registered_scene_must_inherit_control() -> void:
	_router.initialize(_screen_container)
	_router.register_screen("invalid", TEST_INVALID_SCREEN_SCENE)

	_router.push("invalid")
	assert_push_error("UIRouter: Scene 'invalid' at 'res://tests/fixtures/ui_router/test_invalid_screen.tscn' must inherit Control.")

	assert_eq(_router.stack_depth(), 0)


func _register_default_screens() -> void:
	_router.register_screen("first", TEST_SCREEN_SCENE)
	_router.register_screen("second", TEST_SCREEN_SCENE)
	_router.register_screen("third", TEST_SCREEN_SCENE)


func _get_screen_at(index: int) -> Control:
	if index < 0 or index >= _screen_container.get_child_count():
		return null
	var child_value: Variant = _screen_container.get_child(index)
	return child_value as Control


func _array_contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false
