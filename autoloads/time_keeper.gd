## TimeKeeper — Tick clock for the game world.
## Advances ticks either in real-time (via a Timer) or manually.
## Dispatches tick_advanced and day_advanced signals through GameEvents.
extends Node

class_name OmniTimeKeeper

const DEFAULT_TICK_RATE := 1.0   # seconds per tick (real time)
const TICKS_PER_DAY := 24        # game ticks that make one in-game day
const MIN_TICK_RATE := 0.01
const MIN_TICKS_PER_DAY := 1

## Current tick rate in seconds. Modifiable at runtime (e.g. pause, fast-forward).
var tick_rate: float = DEFAULT_TICK_RATE

## Whether the clock is currently running.
var is_running: bool = false

var _timer: Timer = null
var _tick_accumulator: int = 0   # ticks elapsed in the current day
var _task_runner: TaskRunner = null
var _last_invalid_ticks_per_day_warning: String = ""
var _last_time_normalization_warning: String = ""

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_rate
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)
	_task_runner = TaskRunner.new()
	add_child(_task_runner)
	_connect_runtime_signals()
	sync_from_game_state()


# ---------------------------------------------------------------------------
# Control
# ---------------------------------------------------------------------------

## Starts the tick clock.
func start() -> void:
	if _timer == null:
		push_warning("TimeKeeper: cannot start before timer initialization completes.")
		return
	sync_from_game_state()
	is_running = true
	_timer.start()


## Pauses the tick clock without resetting accumulators.
func pause() -> void:
	is_running = false
	if _timer != null:
		_timer.stop()


## Resumes a paused clock.
func resume() -> void:
	if is_running:
		return
	if _timer == null:
		push_warning("TimeKeeper: cannot resume before timer initialization completes.")
		return
	sync_from_game_state()
	is_running = true
	_timer.start()


## Stops the clock and resynchronizes derived time state from GameState.
func stop() -> void:
	is_running = false
	if _timer != null:
		_timer.stop()
	sync_from_game_state()


## Sets a new tick rate. Takes effect on the next tick.
func set_tick_rate(seconds: float) -> void:
	tick_rate = maxf(seconds, MIN_TICK_RATE)
	if _timer != null:
		_timer.wait_time = tick_rate


## Manually advances the clock by one tick (useful for testing / cutscenes).
func advance_tick() -> void:
	var ticks_per_day := _get_ticks_per_day()
	_normalize_game_state_time(ticks_per_day)
	GameState.current_tick += 1
	_tick_accumulator = posmod(_tick_accumulator + 1, ticks_per_day)
	_emit_tick(GameState.current_tick)

	if _tick_accumulator == 0:
		GameState.current_day += 1
		_emit_day(GameState.current_day)


## Manually advances the clock by N ticks.
func advance_ticks(count: int) -> void:
	for _i in range(maxi(count, 0)):
		advance_tick()


func advance_to_next_day() -> void:
	var ticks_per_day := _get_ticks_per_day()
	var remaining := ticks_per_day - _tick_accumulator
	if remaining <= 0:
		remaining = ticks_per_day
	advance_ticks(remaining)


func get_current_tick() -> int:
	return GameState.current_tick


func get_current_day() -> int:
	return GameState.current_day


func get_ticks_into_day() -> int:
	return _tick_accumulator


func get_ticks_per_day() -> int:
	return _get_ticks_per_day()


func get_time_string() -> String:
	var ticks_per_day := _get_ticks_per_day()
	var total_minutes := int(float(_tick_accumulator) * (1440.0 / float(ticks_per_day)))
	@warning_ignore("integer_division")
	var hour := total_minutes / 60
	var minute := total_minutes % 60
	return "Day %d, %02d:%02d" % [GameState.current_day, hour, minute]


func accept_task(template_id: String, params: Dictionary = {}) -> String:
	if _task_runner == null:
		return ""
	return _task_runner.accept_task(template_id, params)


func sync_from_game_state() -> void:
	var ticks_per_day := _get_ticks_per_day()
	_normalize_game_state_time(ticks_per_day)
	_tick_accumulator = posmod(GameState.current_tick, ticks_per_day)


