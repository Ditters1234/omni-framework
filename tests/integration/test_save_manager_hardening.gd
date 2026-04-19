
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
