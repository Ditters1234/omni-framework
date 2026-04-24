extends GutTest

const TEST_TICK_HOOK_PATH := "res://tests/fixtures/hooks/test_part_tick_hook.gd"
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

var _original_config: Dictionary = {}


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	AIManager.initialize()
	TimeKeeper.stop()
	GameEvents.clear_event_history()
	_original_config = DataManager.config.duplicate(true)


func after_each() -> void:
	DataManager.config = _original_config.duplicate(true)
	TimeKeeper.stop()


func test_stop_preserves_tick_position_for_correct_next_day_rollover() -> void:
	GameState.current_tick = 23
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()

	TimeKeeper.stop()

	assert_eq(TimeKeeper.get_ticks_into_day(), 23)

	TimeKeeper.advance_tick()

	assert_eq(GameState.current_tick, 24)
	assert_eq(GameState.current_day, 2)
	assert_eq(TimeKeeper.get_ticks_into_day(), 0)


func test_sync_from_game_state_normalizes_current_day_from_current_tick() -> void:
	GameState.current_tick = 49
	GameState.current_day = 1

	TimeKeeper.sync_from_game_state()

	assert_eq(GameState.current_day, 3)
	assert_push_warning("TimeKeeper: resynchronized GameState.current_day")
	assert_eq(TimeKeeper.get_ticks_into_day(), 1)

	var snapshot := TimeKeeper.get_debug_snapshot()
	assert_eq(int(snapshot.get("expected_day", 0)), 3)
	assert_true(bool(snapshot.get("is_time_consistent", false)))


func test_invalid_ticks_per_day_falls_back_to_default_clock_contract() -> void:
	var game_config_data: Variant = DataManager.config.get("game", {})
	var game_config: Dictionary = {}
	if game_config_data is Dictionary:
		game_config = game_config_data.duplicate(true)
	game_config["ticks_per_day"] = 0
	DataManager.config["game"] = game_config

	GameState.current_tick = 23
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()
	TimeKeeper.advance_tick()

	assert_eq(TimeKeeper.get_ticks_per_day(), TimeKeeper.TICKS_PER_DAY)
	assert_push_warning("TimeKeeper: invalid game.ticks_per_day value '0'")
	assert_eq(GameState.current_tick, 24)
	assert_eq(GameState.current_day, 2)
	assert_eq(TimeKeeper.get_ticks_into_day(), 0)


func test_advance_tick_emits_tick_and_day_events_through_game_events() -> void:
	GameState.current_tick = 23
	GameState.current_day = 1
	TimeKeeper.sync_from_game_state()
	watch_signals(GameEvents)

	TimeKeeper.advance_tick()

	assert_signal_emitted(GameEvents, "tick_advanced")
	assert_signal_emitted(GameEvents, "day_advanced")
	assert_eq(get_signal_parameters(GameEvents, "tick_advanced"), [24])
	assert_eq(get_signal_parameters(GameEvents, "day_advanced"), [2])

	var time_history := GameEvents.get_event_history(10, "time")
	assert_eq(time_history.size(), 2)
	assert_eq(str(time_history[0].get("signal_name", "")), "tick_advanced")
	assert_eq(str(time_history[1].get("signal_name", "")), "day_advanced")


func test_advance_tick_dispatches_on_tick_for_carried_part_hooks() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return

	DataManager.parts["base:test_tick_hook_part"] = {
		"id": "base:test_tick_hook_part",
		"display_name": "Tick Hook Part",
		"tags": ["test_tick_hook"],
		"stats": {},
		"script_path": TEST_TICK_HOOK_PATH,
	}
	var part := PartInstance.from_template(DataManager.get_part("base:test_tick_hook_part"))
	part.instance_id = "base:test_tick_hook_part:001"
	player.add_part(part)
	GameState.set_flag("test_tick_hook_call_count", 0)
	GameState.set_flag("test_tick_hook_last_tick", -1)

	TimeKeeper.advance_tick()

	assert_eq(int(GameState.get_flag("test_tick_hook_call_count", 0)), 1)
	assert_eq(int(GameState.get_flag("test_tick_hook_last_tick", -1)), GameState.current_tick)
