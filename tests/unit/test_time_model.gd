extends GutTest

const TIME_MODEL := preload("res://systems/time_model.gd")

var _original_config: Dictionary = {}
var _original_tick: int = 0
var _original_day: int = 1


func before_each() -> void:
	_original_config = DataManager.config.duplicate(true)
	_original_tick = GameState.current_tick
	_original_day = GameState.current_day
	DataManager.config = {}
	GameState.current_tick = 0
	GameState.current_day = 1


func after_each() -> void:
	DataManager.config = _original_config.duplicate(true)
	GameState.current_tick = _original_tick
	GameState.current_day = _original_day


func test_tick_and_day_resolution_uses_arbitrary_ticks_per_day() -> void:
	DataManager.config = {
		"game": {
			"ticks_per_day": 10,
		},
	}
	GameState.current_tick = 27

	assert_eq(TIME_MODEL.get_ticks_per_day(), 10)
	assert_eq(TIME_MODEL.get_current_absolute_tick(), 27)
	assert_eq(TIME_MODEL.get_day_for_absolute_tick(27), 3)
	assert_eq(TIME_MODEL.get_tick_of_day(), 7)
	assert_eq(TIME_MODEL.get_absolute_tick(4, 2), 32)
	assert_eq(TIME_MODEL.format_time(5), "12:00")


func test_weekday_cycle_uses_configured_week_length_and_start_day() -> void:
	DataManager.config = {
		"calendar": {
			"weekdays": ["Alpha", "Beta", "Gamma"],
			"starting_absolute_day": 2,
		},
	}

	assert_eq(TIME_MODEL.get_week_length(), 3)
	assert_eq(TIME_MODEL.get_weekday_for_day(2), "Alpha")
	assert_eq(TIME_MODEL.get_weekday_for_day(4), "Gamma")
	assert_eq(TIME_MODEL.get_weekday_for_day(5), "Alpha")
	assert_eq(TIME_MODEL.days_until_weekday("Gamma", 2), 2)
	assert_eq(TIME_MODEL.days_until_weekday("Gamma", 4), 0)
	assert_eq(TIME_MODEL.days_until_weekday("Missing", 4), -1)


func test_month_rollover_and_date_conversion_use_configured_year_shape() -> void:
	DataManager.config = {
		"calendar": {
			"weekdays": ["First"],
			"months": [
				{"month_id": "dawn", "display_name": "Dawn", "days": 2, "tags": ["season:bright"]},
				{"month_id": "dusk", "display_name": "Dusk", "days": 3, "tags": ["season:dim"]},
			],
			"starting_year": 7,
			"starting_absolute_day": 1,
			"date_format": "Y{year} {month_id} {day_2}",
		},
	}

	var day_three_date := TIME_MODEL.absolute_day_to_date(3)

	assert_eq(TIME_MODEL.get_year_length(), 5)
	assert_eq(str(day_three_date.get("month_id", "")), "dusk")
	assert_eq(int(day_three_date.get("day_of_month", 0)), 1)
	assert_eq(int(TIME_MODEL.absolute_day_to_date(6).get("year", 0)), 8)
	assert_eq(str(TIME_MODEL.absolute_day_to_date(6).get("month_id", "")), "dawn")
	assert_eq(TIME_MODEL.get_month_days("dusk"), 3)
	assert_eq(TIME_MODEL.get_month_tags("dawn"), ["season:bright"])
	assert_eq(TIME_MODEL.date_to_absolute_day(8, "dusk", 2), 9)
	assert_eq(TIME_MODEL.format_date(3), "Y7 dusk 01")


func test_day_start_offset_changes_display_day_without_rewriting_absolute_time() -> void:
	DataManager.config = {
		"game": {
			"ticks_per_day": 10,
		},
		"calendar": {
			"day_start_tick": 3,
		},
	}
	GameState.current_tick = 12
	GameState.current_day = 2

	assert_eq(TIME_MODEL.get_day_for_absolute_tick(GameState.current_tick), 2)
	assert_eq(TIME_MODEL.get_tick_of_day(), 2)
	assert_eq(TIME_MODEL.get_display_day(), 1)
	assert_eq(GameState.current_day, 2)
	assert_eq(TIME_MODEL.get_display_day(2, 3), 2)
