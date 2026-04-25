extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")
const MAIN_SCENE := preload("res://ui/main.tscn")
const SETTINGS_SCENE_PATH := "res://ui/screens/settings/settings_screen.tscn"
const GAMEPLAY_SHELL_SCENE_PATH := "res://ui/screens/gameplay_shell/gameplay_shell_screen.tscn"
const ASSEMBLY_EDITOR_SCENE_PATH := "res://ui/screens/backends/assembly_editor_screen.tscn"
const SAVE_SLOT_LIST_SCENE := preload("res://ui/screens/save_slot_list/save_slot_list_screen.tscn")
const TEST_SCREEN_SCENE := "res://tests/fixtures/ui_router/test_routed_screen.tscn"
const TEST_SAVE_DIR := "user://test_saves/test_engine_owned_ui_behaviors/"
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

var _spawned_nodes: Array[Node] = []
var _main_scene: Node = null
var _screen_container: CanvasLayer = null
var _test_viewport: SubViewport = null


func before_each() -> void:
	_delete_settings_file()
	_cleanup_directory(TEST_SAVE_DIR)
	SaveManager.set_save_directory_for_testing(TEST_SAVE_DIR)
	TEST_FIXTURE_WORLD.bootstrap_data_fixture()
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


func test_main_menu_new_game_opens_character_creator_surface_without_crashing() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	UIRouter.push("main_menu")
	await get_tree().process_frame

	var menu := _get_top_screen()
	assert_not_null(menu)
	menu.call("_on_new_game_button_pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)
	assert_not_null(GameState.player)
	var snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(snapshot.get("active_surface_screen_id", "")), "assembly_editor")


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


func test_settings_ai_chat_controls_persist_history_window_and_streaming_speed() -> void:
	var settings_scene := load(SETTINGS_SCENE_PATH) as PackedScene
	assert_not_null(settings_scene)
	var instance_value: Variant = settings_scene.instantiate()
	assert_true(instance_value is Control)
	var settings_screen: Control = instance_value
	_spawned_nodes.append(settings_screen)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(settings_screen)
	await get_tree().process_frame

	var history_spinbox := settings_screen.get_node(
		"MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiChatHistoryWindowSpinBox"
	) as SpinBox
	var streaming_spinbox := settings_screen.get_node(
		"MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiStreamingSpeedSpinBox"
	) as SpinBox
	var world_gen_toggle := settings_screen.get_node(
		"MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/AiGrid/AiWorldGenToggle"
	) as CheckButton
	assert_not_null(history_spinbox)
	assert_not_null(streaming_spinbox)
	assert_not_null(world_gen_toggle)
	if history_spinbox == null or streaming_spinbox == null or world_gen_toggle == null:
		return

	history_spinbox.value = 7
	settings_screen.call("_on_ai_chat_history_window_spinbox_value_changed", 7.0)
	streaming_spinbox.value = 0.12
	settings_screen.call("_on_ai_streaming_speed_spinbox_value_changed", 0.12)
	world_gen_toggle.button_pressed = true
	settings_screen.call("_on_ai_world_gen_toggle_toggled", true)
	await get_tree().process_frame

	settings_screen.call("_on_save_button_pressed")
	await get_tree().process_frame

	var ai_settings := APP_SETTINGS.get_ai_settings(APP_SETTINGS.load_settings())
	assert_eq(int(ai_settings.get(APP_SETTINGS.AI_CHAT_HISTORY_WINDOW, 0)), 7)
	assert_almost_eq(float(ai_settings.get(APP_SETTINGS.AI_STREAMING_SPEED, 0.0)), 0.12, 0.001)
	assert_true(bool(ai_settings.get(APP_SETTINGS.AI_ENABLE_WORLD_GEN, false)))


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


func test_gameplay_shell_debug_snapshot_includes_hosted_surface_snapshot_and_title() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	GameState.new_game()

	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	shell.call("open_surface_screen", "entity_sheet", {
		"target_entity_id": "player",
		"screen_title": "Inspect Player",
	})
	await get_tree().process_frame

	var snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(snapshot.get("active_surface_screen_id", "")), "entity_sheet")
	assert_eq(str(snapshot.get("surface_title", "")), "Inspect Player")
	var surface_snapshot_value: Variant = snapshot.get("active_surface_snapshot", {})
	assert_true(surface_snapshot_value is Dictionary)
	var surface_snapshot: Dictionary = surface_snapshot_value
	assert_eq(str(surface_snapshot.get("title", "")), "Inspect Player")
	assert_true(bool(surface_snapshot.get("opened_from_gameplay_shell", false)))

	var surface_title_label := shell.get_node("MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHeader/SurfaceTitleLabel") as Label
	assert_not_null(surface_title_label)
	assert_eq(surface_title_label.text, "Inspect Player")


