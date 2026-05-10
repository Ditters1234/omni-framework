## TimeModel - Stateless interpretation helpers for Omni game time.
## Time advancement remains owned by TimeKeeper.
extends RefCounted

class_name TimeModel

const DEFAULT_TICKS_PER_DAY := 24
const DEFAULT_WEEKDAYS: Array[String] = ["Day"]
const DEFAULT_MONTH_ID := "month"
const DEFAULT_MONTH_NAME := "Month"
const DEFAULT_MONTH_DAYS := 30
const DEFAULT_STARTING_YEAR := 1
const DEFAULT_STARTING_ABSOLUTE_DAY := 1
const DEFAULT_TIME_FORMAT := "{hour_24}:{minute_2}"
const DEFAULT_DATE_FORMAT := "{weekday}, {month} {day}, Year {year}"


static func get_ticks_per_day() -> int:
	var configured_value: Variant = DataManager.get_config_value("game.ticks_per_day", DEFAULT_TICKS_PER_DAY)
	if _is_integral_number(configured_value) and int(configured_value) >= 1:
		return int(configured_value)
	return DEFAULT_TICKS_PER_DAY


static func get_current_absolute_tick() -> int:
	return maxi(GameState.current_tick, 0)


static func get_absolute_tick(day: int = -1, tick_of_day: int = -1) -> int:
	if day < 1 and tick_of_day < 0:
		return get_current_absolute_tick()
	var ticks_per_day := get_ticks_per_day()
	var resolved_day := day
	if resolved_day < 1:
		resolved_day = get_day_for_absolute_tick(get_current_absolute_tick())
	var resolved_tick := tick_of_day
	if resolved_tick < 0:
		resolved_tick = get_tick_of_day(get_current_absolute_tick())
	resolved_tick = clampi(resolved_tick, 0, ticks_per_day - 1)
	return ((resolved_day - 1) * ticks_per_day) + resolved_tick


static func get_day_for_absolute_tick(absolute_tick: int) -> int:
	var normalized_tick := maxi(absolute_tick, 0)
	var ticks_per_day := get_ticks_per_day()
	return floori(float(normalized_tick) / float(ticks_per_day)) + 1


static func get_tick_of_day(absolute_tick: int = -1) -> int:
	var normalized_tick := get_current_absolute_tick() if absolute_tick < 0 else maxi(absolute_tick, 0)
	return posmod(normalized_tick, get_ticks_per_day())


static func get_display_day(day: int = -1, tick_of_day: int = -1) -> int:
	var resolved_day := day
	var resolved_tick := tick_of_day
	if resolved_day < 1 or resolved_tick < 0:
		var absolute_tick := get_current_absolute_tick()
		resolved_day = get_day_for_absolute_tick(absolute_tick)
		resolved_tick = get_tick_of_day(absolute_tick)
	var day_start_tick := _get_day_start_tick()
	if day_start_tick > 0 and resolved_tick < day_start_tick and resolved_day > 1:
		return resolved_day - 1
	return maxi(resolved_day, 1)


static func get_weekdays() -> Array[String]:
	var weekdays_value: Variant = DataManager.get_config_value("calendar.weekdays", DEFAULT_WEEKDAYS)
	if not weekdays_value is Array:
		return DEFAULT_WEEKDAYS.duplicate()
	var weekdays: Array = weekdays_value
	var normalized: Array[String] = []
	for weekday_value in weekdays:
		if not weekday_value is String:
			continue
		var weekday := str(weekday_value).strip_edges()
		if weekday.is_empty():
			continue
		normalized.append(weekday)
	if normalized.is_empty():
		return DEFAULT_WEEKDAYS.duplicate()
	return normalized


static func get_week_length() -> int:
	return get_weekdays().size()


static func get_current_weekday() -> String:
	return get_weekday_for_day(get_display_day())


static func get_weekday_for_day(day: int) -> String:
	var weekdays := get_weekdays()
	var starting_day := _get_starting_absolute_day()
	var offset := day - starting_day
	var index := posmod(offset, weekdays.size())
	return weekdays[index]


static func get_months() -> Array[Dictionary]:
	var months_value: Variant = DataManager.get_config_value("calendar.months", [])
	if not months_value is Array:
		return _get_default_months()
	var months: Array = months_value
	var normalized: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for month_value in months:
		if not month_value is Dictionary:
			continue
		var month_data: Dictionary = month_value
		var month_id := str(month_data.get("month_id", "")).strip_edges()
		if month_id.is_empty() or seen_ids.has(month_id):
			continue
		var days_value: Variant = month_data.get("days", 0)
		if not _is_integral_number(days_value) or int(days_value) < 1:
			continue
		var display_name := str(month_data.get("display_name", month_id)).strip_edges()
		if display_name.is_empty():
			display_name = month_id
		var tags := _normalize_string_array(month_data.get("tags", []))
		normalized.append({
			"month_id": month_id,
			"display_name": display_name,
			"days": int(days_value),
			"tags": tags,
		})
		seen_ids[month_id] = true
	if normalized.is_empty():
		return _get_default_months()
	return normalized


static func get_month_days(month_id: String) -> int:
	for month in get_months():
		if str(month.get("month_id", "")) == month_id:
			return int(month.get("days", DEFAULT_MONTH_DAYS))
	return 0


static func get_month_tags(month_id: String) -> Array[String]:
	for month in get_months():
		if str(month.get("month_id", "")) != month_id:
			continue
		return _normalize_string_array(month.get("tags", []))
	return []


static func get_year_length(_year: int = -1) -> int:
	var total := 0
	for month in get_months():
		total += int(month.get("days", 0))
	return maxi(total, 1)


