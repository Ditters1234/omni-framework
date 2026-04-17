## TimeKeeper — Tick clock for the game world.
## Advances ticks either in real-time (via a Timer) or manually.
## Dispatches tick_advanced and day_advanced signals through GameEvents.
extends Node

class_name OmniTimeKeeper

const DEFAULT_TICK_RATE := 1.0   # seconds per tick (real time)
const TICKS_PER_DAY := 24        # game ticks that make one in-game day

## Current tick rate in seconds. Modifiable at runtime (e.g. pause, fast-forward).
var tick_rate: float = DEFAULT_TICK_RATE

## Whether the clock is currently running.
var is_running: bool = false

var _timer: Timer = null
var _tick_accumulator: int = 0   # ticks elapsed in the current day

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_rate
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)


# ---------------------------------------------------------------------------
# Control
# ---------------------------------------------------------------------------

## Starts the tick clock.
func start() -> void:
	is_running = true
	_timer.start()


## Pauses the tick clock without resetting accumulators.
func pause() -> void:
	is_running = false
	_timer.stop()


## Resumes a paused clock.
func resume() -> void:
	if is_running:
		return
	is_running = true
	_timer.start()


## Stops the clock and resets accumulators to zero.
func stop() -> void:
	is_running = false
	_tick_accumulator = 0
	_timer.stop()


## Sets a new tick rate. Takes effect on the next tick.
func set_tick_rate(seconds: float) -> void:
	tick_rate = maxf(seconds, 0.01)
	_timer.wait_time = tick_rate


## Manually advances the clock by one tick (useful for testing / cutscenes).
func advance_tick() -> void:
	GameState.current_tick += 1
	_tick_accumulator += 1
	_emit_tick(GameState.current_tick)

	var ticks_per_day := int(DataManager.get_config_value("game.ticks_per_day", TICKS_PER_DAY))
	if ticks_per_day > 0 and _tick_accumulator >= ticks_per_day:
		_tick_accumulator = 0
		GameState.current_day += 1
		_emit_day(GameState.current_day)


## Manually advances the clock by N ticks.
func advance_ticks(count: int) -> void:
	for _i in range(maxi(count, 0)):
		advance_tick()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_timer_tick() -> void:
	if is_running:
		advance_tick()


func _emit_tick(tick: int) -> void:
	GameEvents.tick_advanced.emit(tick)


func _emit_day(day: int) -> void:
	GameEvents.day_advanced.emit(day)
