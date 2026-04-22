extends GutTest


const AUDIO_MANAGER_SCRIPT := preload("res://autoloads/audio_manager.gd")
const TEST_AUDIO_A := "res://tests/audio/fake_track_a.wav"
const TEST_AUDIO_B := "res://tests/audio/fake_track_b.wav"
const TEST_AUDIO_C := "res://tests/audio/fake_track_c.wav"

var _audio_manager: OmniAudioManager = null
var _original_config: Dictionary = {}


func before_each() -> void:
	_original_config = DataManager.config.duplicate(true)
	DataManager.config = {}
	GameEvents.clear_event_history()
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	get_tree().root.add_child(_audio_manager)


func after_each() -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.free()
	DataManager.config = _original_config.duplicate(true)


func test_reload_ui_sound_config_updates_from_data_manager_via_all_mods_loaded_signal() -> void:
	DataManager.config = {
		"ui": {
			"sounds": {
				"hover": TEST_AUDIO_A,
				"click": TEST_AUDIO_B,
			}
		}
	}

	GameEvents.all_mods_loaded.emit()

	assert_true(_audio_manager.has_ui_sound("hover"))
	assert_eq(_audio_manager.get_ui_sound_path("hover"), TEST_AUDIO_A)
	assert_eq(_audio_manager.get_ui_sound_path("click"), TEST_AUDIO_B)

	var snapshot := _audio_manager.get_debug_snapshot()
	assert_true(bool(snapshot.get("listens_for_all_mods_loaded", false)))

	var keys_value: Variant = snapshot.get("ui_sound_keys", [])
	assert_true(keys_value is Array)
	var keys: Array = keys_value
	assert_eq(keys, ["click", "hover"])


func test_missing_audio_buses_fall_back_to_master_bus() -> void:
	var resolved_bus := _audio_manager._resolve_audio_bus("DefinitelyMissingAudioBus")

	assert_eq(resolved_bus, _audio_manager.DEFAULT_AUDIO_BUS)
	assert_push_warning("DefinitelyMissingAudioBus")

	var snapshot := _audio_manager.get_debug_snapshot()
	var errors_value: Variant = snapshot.get("recent_errors", [])
	assert_true(errors_value is Array)
	var errors: Array = errors_value
	assert_true(_array_contains_text(errors, "DefinitelyMissingAudioBus"))


func test_refresh_audio_volumes_preserves_per_sfx_volume_offset() -> void:
	var player := _audio_manager._sfx_pool[0]
	_audio_manager._sfx_volume_offsets[player.get_instance_id()] = 6.0
	_audio_manager.set_master_volume(0.5)
	_audio_manager.set_sfx_volume(0.5)

	var expected_db := 6.0 + linear_to_db(0.25)
	assert_almost_eq(player.volume_db, expected_db, 0.01)


func test_game_pause_and_resume_signals_pause_and_resume_music_players() -> void:
	_cache_test_stream(TEST_AUDIO_A)
	_audio_manager.play_music(TEST_AUDIO_A, 0.0)
	var active_player := _audio_manager._active_music_player

	GameEvents.game_paused.emit()

	assert_true(active_player != null)
	assert_true(active_player.stream_paused)
	assert_true(bool(_audio_manager.get_debug_snapshot().get("listens_for_game_paused", false)))

	GameEvents.game_resumed.emit()

	assert_false(active_player.stream_paused)
	assert_true(bool(_audio_manager.get_debug_snapshot().get("listens_for_game_resumed", false)))


func test_overlapping_music_transitions_do_not_stop_the_latest_track() -> void:
	_cache_test_stream(TEST_AUDIO_A)
	_cache_test_stream(TEST_AUDIO_B)
	_cache_test_stream(TEST_AUDIO_C)

	_audio_manager.play_music(TEST_AUDIO_A, 0.0)
	_audio_manager.play_music(TEST_AUDIO_B, 0.1)
	_audio_manager.play_music(TEST_AUDIO_C, 0.1)
	await get_tree().create_timer(0.2).timeout

	assert_eq(_audio_manager.get_current_music_path(), TEST_AUDIO_C)
	assert_true(_audio_manager._active_music_player != null)
	assert_true(_audio_manager._active_music_player.playing)
	assert_false(bool(_audio_manager.get_debug_snapshot().get("music_transition_in_progress", true)))


func _cache_test_stream(path: String) -> void:
	_audio_manager._stream_cache[path] = _create_test_stream()


func _create_test_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(44100 * 2)
	stream.data = data
	return stream


func _array_contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false
