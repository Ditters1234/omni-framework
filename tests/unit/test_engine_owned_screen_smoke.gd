extends GutTest

const SCREEN_CASES := [
	{
		"scene_path": "res://ui/screens/main_menu/main_menu_screen.tscn",
		"params": {},
	},
	{
		"scene_path": "res://ui/screens/settings/settings_screen.tscn",
		"params": {},
	},
	{
		"scene_path": "res://ui/screens/save_slot_list/save_slot_list_screen.tscn",
		"params": {
			"mode": "save",
			"close_on_save": false,
		},
	},
	{
		"scene_path": "res://ui/screens/credits/credits_screen.tscn",
		"params": {},
	},
	{
		"scene_path": "res://ui/screens/pause_menu/pause_menu_screen.tscn",
		"params": {},
	},
	{
		"scene_path": "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn",
		"params": {},
	},
	{
		"scene_path": "res://ui/screens/location_view/location_view_screen.tscn",
		"params": {},
	},
]

var _spawned_screens: Array[Control] = []


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()


func after_each() -> void:
	for screen in _spawned_screens:
		if screen == null or not is_instance_valid(screen):
			continue
		screen.queue_free()
	_spawned_screens.clear()
	await get_tree().process_frame


func test_engine_owned_screens_instantiate_and_initialize_without_runtime_errors() -> void:
	for screen_case_value in SCREEN_CASES:
		assert_true(screen_case_value is Dictionary)
		var screen_case: Dictionary = screen_case_value
		var scene_path := str(screen_case.get("scene_path", ""))
		var packed_value: Variant = load(scene_path)
		assert_true(packed_value is PackedScene)
		var packed_scene: PackedScene = packed_value
		var instance_value: Variant = packed_scene.instantiate()
		assert_true(instance_value is Control)
		var screen: Control = instance_value
		_spawned_screens.append(screen)
		get_tree().root.add_child(screen)
		var params_value: Variant = screen_case.get("params", {})
		var params: Dictionary = {}
		if params_value is Dictionary:
			params = params_value
		if screen.has_method("initialize"):
			screen.call("initialize", params.duplicate(true))
		await get_tree().process_frame
		assert_true(screen.is_inside_tree())