func test_initial_gameplay_shell_assembly_surface_begin_reveals_location_surface() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen("gameplay_shell", GAMEPLAY_SHELL_SCENE_PATH)
	UIRouter.register_screen("assembly_editor", ASSEMBLY_EDITOR_SCENE_PATH)
	GameState.new_game()
	var starting_location_id := str(DataManager.get_config_value("game.starting_location", ""))
	assert_false(starting_location_id.is_empty())
	var starting_location := DataManager.get_location(starting_location_id)
	assert_false(starting_location.is_empty())
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var connections_value: Variant = starting_location.get("connections", {})
	assert_true(connections_value is Dictionary)
	if not connections_value is Dictionary:
		return
	var connections: Dictionary = connections_value
	assert_gt(connections.size(), 0)
	var connected_location_id := ""
	for location_id_value in connections.keys():
		connected_location_id = str(location_id_value)
		if not connected_location_id.is_empty():
			break
	assert_false(connected_location_id.is_empty())
	assert_true(player.has_discovered_location(connected_location_id))

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

	assert_false(GameState.current_location_id.is_empty())
	assert_eq(GameState.current_location_id, starting_location_id)
	assert_not_null(GameState.player)
	assert_eq(UIRouter.current_screen_id(), "gameplay_shell")
	assert_eq(UIRouter.stack_depth(), 1)
	var snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(snapshot.get("active_surface_screen_id", "")), "location_surface")
	assert_true(bool(snapshot.get("surface_visible", false)))

	var location_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(location_surface)
	var surface_snapshot_value: Variant = location_surface.call("get_debug_snapshot")
	assert_true(surface_snapshot_value is Dictionary)
	var surface_snapshot: Dictionary = surface_snapshot_value
	var travel_value: Variant = surface_snapshot.get("travel", [])
	assert_true(travel_value is Array)
	var travel_entries: Array = travel_value
	assert_gt(travel_entries.size(), 0)
	var travel_container := location_surface.get_node("MarginContainer/VBoxContainer/MainColumns/TravelPanel/MarginContainer/VBoxContainer/TravelScroll/TravelContainer") as VBoxContainer
	assert_not_null(travel_container)
	assert_gt(travel_container.get_child_count(), 0)
	assert_null(_find_label_with_text(location_surface, "No active location."))


func test_assembly_editor_custom_field_signal_updates_draft_part_detail_view_model() -> void:
	GameState.new_game()
	var packed_scene := load(ASSEMBLY_EDITOR_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene)
	if packed_scene == null:
		return
	var instance_value: Variant = packed_scene.instantiate()
	assert_true(instance_value is Control)
	if not instance_value is Control:
		return
	var screen: Control = instance_value
	_spawned_nodes.append(screen)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(screen)
	screen.call("initialize", {
		"target_entity_id": "player",
		"budget_entity_id": "player",
		"budget_currency_id": "credits",
	})
	await get_tree().process_frame
	screen.call("_on_row_selected", "head")
	await get_tree().process_frame

	var panel := screen.find_child("PartDetailPanel", true, false) as PartDetailPanel
	assert_not_null(panel)
	if panel == null:
		return
	panel.custom_field_changed.emit("head", "eye_color", "amber")
	await get_tree().process_frame

	var snapshot_value: Variant = screen.call("get_debug_snapshot")
	assert_true(snapshot_value is Dictionary)
	if not snapshot_value is Dictionary:
		return
	var snapshot: Dictionary = snapshot_value
	var last_view_model := _read_dictionary(snapshot.get("last_view_model", {}))
	var part_detail := _read_dictionary(last_view_model.get("part_detail", {}))
	var custom_values := _read_dictionary(part_detail.get("custom_values", {}))

	assert_eq(str(part_detail.get("slot_id", "")), "head")
	assert_eq(str(custom_values.get("eye_color", "")), "amber")