static func absolute_day_to_date(day: int) -> Dictionary:
	var months := get_months()
	var year_length := get_year_length()
	var starting_year := _get_starting_year()
	var starting_day := _get_starting_absolute_day()
	var offset := day - starting_day
	var year_offset := _floor_div(offset, year_length)
	var day_of_year := posmod(offset, year_length)
	var month_start_day := 0
	var resolved_month := months[0]
	for month in months:
		var month_days := int(month.get("days", DEFAULT_MONTH_DAYS))
		if day_of_year < month_start_day + month_days:
			resolved_month = month
			break
		month_start_day += month_days
	var day_of_month := (day_of_year - month_start_day) + 1
	var tags := _normalize_string_array(resolved_month.get("tags", []))
	return {
		"absolute_day": day,
		"year": starting_year + year_offset,
		"month_id": str(resolved_month.get("month_id", DEFAULT_MONTH_ID)),
		"month_name": str(resolved_month.get("display_name", DEFAULT_MONTH_NAME)),
		"month": str(resolved_month.get("display_name", DEFAULT_MONTH_NAME)),
		"month_tags": tags,
		"day_of_month": day_of_month,
		"day": day_of_month,
		"weekday": get_weekday_for_day(day),
	}


static func date_to_absolute_day(year: int, month_id: String, day_of_month: int) -> int:
	var months := get_months()
	var starting_year := _get_starting_year()
	var starting_day := _get_starting_absolute_day()
	var year_offset := maxi(year - starting_year, 0)
	var absolute_day := starting_day + (year_offset * get_year_length(year))
	for month in months:
		var current_month_id := str(month.get("month_id", ""))
		var month_days := int(month.get("days", DEFAULT_MONTH_DAYS))
		if current_month_id == month_id:
			var resolved_day := clampi(day_of_month, 1, month_days)
			return absolute_day + resolved_day - 1
		absolute_day += month_days
	return starting_day


static func format_time(tick_of_day: int = -1) -> String:
	var ticks_per_day := get_ticks_per_day()
	var resolved_tick := get_tick_of_day() if tick_of_day < 0 else clampi(tick_of_day, 0, ticks_per_day - 1)
	var total_minutes := floori(float(resolved_tick) * (1440.0 / float(ticks_per_day)))
	var hour := floori(float(total_minutes) / 60.0)
	var minute := total_minutes % 60
	var format := _get_string_config("calendar.time_format", DEFAULT_TIME_FORMAT)
	return format.replace("{hour_24}", str(hour)).replace("{hour_24_2}", str(hour).pad_zeros(2)).replace("{minute_2}", str(minute).pad_zeros(2)).replace("{tick}", str(resolved_tick))


static func format_date(day: int = -1) -> String:
	var resolved_day := get_display_day() if day < 1 else day
	var date := absolute_day_to_date(resolved_day)
	var format := _get_string_config("calendar.date_format", DEFAULT_DATE_FORMAT)
	return format.replace("{weekday}", str(date.get("weekday", ""))).replace("{month}", str(date.get("month_name", ""))).replace("{month_id}", str(date.get("month_id", ""))).replace("{day}", str(date.get("day_of_month", 0))).replace("{day_2}", str(date.get("day_of_month", 0)).pad_zeros(2)).replace("{year}", str(date.get("year", 0))).replace("{absolute_day}", str(date.get("absolute_day", 0)))


static func format_datetime(day: int = -1, tick_of_day: int = -1) -> String:
	return "%s %s" % [format_date(day), format_time(tick_of_day)]


static func days_until_weekday(target_weekday: String, from_day: int = -1) -> int:
	var weekdays := get_weekdays()
	var target_index := weekdays.find(target_weekday)
	if target_index < 0:
		return -1
	var resolved_day := get_display_day() if from_day < 1 else from_day
	var current_weekday := get_weekday_for_day(resolved_day)
	var current_index := weekdays.find(current_weekday)
	if current_index < 0:
		return -1
	return posmod(target_index - current_index, weekdays.size())


static func _get_day_start_tick() -> int:
	var ticks_per_day := get_ticks_per_day()
	var day_start_value: Variant = DataManager.get_config_value("calendar.day_start_tick", 0)
	if _is_integral_number(day_start_value):
		return clampi(int(day_start_value), 0, ticks_per_day - 1)
	return 0


static func _get_starting_year() -> int:
	var value: Variant = DataManager.get_config_value("calendar.starting_year", DEFAULT_STARTING_YEAR)
	if _is_integral_number(value) and int(value) >= 1:
		return int(value)
	return DEFAULT_STARTING_YEAR


static func _get_starting_absolute_day() -> int:
	var value: Variant = DataManager.get_config_value("calendar.starting_absolute_day", DEFAULT_STARTING_ABSOLUTE_DAY)
	if _is_integral_number(value) and int(value) >= 1:
		return int(value)
	return DEFAULT_STARTING_ABSOLUTE_DAY


static func _get_string_config(key_path: String, default_value: String) -> String:
	var value: Variant = DataManager.get_config_value(key_path, default_value)
	if value is String and not str(value).strip_edges().is_empty():
		return str(value)
	return default_value


static func _get_default_months() -> Array[Dictionary]:
	var months: Array[Dictionary] = []
	months.append({
		"month_id": DEFAULT_MONTH_ID,
		"display_name": DEFAULT_MONTH_NAME,
		"days": DEFAULT_MONTH_DAYS,
		"tags": [],
	})
	return months


static func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		if not entry is String:
			continue
		var normalized := str(entry).strip_edges()
		if not normalized.is_empty():
			result.append(normalized)
	return result


static func _floor_div(numerator: int, denominator: int) -> int:
	var safe_denominator := maxi(denominator, 1)
	return floori(float(numerator) / float(safe_denominator))


static func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value := float(value)
		return is_equal_approx(numeric_value, roundf(numeric_value))
	return false
