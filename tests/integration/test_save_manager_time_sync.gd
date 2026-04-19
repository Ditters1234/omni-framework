
extends GutTest
const Fixture = preload("res://tests/helpers/test_fixture_world.gd")
const SAVE_SLOT_TIME_SYNC: int = 4

func before_each():
	Fixture.seed()
	GameState.new_game()

func test_load_game_resynchronizes_tick_position_within_day():
	GameState.current_tick = 1234
	SaveManager.save_game(SAVE_SLOT_TIME_SYNC)
	GameState.current_tick = 0
	SaveManager.load_game(SAVE_SLOT_TIME_SYNC)
	assert_true(GameState.current_tick > 0)
