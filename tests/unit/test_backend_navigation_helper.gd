extends GutTest

const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const GAMEPLAY_SHELL_SCENE_PATH := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"

var _screen_container: CanvasLayer = null
var _test_viewport: SubViewport = null


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	_screen_container = CanvasLayer.new()
	_test_viewport = _create_test_viewport()
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("first", TEST_SCREEN_SCENE)
	UIRouter.register_screen("second", TEST_SCREEN_SCENE)
	UIRouter.register_screen("third", TEST_SCREEN_SCENE)
	UIRouter.register_screen("gameplay_shell", GAMEPLAY_SHELL_SCENE_PATH)


func after_each() -> void:
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	await get_tree().process_frame
	if is_instance_valid(_screen_container):
		_screen_container.free()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	await get_tree().process_frame
	_test_viewport = null
	GameState.reset()


func test_execute_navigation_action_pushes_and_replaces_normal_stack() -> void:
	UIRouter.push("first")

	var pushed := BACKEND_NAVIGATION_HELPER.execute_navigation_action({
		"type": "push",
		"screen_id": "second",
		"params": {"source": "helper_push"},
	})
	assert_true(pushed)
	assert_eq(UIRouter.current_screen_id(), "second")
	assert_eq(UIRouter.stack_depth(), 2)

	var replaced := BACKEND_NAVIGATION_HELPER.execute_navigation_action({
		"type": "replace_all",
		"screen_id": "third",
		"params": {"source": "helper_replace"},
	})
	assert_true(replaced)
	assert_eq(UIRouter.current_screen_id(), "third")
	assert_eq(UIRouter.stack_depth(), 1)


func test_execute_navigation_action_closes_gameplay_shell_surface_for_shell_pop() -> void:
	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame

	var opened := BACKEND_NAVIGATION_HELPER.execute_navigation_action({
		"type": "push",
		"screen_id": "first",
		"params": {"source": "shell_surface"},
	}, true)
	assert_true(opened)
	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)
	assert_eq(_current_surface_id(), "first")

	var closed := BACKEND_NAVIGATION_HELPER.execute_navigation_action({"type": "pop"}, true)
	assert_true(closed)
	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)
	assert_eq(_current_surface_id(), "location_surface")


func test_execute_navigation_action_can_replace_shell_pop_with_fallback_screen() -> void:
	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame

	var replaced := BACKEND_NAVIGATION_HELPER.execute_navigation_action(
		{"type": "pop"},
		true,
		"third",
		{"source": "shell_cancel"}
	)
	assert_true(replaced)
	assert_eq(UIRouter.current_screen_id(), "third")
	assert_eq(UIRouter.stack_depth(), 1)


func _current_surface_id() -> String:
	var snapshot := UIRouter.get_current_screen_debug_snapshot()
	return str(snapshot.get("active_surface_screen_id", ""))


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestBackendNavigationViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
