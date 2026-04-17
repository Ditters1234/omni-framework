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
	pass


func _build_music_players() -> void:
	pass


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

## Plays a one-shot sound effect. path can be a res:// path or a mod asset path.
func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	pass


## Returns the next available SFX pool player, or null if all are busy.
func _get_free_sfx_player() -> AudioStreamPlayer:
	return null


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

## Plays background music. Cross-fades if a track is already playing.
func play_music(path: String, fade_duration: float = 1.0) -> void:
	pass


## Stops music with an optional fade-out.
func stop_music(fade_duration: float = 1.0) -> void:
	pass


## Pauses music playback.
func pause_music() -> void:
	pass


## Resumes paused music.
func resume_music() -> void:
	pass


# ---------------------------------------------------------------------------
# Volume
# ---------------------------------------------------------------------------

func set_master_volume(value: float) -> void:
	_master_volume = clamp(value, 0.0, 1.0)


func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clamp(value, 0.0, 1.0)


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume
