## AudioManager — SFX pools and music playback.
## SFX are played from pooled AudioStreamPlayer nodes.
## Music uses a dedicated player with optional cross-fade.
extends Node

class_name OmniAudioManager

const SFX_POOL_SIZE := 8
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const DEFAULT_AUDIO_BUS := "Master"
const SILENT_DB := -80.0
const MIN_LINEAR_VOLUME := 0.0001
const MAX_RECENT_ERRORS := 12

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null

var _master_volume: float = 1.0
var _music_volume: float = 1.0
var _sfx_volume: float = 1.0
var _resolved_music_bus: String = DEFAULT_AUDIO_BUS
var _resolved_sfx_bus: String = DEFAULT_AUDIO_BUS
var _current_music_path: String = ""
var _stream_cache: Dictionary = {}
var _ui_sound_paths: Dictionary = {}
var _sfx_volume_offsets: Dictionary = {}
var _recent_errors: Array[String] = []
var _warning_cache: Dictionary = {}
var _music_fade_tween: Tween = null
var _music_transition_token: int = 0
var _music_mix_a: float = 1.0
var _music_mix_b: float = 0.0
var _sfx_play_requests: int = 0
var _sfx_play_failures: int = 0
var _sfx_pool_exhaustions: int = 0
var _music_play_requests: int = 0
var _music_play_failures: int = 0

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_audio_players_ready()
	_connect_runtime_signals()
	reload_ui_sound_config()


func _build_sfx_pool() -> void:
	for player in _sfx_pool:
		if player != null and player.get_parent() == self:
			remove_child(player)
			player.queue_free()
	_sfx_pool.clear()
	_sfx_volume_offsets.clear()
	for _i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = _resolved_sfx_bus
		add_child(player)
		_sfx_pool.append(player)


func _build_music_players() -> void:
	if _music_player_a != null and _music_player_a.get_parent() == self:
		remove_child(_music_player_a)
		_music_player_a.queue_free()
	if _music_player_b != null and _music_player_b.get_parent() == self:
		remove_child(_music_player_b)
		_music_player_b.queue_free()

	_music_player_a = AudioStreamPlayer.new()
	_music_player_b = AudioStreamPlayer.new()
	_music_player_a.bus = _resolved_music_bus
	_music_player_b.bus = _resolved_music_bus
	add_child(_music_player_a)
	add_child(_music_player_b)
	_active_music_player = _music_player_a
	_set_music_mix_a(1.0)
	_set_music_mix_b(0.0)


func _ensure_audio_players_ready() -> void:
	_resolve_audio_buses()

	var needs_sfx_pool := _sfx_pool.is_empty()
	if not needs_sfx_pool:
		for player in _sfx_pool:
			if player == null or player.get_parent() != self:
				needs_sfx_pool = true
				break
	if needs_sfx_pool:
		_build_sfx_pool()
	else:
		for player in _sfx_pool:
			if player != null:
				player.bus = _resolved_sfx_bus

	var needs_music_players := (
		_music_player_a == null
		or _music_player_b == null
		or _music_player_a.get_parent() != self
		or _music_player_b.get_parent() != self
	)
	if needs_music_players:
		_build_music_players()
	else:
		_music_player_a.bus = _resolved_music_bus
		_music_player_b.bus = _resolved_music_bus
		if _active_music_player == null:
			_active_music_player = _music_player_a
		_apply_music_mix(_music_player_a, _music_mix_a)
		_apply_music_mix(_music_player_b, _music_mix_b)


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

## Plays a one-shot sound effect. path can be a res:// path or a mod asset path.
func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	_ensure_audio_players_ready()
	var normalized_path := path.strip_edges()
	_sfx_play_requests += 1
	var stream := _load_audio_stream(normalized_path)
	if stream == null:
		_sfx_play_failures += 1
		return
	var player := _get_free_sfx_player()
	if player == null and not _sfx_pool.is_empty():
		player = _sfx_pool[0]
		_sfx_pool_exhaustions += 1
	if player == null:
		_sfx_play_failures += 1
		_append_recent_error("AudioManager: no SFX player was available for '%s'." % normalized_path)
		return
	_sfx_volume_offsets[player.get_instance_id()] = volume_db
	player.stream = stream
	player.stream_paused = false
	player.pitch_scale = pitch_scale
	_apply_sfx_volume(player)
	player.play()