func test_location_surface_lists_present_entities_and_entity_interactions() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	GameState.new_game()
	GameState.travel_to(TEST_FIXTURE_WORLD.connected_location_id())

	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	var location_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(location_surface)

	var surface_snapshot_value: Variant = location_surface.call("get_debug_snapshot")
	assert_true(surface_snapshot_value is Dictionary)
	var surface_snapshot: Dictionary = surface_snapshot_value
	var entities_value: Variant = surface_snapshot.get("entities", [])
	assert_true(entities_value is Array)
	var entities: Array = entities_value
	assert_gt(entities.size(), 0)
	if entities.is_empty():
		return
	var vendor_id := TEST_FIXTURE_WORLD.fixture_vendor_id()
	var vendor_value: Variant = _find_entity_row(entities, vendor_id)
	assert_true(vendor_value is Dictionary)
	if not vendor_value is Dictionary:
		return
	var vendor: Dictionary = vendor_value
	assert_eq(str(vendor.get("display_name", "")), "Fixture Vendor")

	var trade_button := _find_button_with_text(location_surface, "Browse Stock")
	assert_not_null(trade_button)
	assert_false(trade_button.disabled)
	var talk_button := _find_button_with_text(location_surface, "Talk")
	assert_not_null(talk_button)
	assert_false(talk_button.disabled)
	talk_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var shell_snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(shell_snapshot.get("active_surface_screen_id", "")), "dialogue")
	var dialogue_screen := shell.find_child("DialogueScreen", true, false) as Control
	assert_not_null(dialogue_screen)
	var dialogue_snapshot_value: Variant = dialogue_screen.call("get_debug_snapshot")
	assert_true(dialogue_snapshot_value is Dictionary)
	var dialogue_snapshot: Dictionary = dialogue_snapshot_value
	assert_eq(str(dialogue_snapshot.get("speaker_entity_id", "")), vendor_id)
	assert_eq(str(dialogue_snapshot.get("dialogue_resource", "")), TEST_FIXTURE_WORLD.sample_dialogue_resource_path())
	assert_null(_find_label_with_text(dialogue_screen, "The configured dialogue resource could not be loaded."))


func test_location_surface_travel_button_advances_time_by_connection_cost() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	GameState.new_game()

	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	var location_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(location_surface)
	var surface_snapshot_value: Variant = location_surface.call("get_debug_snapshot")
	assert_true(surface_snapshot_value is Dictionary)
	if not surface_snapshot_value is Dictionary:
		return
	var surface_snapshot: Dictionary = surface_snapshot_value
	var travel_entries: Array[Dictionary] = _read_dictionary_array(surface_snapshot.get("travel", []))
	assert_gt(travel_entries.size(), 0)
	if travel_entries.is_empty():
		return
	var destination_entry: Dictionary = travel_entries[0]
	var destination_name := str(destination_entry.get("destination_name", ""))
	var destination_id := str(destination_entry.get("destination_id", ""))
	var travel_cost := int(destination_entry.get("travel_cost", 0))
	assert_false(destination_name.is_empty())
	assert_false(destination_id.is_empty())
	assert_gt(travel_cost, 0)

	var tick_before := GameState.current_tick
	var destination_button := _find_button_with_text(location_surface, "%s (%d)" % [destination_name, travel_cost])
	assert_not_null(destination_button)
	if destination_button == null:
		return
	destination_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(GameState.current_location_id, destination_id)
	assert_eq(GameState.current_tick, tick_before + travel_cost)


func test_location_surface_empty_location_param_falls_back_to_game_state_location() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	GameState.new_game()

	UIRouter.replace_all("gameplay_shell", {
		"initial_surface_id": "assembly_editor",
		"initial_surface_params": {
			"target_entity_id": "player",
			"pop_on_confirm": true,
			"allow_confirm_without_changes": true,
		},
	})
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	var assembly_screen := shell.find_child("AssemblyEditorScreen", true, false) as Control
	assert_not_null(assembly_screen)
	assembly_screen.call("_on_begin_button_pressed")
	await get_tree().process_frame

	var location_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(location_surface)
	location_surface.call("initialize", {"location_id": ""})
	await get_tree().process_frame

	var surface_snapshot_value: Variant = location_surface.call("get_debug_snapshot")
	assert_true(surface_snapshot_value is Dictionary)
	var surface_snapshot: Dictionary = surface_snapshot_value
	assert_eq(str(surface_snapshot.get("location_id", "")), GameState.current_location_id)
	var travel_value: Variant = surface_snapshot.get("travel", [])
	assert_true(travel_value is Array)
	var travel_entries: Array = travel_value
	assert_gt(travel_entries.size(), 0)
	assert_null(_find_label_with_text(location_surface, "No active location."))


