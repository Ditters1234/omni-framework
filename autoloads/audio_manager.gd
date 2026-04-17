## AudioManager — SFX pools and music playback.
## SFX are played from pooled AudioStreamPlayer nodes.
## Music uses a dedicated player with optional cross-fade.
extends Node

class_name OmniAudioManager

const SFX_POOL_SIZE := 8
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null

var _master_volume: float = 1.0
var _music_volume: float = 1.0
var _sfx_volume: float = 1.0

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_sfx_pool()
	_build_music_players()


func _build_sfx_pool() -> void:
	_sfx_pool.clear()
	for _i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)


func _build_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_b = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	_music_player_b.bus = MUSIC_BUS
	add_child(_music_player_a)
	add_child(_music_player_b)
	_active_music_player = _music_player_a
	_apply_music_volume(_music_player_a)
	_apply_music_volume(_music_player_b)


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

## Plays a one-shot sound effect. path can be a res:// path or a mod asset path.
func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var player := _get_free_sfx_player()
	if player == null and not _sfx_pool.is_empty():
		player = _sfx_pool[0]
	if player == null:
		return
	player.stream = load(path) as AudioStream
	if player.stream == null:
		return
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db + linear_to_db(_master_volume * _sfx_volume)
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
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if _active_music_player == null:
		return
	var next_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	next_player.stream = stream
	next_player.volume_db = linear_to_db(0.001)
	next_player.play()
	if not _active_music_player.playing or fade_duration <= 0.0:
		_active_music_player.stop()
		_active_music_player = next_player
		_apply_music_volume(_active_music_player)
		return
	var previous_player := _active_music_player
	_active_music_player = next_player
	var tween := create_tween()
	tween.tween_property(previous_player, "volume_db", linear_to_db(0.001), fade_duration)
	tween.parallel().tween_property(next_player, "volume_db", linear_to_db(maxf(_master_volume * _music_volume, 0.001)), fade_duration)
	tween.finished.connect(func() -> void:
		previous_player.stop()
		_apply_music_volume(_active_music_player)
	)


## Stops music with an optional fade-out.
func stop_music(fade_duration: float = 1.0) -> void:
	if _active_music_player == null or not _active_music_player.playing:
		return
	if fade_duration <= 0.0:
		_active_music_player.stop()
		return
	var player := _active_music_player
	var tween := create_tween()
	tween.tween_property(player, "volume_db", linear_to_db(0.001), fade_duration)
	tween.finished.connect(func() -> void:
		player.stop()
		_apply_music_volume(player)
	)


## Pauses music playback.
func pause_music() -> void:
	if _music_player_a != null:
		_music_player_a.stream_paused = true
	if _music_player_b != null:
		_music_player_b.stream_paused = true


## Resumes paused music.
func resume_music() -> void:
	if _music_player_a != null:
		_music_player_a.stream_paused = false
	if _music_player_b != null:
		_music_player_b.stream_paused = false


# ---------------------------------------------------------------------------
# Volume
# ---------------------------------------------------------------------------

func set_master_volume(value: float) -> void:
	_master_volume = clamp(value, 0.0, 1.0)
	_refresh_audio_volumes()


func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)
	_refresh_audio_volumes()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clamp(value, 0.0, 1.0)
	_refresh_audio_volumes()


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func _refresh_audio_volumes() -> void:
	for player in _sfx_pool:
		if player != null and player.playing:
			player.volume_db = linear_to_db(maxf(_master_volume * _sfx_volume, 0.001))
	_apply_music_volume(_music_player_a)
	_apply_music_volume(_music_player_b)


func _apply_music_volume(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.volume_db = linear_to_db(maxf(_master_volume * _music_volume, 0.001))
