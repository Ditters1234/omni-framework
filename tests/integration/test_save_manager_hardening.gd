
extends GutTest
const Fixture = preload("res://tests/helpers/test_fixture_world.gd")
const SAVE_SLOT_HARDENING: int = 5

func before_each():
	Fixture.seed()
	GameState.new_game()

func test_failed_load_restores_previous_runtime_state():
	var player = GameState.player as EntityInstance
	player.add_currency("gold", 15)
	var before = player.get_currency("gold")
	SaveManager._simulate_invalid_load = true
	SaveManager.load_game(SAVE_SLOT_HARDENING)
	assert_eq((GameState.player as EntityInstance).get_currency("gold"), before)


func test_save_directory_is_isolated_while_running_gut() -> void:
	SaveManager._is_test_environment = false
	SaveManager._save_dir = SaveManager.DEFAULT_SAVE_DIR
	SaveManager._test_session_save_dir = ""

	var save_dir := SaveManager.get_save_directory()

	assert_true(save_dir.begins_with(SaveManager.TEST_SAVE_DIR_PREFIX))
	assert_ne(save_dir, SaveManager.DEFAULT_SAVE_DIR)