func test_gameplay_shell_hosts_default_location_surface() -> void:
	GameState.new_game()
	var packed_scene := load(GAMEPLAY_SHELL_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene)
	var instance_value: Variant = packed_scene.instantiate()
	assert_true(instance_value is Control)
	var shell := instance_value as Control
	_spawned_nodes.append(shell)
	assert_not_null(_test_viewport)
	_test_viewport.size = Vector2i(640, 360)
	_test_viewport.add_child(shell)
	shell.call("initialize", {})
	await get_tree().process_frame
	await get_tree().process_frame

	var surface_host := shell.get_node("MarginContainer/VBoxContainer/SurfacePanel/MarginContainer/VBoxContainer/SurfaceHost") as Control
	assert_not_null(surface_host)

	var active_surface := shell.find_child("GameplayLocationSurface", true, false) as Control
	assert_not_null(active_surface)


func test_gameplay_shell_top_menu_opens_world_map_with_full_graph_and_keeps_map_after_travel_signal() -> void:
	_screen_container = CanvasLayer.new()
	_spawned_nodes.append(_screen_container)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	_register_runtime_screens()
	GameState.new_game()

	UIRouter.replace_all("gameplay_shell")
	await get_tree().process_frame
	await get_tree().process_frame

	var shell := _get_top_screen()
	assert_not_null(shell)
	var world_map_button := _find_button_with_text(shell, "Map")
	assert_not_null(world_map_button)
	assert_false(world_map_button.disabled)
	world_map_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var shell_snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(shell_snapshot.get("active_surface_screen_id", "")), "world_map")
	var map_screen := shell.find_child("WorldMapScreen", true, false) as Control
	assert_not_null(map_screen)
	var map_snapshot_value: Variant = map_screen.call("get_debug_snapshot")
	assert_true(map_snapshot_value is Dictionary)
	if not map_snapshot_value is Dictionary:
		return
	var map_snapshot: Dictionary = map_snapshot_value
	var locations_value: Variant = map_snapshot.get("locations", [])
	assert_true(locations_value is Array)
	if not locations_value is Array:
		return
	var locations: Array = locations_value
	assert_gt(locations.size(), 1)
	assert_true(_map_rows_contain_location(locations, GameState.current_location_id))
	var destination_id := _first_non_current_map_location(locations, GameState.current_location_id)
	assert_false(destination_id.is_empty())
	if destination_id.is_empty():
		return
	var expected_travel_cost := LocationGraph.get_route_travel_cost(GameState.current_location_id, destination_id)
	assert_gt(expected_travel_cost, 0)
	var edges_value: Variant = map_snapshot.get("edges", [])
	assert_true(edges_value is Array)
	if edges_value is Array:
		var edges: Array = edges_value
		assert_gt(edges.size(), 0)

	var graph := map_screen.find_child("WorldMapGraph", true, false) as Control
	assert_not_null(graph)
	var graph_buttons_value: Variant = graph.get("_buttons_by_id")
	assert_true(graph_buttons_value is Dictionary)
	if graph_buttons_value is Dictionary:
		var graph_buttons: Dictionary = graph_buttons_value
		var effective_viewport_size_value: Variant = graph.call("_get_effective_viewport_size")
		assert_true(effective_viewport_size_value is Vector2)
		var effective_viewport_size := Vector2.ZERO
		if effective_viewport_size_value is Vector2:
			effective_viewport_size = effective_viewport_size_value
		var viewport_bounds := Rect2(Vector2.ZERO, effective_viewport_size)
		assert_true(graph_buttons.has(GameState.current_location_id))
		assert_true(graph_buttons.has(destination_id))
		for location_id_value in graph_buttons.keys():
			var location_button := graph_buttons.get(location_id_value) as Button
			assert_not_null(location_button)
			if location_button != null:
				assert_true(location_button.visible, "%s map button should be visible." % str(location_id_value))
				var location_center := location_button.position + location_button.size * 0.5
				assert_true(viewport_bounds.has_point(location_center), "%s map button should land inside the graph viewport." % str(location_id_value))

	var zoom_in_button := _find_button_with_text(map_screen, "+")
	var zoom_out_button := _find_button_with_text(map_screen, "-")
	assert_not_null(zoom_in_button)
	assert_not_null(zoom_out_button)
	var initial_viewport := _read_dictionary(map_snapshot.get("viewport", {}))
	var initial_zoom := float(initial_viewport.get("zoom", 1.0))
	if initial_zoom >= 2.5:
		zoom_out_button.pressed.emit()
	else:
		zoom_in_button.pressed.emit()
	await get_tree().process_frame
	var zoomed_snapshot_value: Variant = map_screen.call("get_debug_snapshot")
	assert_true(zoomed_snapshot_value is Dictionary)
	if zoomed_snapshot_value is Dictionary:
		var zoomed_snapshot: Dictionary = zoomed_snapshot_value
		var zoomed_viewport := _read_dictionary(zoomed_snapshot.get("viewport", {}))
		assert_ne(float(zoomed_viewport.get("zoom", 1.0)), initial_zoom)

	var orientation_button := map_screen.get_node("MarginContainer/PanelContainer/VBoxContainer/ControlRow/OrientationButton") as OptionButton
	assert_not_null(orientation_button)
	orientation_button.select(1)
	orientation_button.item_selected.emit(1)
	await get_tree().process_frame
	var oriented_snapshot_value: Variant = map_screen.call("get_debug_snapshot")
	assert_true(oriented_snapshot_value is Dictionary)
	if oriented_snapshot_value is Dictionary:
		var oriented_snapshot: Dictionary = oriented_snapshot_value
		var oriented_viewport := _read_dictionary(oriented_snapshot.get("viewport", {}))
		assert_eq(str(oriented_viewport.get("orientation", "")), "horizontal")

	var pan_before_value: Variant = graph.call("get_viewport_snapshot")
	assert_true(pan_before_value is Dictionary)
	if pan_before_value is Dictionary:
		var pan_before: Dictionary = pan_before_value
		var pan_before_position := _read_dictionary(pan_before.get("pan", {}))
		_drag_graph_for_test(graph, Vector2(42.0, -18.0))
		await get_tree().process_frame
		var pan_after_value: Variant = graph.call("get_viewport_snapshot")
		assert_true(pan_after_value is Dictionary)
		if pan_after_value is Dictionary:
			var pan_after: Dictionary = pan_after_value
			var pan_after_position := _read_dictionary(pan_after.get("pan", {}))
			assert_ne(float(pan_after_position.get("x", 0.0)), float(pan_before_position.get("x", 0.0)))

	graph.emit_signal("location_selected", destination_id)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(GameState.current_location_id, destination_id)
	assert_eq(GameState.current_tick, expected_travel_cost)
	var after_travel_snapshot := UIRouter.get_current_screen_debug_snapshot()
	assert_eq(str(after_travel_snapshot.get("active_surface_screen_id", "")), "world_map")
	var after_map_snapshot_value: Variant = map_screen.call("get_debug_snapshot")
	assert_true(after_map_snapshot_value is Dictionary)
	if after_map_snapshot_value is Dictionary:
		var after_map_snapshot: Dictionary = after_map_snapshot_value
		assert_eq(str(after_map_snapshot.get("current_location_id", "")), destination_id)


