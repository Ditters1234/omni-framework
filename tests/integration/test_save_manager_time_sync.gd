extends GutTest


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	TimeKeeper.stop()


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
