extends GutTest

const TEST_SAVE_DIR := "user://test_saves/test_save_manager_time_sync/"


func before_each() -> void:
	_prepare_test_save_directory()
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	TimeKeeper.stop()


func after_each() -> void:
	_clear_directory(TEST_SAVE_DIR)
	SaveManager.reset_save_directory_for_testing()


func test_load_game_resynchronizes_tick_position_within_day() -> void:
	GameState.current_tick = 49
	GameState.current_day = 3
	TimeKeeper.sync_from_game_state()

	SaveManager.save_game(2)

	GameState.current_tick = 0
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()

	assert_true(SaveManager.load_game(2))
	assert_eq(GameState.current_tick, 49)
	assert_eq(GameState.current_day, 3)
	assert_eq(TimeKeeper.get_ticks_into_day(), 1)


func _prepare_test_save_directory() -> void:
	_clear_directory(TEST_SAVE_DIR)
	assert_true(SaveManager.set_save_directory_for_testing(TEST_SAVE_DIR))


func _clear_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while not entry.is_empty():
			if not entry.begins_with("."):
				var child_path := path.path_join(entry)
				if dir.current_is_dir():
					_clear_directory(child_path)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
