extends GutTest

const ASSEMBLY_EDITOR_SCENE := preload("res://ui/screens/backends/assembly_editor_screen.tscn")

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


func test_assembly_editor_screen_instantiate_and_initialize_without_runtime_errors() -> void:
	var instance_value: Variant = ASSEMBLY_EDITOR_SCENE.instantiate()
	assert_true(instance_value is Control)
	var screen: Control = instance_value
	_spawned_screens.append(screen)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(screen)
	screen.call("initialize", {
		"target_entity_id": "player",
		"screen_title": "Character Loadout",
		"confirm_label": "Done",
		"cancel_label": "Back",
	})
	await get_tree().process_frame
	assert_true(screen.is_inside_tree())


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestBackendScreenViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
