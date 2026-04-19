
extends GutTest
const Fixture = preload("res://tests/helpers/test_fixture_world.gd")
const SAVE_SLOT_GAME_STATE_FLOW: int = 3

func before_each():
	Fixture.seed()
	GameState.new_game()

func test_player_currency_is_owned_by_player_entity():
	var player = GameState.player as EntityInstance
	assert_eq(player.get_currency("gold"), 100)

func test_save_round_trip_restores_game_state():
	var player = GameState.player as EntityInstance
	player.add_currency("gold", 25)
	SaveManager.save_game(SAVE_SLOT_GAME_STATE_FLOW)
	player.add_currency("gold", 1000)
	SaveManager.load_game(SAVE_SLOT_GAME_STATE_FLOW)
	assert_eq((GameState.player as EntityInstance).get_currency("gold"), 125)