func _get_top_screen() -> Control:
	if _screen_container == null or _screen_container.get_child_count() == 0:
		return null
	var child_value: Variant = _screen_container.get_child(_screen_container.get_child_count() - 1)
	return child_value as Control


func _register_runtime_screens() -> void:
	for screen_id_value in UI_ROUTE_CATALOG.RUNTIME_SCREEN_REGISTRY.keys():
		var screen_id := str(screen_id_value)
		var scene_path := str(UI_ROUTE_CATALOG.RUNTIME_SCREEN_REGISTRY.get(screen_id_value, ""))
		UIRouter.register_screen(screen_id, scene_path)


func _find_button_with_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		var button := child as Button
		if button != null and button.text == text:
			return button
		var match := _find_button_with_text(child, text)
		if match != null:
			return match
	return null


func _find_label_with_text(root: Node, text: String) -> Label:
	for child in root.get_children():
		var label := child as Label
		if label != null and label.text == text:
			return label
		var match := _find_label_with_text(child, text)
		if match != null:
			return match
	return null


func _map_rows_contain_location(rows: Array, location_id: String) -> bool:
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		if str(row.get("location_id", "")) == location_id:
			return true
	return false


func _first_non_current_map_location(rows: Array, current_location_id: String) -> String:
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var location_id := str(row.get("location_id", ""))
		if not location_id.is_empty() and location_id != current_location_id:
			return location_id
	return ""


func _find_entity_row(rows: Array, entity_id: String) -> Variant:
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		if str(row.get("entity_id", "")) == entity_id:
			return row
	return null


func _drag_graph_for_test(graph: Control, relative: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	graph.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 100.0) + relative
	motion.relative = relative
	graph.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = Vector2(100.0, 100.0) + relative
	graph.call("_gui_input", release)


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _read_dictionary_array(value: Variant) -> Array[Dictionary]:
	var dictionaries: Array[Dictionary] = []
	if not value is Array:
		return dictionaries
	var values: Array = value
	for item in values:
		if item is Dictionary:
			var dictionary_item: Dictionary = item
			dictionaries.append(dictionary_item)
	return dictionaries


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
