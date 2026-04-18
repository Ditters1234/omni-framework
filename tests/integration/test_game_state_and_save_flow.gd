extends GutTest

const TEST_SAVE_DIR := "user://test_saves/test_game_state_and_save_flow/"


func before_each() -> void:
	_prepare_test_save_directory()
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()


func after_each() -> void:
	_clear_directory(TEST_SAVE_DIR)
	SaveManager.reset_save_directory_for_testing()


func test_player_currency_is_owned_by_player_entity() -> void:
	assert_true(GameState.player != null)
	assert_eq(GameState.get_currency("credits"), 100.0)

	GameState.add_currency("credits", 25.0)

	assert_eq(GameState.get_currency("credits"), 125.0)
	assert_eq(GameState.player.get_currency("credits"), 125.0)


func test_save_round_trip_restores_game_state() -> void:
	GameState.player.set_stat("health", 40.0)
	GameState.add_currency("credits", 25.0)
	GameState.set_flag("debug_test_flag", true)
	GameState.current_tick = 31
	GameState.current_day = 2

	SaveManager.save_game(1)

	GameState.player.set_stat("health", 1.0)
	GameState.spend_currency("credits", 100.0)
	GameState.set_flag("debug_test_flag", false)
	GameState.current_tick = 0
	GameState.current_day = 1

	SaveManager.load_game(1)

	assert_eq(GameState.player.get_stat("health"), 40.0)
	assert_eq(GameState.get_currency("credits"), 125.0)
	assert_eq(GameState.get_flag("debug_test_flag", null), true)
	assert_eq(GameState.current_tick, 31)
	assert_eq(GameState.current_day, 2)


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
