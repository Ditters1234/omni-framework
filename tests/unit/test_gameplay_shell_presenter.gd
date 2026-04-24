extends GutTest

const GAMEPLAY_SHELL_PRESENTER := preload("res://ui/screens/gameplay_shell/gameplay_shell_presenter.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

var _presenter: RefCounted = null


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_data_fixture()
	_presenter = GAMEPLAY_SHELL_PRESENTER.new()


func test_build_view_model_without_session_returns_disabled_shell_state() -> void:
	var view_model_value: Variant = _presenter.call("build_view_model", "Ignored")
	var view_model: Dictionary = {}
	if view_model_value is Dictionary:
		view_model = view_model_value

	assert_false(bool(view_model.get("has_session", true)))
	assert_false(bool(view_model.get("buttons_enabled", true)))
	assert_eq(
		str(view_model.get("status_text", "")),
		"The gameplay shell becomes available once a runtime session exists."
	)
	assert_eq(str(view_model.get("time_text", "")), "")
	assert_eq(str(view_model.get("autosave_summary", "")), "")

	var location_value: Variant = view_model.get("location", {})
	assert_true(location_value is Dictionary)
	var location: Dictionary = location_value
	assert_eq(str(location.get("title_text", "")), "No Active Session")

	var player_value: Variant = view_model.get("player", {})
	assert_true(player_value is Dictionary)
	var player: Dictionary = player_value
	assert_true(player.has("portrait"))
	assert_true(player.has("stat_sheet"))
	assert_true(player.has("equipped_parts"))


func test_build_view_model_with_session_exposes_player_location_and_time_controls() -> void:
	GameState.new_game()

	var player := GameState.player as EntityInstance
	assert_not_null(player)

	var view_model_value: Variant = _presenter.call("build_view_model", "Ready.")
	var view_model: Dictionary = {}
	if view_model_value is Dictionary:
		view_model = view_model_value

	assert_true(bool(view_model.get("has_session", false)))
	assert_true(bool(view_model.get("buttons_enabled", false)))
	assert_eq(str(view_model.get("status_text", "")), "Ready.")
	assert_true(str(view_model.get("time_text", "")).begins_with("Time: "))
	assert_true(str(view_model.get("autosave_summary", "")).contains("Autosave"))

	var time_specs_value: Variant = view_model.get("time_button_specs", [])
	assert_true(time_specs_value is Array)
	var time_specs: Array = time_specs_value
	assert_gt(time_specs.size(), 0)

	var player_value: Variant = view_model.get("player", {})
	assert_true(player_value is Dictionary)
	var player_view_model: Dictionary = player_value
	assert_eq(str(player_view_model.get("entity_id", "")), player.entity_id)
	assert_true(str(player_view_model.get("display_name", "")).length() > 0)

	var portrait_value: Variant = player_view_model.get("portrait", {})
	assert_true(portrait_value is Dictionary)
	var portrait: Dictionary = portrait_value
	assert_true(str(portrait.get("display_name", "")).length() > 0)

	var location_value: Variant = view_model.get("location", {})
	assert_true(location_value is Dictionary)
	var location: Dictionary = location_value
	assert_true(str(location.get("id", "")).length() > 0)
	assert_true(str(location.get("title_text", "")).length() > 0)