func get_debug_snapshot() -> Dictionary:
	var ticks_per_day := _get_ticks_per_day()
	var normalized_day := _get_normalized_day(GameState.current_tick, ticks_per_day)
	return {
		"is_running": is_running,
		"tick_rate": tick_rate,
		"timer_initialized": _timer != null,
		"timer_stopped": _timer == null or _timer.is_stopped(),
		"current_tick": GameState.current_tick,
		"current_day": GameState.current_day,
		"expected_day": normalized_day,
		"ticks_per_day": ticks_per_day,
		"ticks_into_day": _tick_accumulator,
		"is_time_consistent": GameState.current_day == normalized_day,
		"active_task_count": GameState.active_tasks.size(),
	}


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_timer_tick() -> void:
	if is_running:
		advance_tick()


func _emit_tick(tick: int) -> void:
	if GameEvents == null:
		push_warning("TimeKeeper: GameEvents is unavailable; tick_advanced was not emitted.")
		return
	if GameEvents.has_method("emit_dynamic"):
		GameEvents.emit_dynamic("tick_advanced", [tick])
		return
	GameEvents.tick_advanced.emit(tick)


func _emit_day(day: int) -> void:
	if GameEvents == null:
		push_warning("TimeKeeper: GameEvents is unavailable; day_advanced was not emitted.")
		return
	if GameEvents.has_method("emit_dynamic"):
		GameEvents.emit_dynamic("day_advanced", [day])
		return
	GameEvents.day_advanced.emit(day)


func _connect_runtime_signals() -> void:
	if GameEvents == null:
		return
	var on_game_started := Callable(self, "_on_game_started")
	if GameEvents.has_signal("game_started") and not GameEvents.is_connected("game_started", on_game_started):
		GameEvents.game_started.connect(_on_game_started)
	var on_load_completed := Callable(self, "_on_load_completed")
	if GameEvents.has_signal("load_completed") and not GameEvents.is_connected("load_completed", on_load_completed):
		GameEvents.load_completed.connect(_on_load_completed)


func _on_game_started() -> void:
	sync_from_game_state()


func _on_load_completed(_slot: int) -> void:
	sync_from_game_state()


func _get_ticks_per_day() -> int:
	var configured_value: Variant = DataManager.get_config_value("game.ticks_per_day", TICKS_PER_DAY)
	var ticks_per_day := int(configured_value)
	if ticks_per_day >= MIN_TICKS_PER_DAY:
		_last_invalid_ticks_per_day_warning = ""
		return ticks_per_day
	var warning_key := str(configured_value)
	if warning_key != _last_invalid_ticks_per_day_warning:
		_last_invalid_ticks_per_day_warning = warning_key
		push_warning(
			"TimeKeeper: invalid game.ticks_per_day value '%s'. Falling back to %d." % [
				str(configured_value),
				TICKS_PER_DAY,
			]
		)
	return TICKS_PER_DAY


func _normalize_game_state_time(ticks_per_day: int) -> void:
	if GameState.current_tick < 0:
		var negative_tick_warning := "tick:%d" % GameState.current_tick
		if negative_tick_warning != _last_time_normalization_warning:
			_last_time_normalization_warning = negative_tick_warning
			push_warning(
				"TimeKeeper: GameState.current_tick was negative (%d). Resetting it to 0." % [
					GameState.current_tick
				]
			)
		GameState.current_tick = 0
	var expected_day := _get_normalized_day(GameState.current_tick, ticks_per_day)
	if GameState.current_day == expected_day:
		_last_time_normalization_warning = ""
		return
	var mismatch_warning := "%d:%d:%d" % [GameState.current_tick, GameState.current_day, ticks_per_day]
	if mismatch_warning != _last_time_normalization_warning:
		_last_time_normalization_warning = mismatch_warning
		push_warning(
			"TimeKeeper: resynchronized GameState.current_day from %d to %d using current_tick=%d and ticks_per_day=%d." % [
				GameState.current_day,
				expected_day,
				GameState.current_tick,
				ticks_per_day,
			]
		)
	GameState.current_day = expected_day


func _get_normalized_day(current_tick: int, ticks_per_day: int) -> int:
	@warning_ignore("integer_division")
	return int(current_tick / ticks_per_day) + 1
