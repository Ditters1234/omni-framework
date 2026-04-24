extends GutTest

const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

var _screen_container: CanvasLayer = null
var _test_viewport: SubViewport = null


func before_each() -> void:
	GameEvents.clear_event_history()
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	_screen_container = CanvasLayer.new()
	_test_viewport = _create_test_viewport()
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("test_action_push_screen", TEST_SCREEN_SCENE)


func after_each() -> void:
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	if is_instance_valid(_screen_container):
		_screen_container.free()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null


func test_emit_signal_forwards_args_positionally() -> void:
	watch_signals(GameEvents)

	ActionDispatcher.dispatch({
		"type": "emit_signal",
		"signal_name": "notification_requested",
		"args": ["Hello world", OmniConstants.NOTIFICATION_LEVEL_WARN]
	})

	assert_signal_emitted(GameEvents, "notification_requested")
	assert_eq(
		get_signal_parameters(GameEvents, "notification_requested"),
		["Hello world", OmniConstants.NOTIFICATION_LEVEL_WARN]
	)


func test_push_screen_routes_through_ui_router_with_params() -> void:
	ActionDispatcher.dispatch({
		"type": "push_screen",
		"screen_id": "test_action_push_screen",
		"params": {
			"source": "action_payload",
			"nested": {"value": 7},
		},
	})

	assert_eq(UIRouter.current_screen_id(), "test_action_push_screen")
	assert_eq(UIRouter.stack_depth(), 1)

	var stack_snapshot := UIRouter.get_stack_snapshot()
	assert_eq(stack_snapshot.size(), 1)
	assert_eq(str(stack_snapshot[0].get("screen_id", "")), "test_action_push_screen")

	var child_value: Variant = _screen_container.get_child(0)
	var screen := child_value as Control
	assert_not_null(screen)
	if screen != null:
		var initialize_calls_value: Variant = screen.get("initialize_calls")
		assert_true(initialize_calls_value is Array)
		var initialize_calls: Array = initialize_calls_value
		assert_eq(initialize_calls.size(), 1)
		var params_value: Variant = initialize_calls[0]
		assert_true(params_value is Dictionary)
		var params: Dictionary = params_value
		assert_eq(str(params.get("source", "")), "action_payload")
		var nested_value: Variant = params.get("nested", {})
		assert_true(nested_value is Dictionary)
		var nested: Dictionary = nested_value
		assert_eq(int(nested.get("value", 0)), 7)


func test_learn_recipe_sets_the_documented_learned_flag_on_the_player() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.recipes["base:test_recipe"] = {
		"recipe_id": "base:test_recipe",
		"display_name": "Test Recipe",
		"output_template_id": "base:body_arm_standard",
		"inputs": [{"template_id": "base:body_arm_standard", "count": 1}],
	}

	ActionDispatcher.dispatch({
		"type": "learn_recipe",
		"recipe_id": "base:test_recipe",
	})

	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player != null:
		assert_true(player.has_flag("learned:base:test_recipe"))


func test_modify_reputation_updates_runtime_state_and_emits_the_new_event() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return

	watch_signals(GameEvents)
	ActionDispatcher.dispatch({
		"type": "modify_reputation",
		"entity_id": "player",
		"faction_id": "base:test_faction",
		"amount": 5,
	})

	assert_eq(player.get_reputation("base:test_faction"), 5.0)
	assert_signal_emitted(GameEvents, "entity_reputation_changed")
	assert_eq(
		get_signal_parameters(GameEvents, "entity_reputation_changed"),
		[player.entity_id, "base:test_faction", 0.0, 5.0]
	)

	ActionDispatcher.dispatch({
		"type": "remove_reputation",
		"entity_id": "player",
		"faction_id": "base:test_faction",
		"amount": 2,
	})

	assert_eq(player.get_reputation("base:test_faction"), 3.0)


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestActionDispatcherViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