## Returns the next available SFX pool player, or null if all are busy.
func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return null


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

## Plays background music. Cross-fades if a track is already playing.
func play_music(path: String, fade_duration: float = 1.0) -> void:
	_ensure_audio_players_ready()
	var normalized_path := path.strip_edges()
	_music_play_requests += 1
	if normalized_path.is_empty():
		_music_play_failures += 1
		_append_recent_error("AudioManager: attempted to play music with an empty path.")
		return
	var stream := _load_audio_stream(normalized_path)
	if stream == null:
		_music_play_failures += 1
		return
	if _active_music_player == null or _music_player_a == null or _music_player_b == null:
		_music_play_failures += 1
		_append_recent_error("AudioManager: music players are not initialized; '%s' was not played." % normalized_path)
		return
	if normalized_path == _current_music_path and _active_music_player.playing:
		return
	_cancel_music_fade()
	var next_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	next_player.stream = stream
	next_player.stream_paused = false
	_set_music_mix_for_player(next_player, 0.0)
	next_player.play()
	_current_music_path = normalized_path
	if not _active_music_player.playing or fade_duration <= 0.0:
		if next_player != _music_player_a:
			_stop_music_player(_music_player_a)
		if next_player != _music_player_b:
			_stop_music_player(_music_player_b)
		_active_music_player = next_player
		_set_music_mix_a(1.0 if next_player == _music_player_a else 0.0)
		_set_music_mix_b(1.0 if next_player == _music_player_b else 0.0)
		return
	var previous_player := _active_music_player
	_active_music_player = next_player
	_music_transition_token += 1
	var transition_token := _music_transition_token
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_method(Callable(self, "_set_music_mix_a"), _music_mix_a, 1.0 if next_player == _music_player_a else 0.0, fade_duration)
	_music_fade_tween.parallel().tween_method(Callable(self, "_set_music_mix_b"), _music_mix_b, 1.0 if next_player == _music_player_b else 0.0, fade_duration)
	_music_fade_tween.finished.connect(func() -> void:
		if transition_token != _music_transition_token:
			return
		previous_player.stop()
		_set_music_mix_for_player(previous_player, 0.0)
		_set_music_mix_for_player(_active_music_player, 1.0)
		_music_fade_tween = null
	)


## Stops music with an optional fade-out.
func stop_music(fade_duration: float = 1.0) -> void:
	_ensure_audio_players_ready()
	if _music_player_a == null or _music_player_b == null:
		return
	_cancel_music_fade()
	_music_transition_token += 1
	_current_music_path = ""
	if not _music_player_a.playing and not _music_player_b.playing:
		_set_music_mix_a(0.0)
		_set_music_mix_b(0.0)
		return
	if fade_duration <= 0.0:
		_stop_music_player(_music_player_a)
		_stop_music_player(_music_player_b)
		_set_music_mix_a(0.0)
		_set_music_mix_b(0.0)
		return
	var transition_token := _music_transition_token
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_method(Callable(self, "_set_music_mix_a"), _music_mix_a, 0.0, fade_duration)
	_music_fade_tween.parallel().tween_method(Callable(self, "_set_music_mix_b"), _music_mix_b, 0.0, fade_duration)
	_music_fade_tween.finished.connect(func() -> void:
		if transition_token != _music_transition_token:
			return
		_stop_music_player(_music_player_a)
		_stop_music_player(_music_player_b)
		_music_fade_tween = null
	)


## Pauses music playback.
func pause_music() -> void:
	_ensure_audio_players_ready()
	if _music_player_a != null:
		_music_player_a.stream_paused = true
	if _music_player_b != null:
		_music_player_b.stream_paused = true


## Resumes paused music.
func resume_music() -> void:
	_ensure_audio_players_ready()
	if _music_player_a != null:
		_music_player_a.stream_paused = false
	if _music_player_b != null:
		_music_player_b.stream_paused = false


