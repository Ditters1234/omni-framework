extends GutTest

const ASSEMBLY_EDITOR_SCENE := preload("res://ui/screens/backends/assembly_editor_screen.tscn")

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


func test_assembly_editor_screen_instantiate_and_initialize_without_runtime_errors() -> void:
	var instance_value: Variant = ASSEMBLY_EDITOR_SCENE.instantiate()
	assert_true(instance_value is Control)
	var screen: Control = instance_value
	_spawned_screens.append(screen)
	get_tree().root.add_child(screen)
	screen.call("initialize", {
		"target_entity_id": "player",
		"screen_title": "Character Loadout",
		"confirm_label": "Done",
		"cancel_label": "Back",
	})
	await get_tree().process_frame
	assert_true(screen.is_inside_tree())
