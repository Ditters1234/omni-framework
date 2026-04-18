extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const MAIN_SCENE := preload("res://ui/main.tscn")
const SETTINGS_SCENE_PATH := "res://ui/screens/settings/settings_screen.tscn"
const GAMEPLAY_SHELL_SCENE_PATH := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const SAVE_SLOT_LIST_SCENE := preload("res://ui/screens/save_slot_list/save_slot_list_screen.tscn")
const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const TEST_SAVE_DIR := "user://test_saves/test_engine_owned_ui_behaviors/"

var _spawned_nodes: Array[Node] = []
var _main_scene: Node = null
var _screen_container: CanvasLayer = null


func before_each() -> void:
	_delete_settings_file()
	_cleanup_directory(TEST_SAVE_DIR)
	SaveManager.set_save_directory_for_testing(TEST_SAVE_DIR)
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	await get_tree().process_frame


func after_each() -> void:
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	for node in _spawned_nodes:
		if node == null or not is_instance_valid(node):
			continue
		node.queue_free()
	_spawned_nodes.clear()
	_main_scene = null
	_screen_container = null
	await get_tree().process_frame
	SaveManager.reset_save_directory_for_testing()
	_cleanup_directory(TEST_SAVE_DIR)
	_delete_settings_file()


func test_ui_cancel_pushes_and_pops_pause_menu_from_gameplay_shell() -> void:
	_main_scene = MAIN_SCENE.instantiate()
	_spawned_nodes.append(_main_scene)
	get_tree().root.add_child(_main_scene)
	await get_tree().process_frame

	GameState.new_game()
	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true

	_main_scene.call("_unhandled_input", cancel_event)
	await get_tree().process_frame

	assert_eq(UIRouter.current_screen_id(), "pause_menu")
	assert_eq(UIRouter.stack_depth(), 2)

	_main_scene.call("_unhandled_input", cancel_event)
	await get_tree().process_frame

	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)


func test_save_slot_list_delete_requires_confirmation_before_removing_slot() -> void:
	GameState.new_game()
	SaveManager.save_game(1)
	assert_true(SaveManager.slot_exists(1))

	var instance_value: Variant = SAVE_SLOT_LIST_SCENE.instantiate()
	assert_true(instance_value is Control)
	var screen: Control = instance_value
	_spawned_nodes.append(screen)
	get_tree().root.add_child(screen)
	screen.call("initialize", {"mode": "load"})
	await get_tree().process_frame

	screen.call("_on_delete_pressed", 1)
	await get_tree().process_frame

	var pending_snapshot_value: Variant = screen.call("get_debug_snapshot")
	assert_true(pending_snapshot_value is Dictionary)
	var pending_snapshot: Dictionary = pending_snapshot_value
	assert_eq(int(pending_snapshot.get("pending_delete_slot", -1)), 1)
	assert_true(SaveManager.slot_exists(1))

	screen.call("_on_delete_pressed", 1)
	await get_tree().process_frame

	var final_snapshot_value: Variant = screen.call("get_debug_snapshot")
	assert_true(final_snapshot_value is Dictionary)
	var final_snapshot: Dictionary = final_snapshot_value
	assert_eq(int(final_snapshot.get("pending_delete_slot", -1)), -1)
	assert_false(SaveManager.slot_exists(1))

	var status_label := screen.get_node("MarginContainer/PanelContainer/VBoxContainer/StatusLabel") as Label
	assert_not_null(status_label)
	assert_true(status_label.text.contains("Deleted"))


func test_settings_back_persists_dirty_changes_and_pops_to_previous_route() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	get_tree().root.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("test_root", TEST_SCREEN_SCENE)
	UIRouter.register_screen("settings", SETTINGS_SCENE_PATH)
	UIRouter.push("test_root")
	UIRouter.push("settings")
	await get_tree().process_frame

	var settings_screen := _get_top_screen()
	assert_not_null(settings_screen)
	assert_eq(UIRouter.stack_depth(), 2)

	var master_slider := settings_screen.get_node("MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AudioGrid/MasterSlider") as HSlider
	assert_not_null(master_slider)
	master_slider.value = 0.42
	settings_screen.call("_on_master_slider_value_changed", 0.42)
	await get_tree().process_frame

	settings_screen.call("_on_back_button_pressed")
	await get_tree().process_frame

	assert_eq(UIRouter.current_screen_id(), "test_root")
	assert_eq(UIRouter.stack_depth(), 1)

	var settings := APP_SETTINGS.load_settings()
	var audio_value: Variant = settings.get(APP_SETTINGS.SECTION_AUDIO, {})
	assert_true(audio_value is Dictionary)
	var audio: Dictionary = audio_value
	assert_almost_eq(float(audio.get(APP_SETTINGS.AUDIO_MASTER_VOLUME, 0.0)), 0.42, 0.001)


func test_router_exposes_current_screen_debug_snapshot_for_engine_owned_screen() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	get_tree().root.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("gameplay_shell", GAMEPLAY_SHELL_SCENE_PATH)
	GameState.new_game()

	UIRouter.push("gameplay_shell")
	await get_tree().process_frame

	var snapshot := UIRouter.get_current_screen_debug_snapshot()

	assert_eq(str(snapshot.get("screen_id", "")), "gameplay_shell")
	assert_true(bool(snapshot.get("has_session", false)))
	assert_true(snapshot.has("player"))
	assert_true(snapshot.has("location"))


func _get_top_screen() -> Control:
	if _screen_container == null or _screen_container.get_child_count() == 0:
		return null
	var child_value: Variant = _screen_container.get_child(_screen_container.get_child_count() - 1)
	return child_value as Control


func _delete_settings_file() -> void:
	if not FileAccess.file_exists(APP_SETTINGS.SETTINGS_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(APP_SETTINGS.SETTINGS_PATH))


func _cleanup_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(absolute_path)
	if dir != null:
		dir.list_dir_begin()
		var child_name := dir.get_next()
		while not child_name.is_empty():
			if child_name != "." and child_name != "..":
				var child_path := path.path_join(child_name)
				if dir.current_is_dir():
					_cleanup_directory(child_path)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			child_name = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)
