extends GutTest

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")

const SCREEN_CASES := [
	{
		"scene_path": UI_ROUTE_CATALOG.MAIN_MENU_SCENE,
		"params": {},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.SETTINGS_SCENE,
		"params": {},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.SAVE_SLOT_LIST_SCENE,
		"params": {
			"mode": "save",
			"close_on_save": false,
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.CREDITS_SCENE,
		"params": {},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.PAUSE_MENU_SCENE,
		"params": {},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.GAMEPLAY_SHELL_SCENE,
		"params": {},
	},
]

var _spawned_screens: Array[Control] = []
var _test_viewport: SubViewport = null


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	_test_viewport = _create_test_viewport()


func after_each() -> void:
	for screen in _spawned_screens:
		if screen == null or not is_instance_valid(screen):
			continue
		screen.queue_free()
	_spawned_screens.clear()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null
	await get_tree().process_frame


func test_engine_owned_screens_instantiate_and_initialize_without_runtime_errors() -> void:
	for screen_case_value in SCREEN_CASES:
		assert_true(screen_case_value is Dictionary)
		var screen_case: Dictionary = screen_case_value
		var scene_path := str(screen_case.get("scene_path", ""))
		if not ResourceLoader.exists(scene_path):
			assert_true(false, "Missing engine-owned screen scene: %s" % scene_path)
			continue
		var packed_value: Variant = load(scene_path)
		assert_true(packed_value is PackedScene)
		if not packed_value is PackedScene:
			continue
		var packed_scene: PackedScene = packed_value
		var instance_value: Variant = packed_scene.instantiate()
		assert_true(instance_value is Control)
		var screen: Control = instance_value
		_spawned_screens.append(screen)
		assert_not_null(_test_viewport)
		_test_viewport.add_child(screen)
		var params_value: Variant = screen_case.get("params", {})
		var params: Dictionary = {}
		if params_value is Dictionary:
			params = params_value
		if screen.has_method("initialize"):
			screen.call("initialize", params.duplicate(true))
		await get_tree().process_frame
		assert_true(screen.is_inside_tree())


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestEngineOwnedScreenViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