## Plays a configured UI sound from config.json ui.sounds.
func play_ui_sound(sound_key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var path := get_ui_sound_path(sound_key)
	if path.is_empty():
		_warn_once(
			"missing_ui_sound:%s" % sound_key,
			"AudioManager: ui.sounds does not define a path for key '%s'." % sound_key
		)
		return
	play_sfx(path, volume_db, pitch_scale)


func reload_ui_sound_config() -> void:
	_ui_sound_paths.clear()
	if DataManager == null or not DataManager.has_method("get_config_value"):
		return
	var sounds_value: Variant = DataManager.get_config_value("ui.sounds", {})
	if not sounds_value is Dictionary:
		_warn_once("invalid_ui_sounds", "AudioManager: ui.sounds must be a dictionary when provided.")
		return
	var sounds: Dictionary = sounds_value
	for sound_key_value in sounds.keys():
		var sound_key := str(sound_key_value)
		var path := str(sounds.get(sound_key_value, ""))
		if sound_key.is_empty() or path.is_empty():
			continue
		_ui_sound_paths[sound_key] = path


func has_ui_sound(sound_key: String) -> bool:
	return _ui_sound_paths.has(sound_key)


func get_ui_sound_path(sound_key: String) -> String:
	return str(_ui_sound_paths.get(sound_key, ""))


func get_current_music_path() -> String:
	return _current_music_path


func get_debug_snapshot() -> Dictionary:
	return {
		"music_bus": _resolved_music_bus,
		"sfx_bus": _resolved_sfx_bus,
		"sfx_pool_size": _sfx_pool.size(),
		"active_sfx_players": _count_active_sfx_players(),
		"master_volume": _master_volume,
		"music_volume": _music_volume,
		"sfx_volume": _sfx_volume,
		"stream_cache_size": _stream_cache.size(),
		"ui_sound_keys": _get_ui_sound_keys(),
		"current_music_path": _current_music_path,
		"music_playing": _active_music_player != null and _active_music_player.playing,
		"music_paused": _active_music_player != null and _active_music_player.stream_paused,
		"music_transition_in_progress": _music_fade_tween != null,
		"game_events_available": GameEvents != null,
		"listens_for_all_mods_loaded": _is_connected_to_game_event("all_mods_loaded", Callable(self, "_on_all_mods_loaded")),
		"listens_for_game_paused": _is_connected_to_game_event("game_paused", Callable(self, "_on_game_paused")),
		"listens_for_game_resumed": _is_connected_to_game_event("game_resumed", Callable(self, "_on_game_resumed")),
		"sfx_play_requests": _sfx_play_requests,
		"sfx_play_failures": _sfx_play_failures,
		"sfx_pool_exhaustions": _sfx_pool_exhaustions,
		"music_play_requests": _music_play_requests,
		"music_play_failures": _music_play_failures,
		"recent_errors": _recent_errors.duplicate(),
	}


# ---------------------------------------------------------------------------
# Volume
# ---------------------------------------------------------------------------

func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_refresh_audio_volumes()


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_refresh_audio_volumes()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_refresh_audio_volumes()


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func _refresh_audio_volumes() -> void:
	for player in _sfx_pool:
		if player != null:
			_apply_sfx_volume(player)
	_apply_music_mix(_music_player_a, _music_mix_a)
	_apply_music_mix(_music_player_b, _music_mix_b)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _resolve_audio_buses() -> void:
	_resolved_music_bus = _resolve_audio_bus(MUSIC_BUS)
	_resolved_sfx_bus = _resolve_audio_bus(SFX_BUS)


func _resolve_audio_bus(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	_warn_once(
		"missing_bus:%s" % bus_name,
		"AudioManager: audio bus '%s' was not found. Falling back to '%s'." % [
			bus_name,
			DEFAULT_AUDIO_BUS,
		]
	)
	return DEFAULT_AUDIO_BUS


func _connect_runtime_signals() -> void:
	if GameEvents == null:
		return
	var on_all_mods_loaded := Callable(self, "_on_all_mods_loaded")
	if GameEvents.has_signal("all_mods_loaded") and not GameEvents.is_connected("all_mods_loaded", on_all_mods_loaded):
		GameEvents.all_mods_loaded.connect(_on_all_mods_loaded)
	var on_game_paused := Callable(self, "_on_game_paused")
	if GameEvents.has_signal("game_paused") and not GameEvents.is_connected("game_paused", on_game_paused):
		GameEvents.game_paused.connect(_on_game_paused)
	var on_game_resumed := Callable(self, "_on_game_resumed")
	if GameEvents.has_signal("game_resumed") and not GameEvents.is_connected("game_resumed", on_game_resumed):
		GameEvents.game_resumed.connect(_on_game_resumed)


func _is_connected_to_game_event(signal_name: String, callable: Callable) -> bool:
	if GameEvents == null or not GameEvents.has_signal(signal_name):
		return false
	return GameEvents.is_connected(signal_name, callable)


func _on_all_mods_loaded() -> void:
	reload_ui_sound_config()


func _on_game_paused() -> void:
	pause_music()


func _on_game_resumed() -> void:
	resume_music()


func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		_append_recent_error("AudioManager: attempted to load an empty audio path.")
		return null
	var cached_value: Variant = _stream_cache.get(path, null)
	if cached_value is AudioStream:
		var cached_stream: AudioStream = cached_value
		return cached_stream
	if not ResourceLoader.exists(path):
		_warn_once(
			"missing_resource:%s" % path,
			"AudioManager: audio resource '%s' does not exist." % path
		)
		return null
	var loaded_value: Variant = load(path)
	if not loaded_value is AudioStream:
		_append_recent_error("AudioManager: resource '%s' is not a valid AudioStream." % path)
		return null
	var stream: AudioStream = loaded_value
	_stream_cache[path] = stream
	return stream


func _apply_sfx_volume(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.volume_db = _get_sfx_volume_offset(player) + _linear_volume_to_db(_master_volume * _sfx_volume)


func _get_sfx_volume_offset(player: AudioStreamPlayer) -> float:
	var offset_value: Variant = _sfx_volume_offsets.get(player.get_instance_id(), 0.0)
	return float(offset_value)


func _apply_music_mix(player: AudioStreamPlayer, mix: float) -> void:
	if player == null:
		return
	player.volume_db = _linear_volume_to_db(_master_volume * _music_volume * clampf(mix, 0.0, 1.0))


func _set_music_mix_for_player(player: AudioStreamPlayer, value: float) -> void:
	if player == _music_player_a:
		_set_music_mix_a(value)
		return
	if player == _music_player_b:
		_set_music_mix_b(value)


func _set_music_mix_a(value: float) -> void:
	_music_mix_a = clampf(value, 0.0, 1.0)
	_apply_music_mix(_music_player_a, _music_mix_a)


func _set_music_mix_b(value: float) -> void:
	_music_mix_b = clampf(value, 0.0, 1.0)
	_apply_music_mix(_music_player_b, _music_mix_b)


func _cancel_music_fade() -> void:
	if _music_fade_tween == null:
		return
	_music_fade_tween.kill()
	_music_fade_tween = null


func _stop_music_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.stream_paused = false


func _linear_volume_to_db(value: float) -> float:
	if value <= 0.0:
		return SILENT_DB
	return linear_to_db(maxf(value, MIN_LINEAR_VOLUME))


func _count_active_sfx_players() -> int:
	var count := 0
	for player in _sfx_pool:
		if player != null and player.playing:
			count += 1
	return count


func _get_ui_sound_keys() -> Array[String]:
	var keys: Array[String] = []
	for sound_key_value in _ui_sound_paths.keys():
		keys.append(str(sound_key_value))
	keys.sort()
	return keys


func _warn_once(cache_key: String, message: String) -> void:
	if bool(_warning_cache.get(cache_key, false)):
		return
	_warning_cache[cache_key] = true
	push_warning(message)
	_append_recent_error(message)


func _append_recent_error(message: String) -> void:
	_recent_errors.append(message)
	if _recent_errors.size() > MAX_RECENT_ERRORS:
		_recent_errors.pop_front()
