extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const MAIN_SCENE := preload("res://ui/main.tscn")
const SETTINGS_SCENE_PATH := "res://ui/screens/settings/settings_screen.tscn"
const GAMEPLAY_SHELL_SCENE_PATH := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const ASSEMBLY_EDITOR_SCENE_PATH := "res://ui/screens/backends/assembly_editor_screen.tscn"
const SAVE_SLOT_LIST_SCENE := preload("res://ui/screens/save_slot_list/save_slot_list_screen.tscn")
const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const TEST_SAVE_DIR := "user://test_saves/test_engine_owned_ui_behaviors/"

var _spawned_nodes: Array[Node] = []
var _main_scene: Node = null
var _screen_container: CanvasLayer = null
var _test_viewport: SubViewport = null


func before_each() -> void:
	_delete_settings_file()
	_cleanup_directory(TEST_SAVE_DIR)
	SaveManager.set_save_directory_for_testing(TEST_SAVE_DIR)
	AIManager.initialize(_make_ai_settings(APP_SETTINGS.AI_PROVIDER_DISABLED))
	_test_viewport = _create_test_viewport()
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
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null
	await get_tree().process_frame
	SaveManager.reset_save_directory_for_testing()
	AIManager.initialize(_make_ai_settings(APP_SETTINGS.AI_PROVIDER_DISABLED))
	_cleanup_directory(TEST_SAVE_DIR)
	_delete_settings_file()
	APP_SETTINGS.reset_settings_path_for_testing()


func test_ui_cancel_pushes_and_pops_pause_menu_from_gameplay_shell() -> void:
	_main_scene = MAIN_SCENE.instantiate()
	_spawned_nodes.append(_main_scene)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_main_scene)
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
	assert_not_null(_test_viewport)
	_test_viewport.add_child(screen)
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
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
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


func test_settings_ai_button_toggles_to_disconnect_after_connection() -> void:
	var settings_scene := load(SETTINGS_SCENE_PATH) as PackedScene
	assert_not_null(settings_scene)
	var instance_value: Variant = settings_scene.instantiate()
	assert_true(instance_value is Control)
	var settings_screen: Control = instance_value
	_spawned_nodes.append(settings_screen)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(settings_screen)
	await get_tree().process_frame

	var provider_button := settings_screen.get_node("MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiProviderButton") as OptionButton
	var connect_button := settings_screen.get_node("MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiButtonRow/ConnectAiButton") as Button
	var status_label := settings_screen.get_node("MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/StatusLabel") as Label
	assert_not_null(provider_button)
	assert_not_null(connect_button)
	assert_not_null(status_label)

	provider_button.select(1)
	settings_screen.call("_on_ai_provider_button_item_selected", 1)
	await get_tree().process_frame

	assert_eq(connect_button.text, "Connect AI")
	assert_false(connect_button.disabled)

	settings_screen.call("_on_connect_ai_button_pressed")
	await get_tree().process_frame

	assert_true(AIManager.is_available())
	assert_eq(connect_button.text, "Disconnect AI")
	assert_false(connect_button.disabled)

	settings_screen.call("_on_connect_ai_button_pressed")
	await get_tree().process_frame

	assert_false(AIManager.is_available())
	assert_eq(connect_button.text, "Connect AI")
	assert_true(connect_button.disabled)
	assert_true(status_label.text.contains("disconnected"))


func test_router_exposes_current_screen_debug_snapshot_for_engine_owned_screen() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
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


func test_initial_gameplay_shell_assembly_surface_begin_reveals_location_surface() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("gameplay_shell", GAMEPLAY_SHELL_SCENE_PATH)
	UIRouter.register_screen("assembly_editor", ASSEMBLY_EDITOR_SCENE_PATH)
	GameState.new_game()

	UIRouter.replace_all("gameplay_shell", {
		"initial_surface_id": "assembly_editor",
		"disable_shell_chrome": true,
		"initial_surface_params": {
			"target_entity_id": "player",
			"pop_on_confirm": true,
			"allow_confirm_without_changes": true,
			"cancel_screen_id": "main_menu",
		},
	})
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	var assembly_screen := shell.find_child("AssemblyEditorScreen", true, false) as Control
	assert_not_null(assembly_screen)

	assembly_screen.call("_on_begin_button_pressed")
	await get_tree().process_frame

	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)
	var snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(snapshot.get("active_surface_screen_id", "")), "location_surface")
	assert_true(bool(snapshot.get("surface_visible", false)))


func test_gameplay_shell_scrolls_when_viewport_is_short() -> void:
	GameState.new_game()
	var packed_scene := load(GAMEPLAY_SHELL_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene)
	var instance_value: Variant = packed_scene.instantiate()
	assert_true(instance_value is ScrollContainer)
	var shell := instance_value as ScrollContainer
	_spawned_nodes.append(shell)
	assert_not_null(_test_viewport)
	_test_viewport.size = Vector2i(640, 360)
	_test_viewport.add_child(shell)
	shell.call("initialize", {})
	await get_tree().process_frame
	await get_tree().process_frame

	assert_lte(shell.size.y, float(_test_viewport.size.y))
	var shell_scrollbar := shell.get_v_scroll_bar()
	assert_gt(shell_scrollbar.max_value, shell_scrollbar.page)

	var surface_host := shell.get_node("MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHost") as ScrollContainer
	assert_not_null(surface_host)
	assert_true(surface_host.follow_focus)
	assert_eq(surface_host.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)

	var active_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(active_surface)
	assert_gte(active_surface.custom_minimum_size.y, surface_host.size.y)


func _get_top_screen() -> Control:
	if _screen_container == null or _screen_container.get_child_count() == 0:
		return null
	var child_value: Variant = _screen_container.get_child(_screen_container.get_child_count() - 1)
	return child_value as Control


func _delete_settings_file() -> void:
	var settings_path := APP_SETTINGS.get_settings_path()
	if not FileAccess.file_exists(settings_path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


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


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestEngineOwnedUIViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport


func _make_ai_settings(provider: String) -> Dictionary:
	var settings := APP_SETTINGS.get_default_settings()
	var ai_settings := APP_SETTINGS.get_ai_settings(settings)
	ai_settings[APP_SETTINGS.AI_ENABLED] = provider != APP_SETTINGS.AI_PROVIDER_DISABLED
	ai_settings[APP_SETTINGS.AI_PROVIDER] = provider
	settings[APP_SETTINGS.SECTION_AI] = ai_settings
	return settings
