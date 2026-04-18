extends GutTest


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()


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
