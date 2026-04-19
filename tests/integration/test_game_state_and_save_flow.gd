extends GutTest

const SAVE_SLOT_GAME_STATE_FLOW: int = 3

func before_each():
	ModLoader.load_all_mods()
	GameState.new_game()

func _starting_player_template() -> Dictionary:
	var player_id := str(DataManager.get_config_value("game.starting_player_id", ""))
	return DataManager.get_entity(player_id)

func _primary_currency_id() -> String:
	var template := _starting_player_template()
	var currencies_value: Variant = template.get("currencies", {})
	if currencies_value is Dictionary:
		var currencies: Dictionary = currencies_value
		if currencies.has("credits"):
			return "credits"
		var keys := currencies.keys()
		if not keys.is_empty():
			return str(keys[0])
	return "credits"

func test_player_currency_is_owned_by_player_entity():
	var player := GameState.player as EntityInstance
	var template := _starting_player_template()
	var currencies: Dictionary = template.get("currencies", {})
	for currency_id_value in currencies.keys():
		var currency_id := str(currency_id_value)
		assert_eq(
			player.get_currency(currency_id),
			float(currencies.get(currency_id, 0.0))
		)

func test_save_round_trip_restores_game_state():
	var player := GameState.player as EntityInstance
	var currency_id := _primary_currency_id()
	var starting_amount := player.get_currency(currency_id)

	player.add_currency(currency_id, 25)
	SaveManager.save_game(SAVE_SLOT_GAME_STATE_FLOW)
	player.add_currency(currency_id, 1000)
	SaveManager.load_game(SAVE_SLOT_GAME_STATE_FLOW)

	assert_eq(
		(GameState.player as EntityInstance).get_currency(currency_id),
		starting_amount + 25.0
	)
