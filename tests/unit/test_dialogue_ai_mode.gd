extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const DIALOGUE_SCREEN_SCENE := preload("res://ui/screens/backends/dialogue_screen.tscn")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"
const AI_HANDOFF_DIALOGUE := "res://tests/fixtures/dialogue/fixture_dialogue_resource.tres"
const FIXTURE_PERSONA_ID := "base:fixture_vendor_persona"
const FIXTURE_FACTION_ID := "base:fixture_faction"

var _spawned_nodes: Array[Node] = []
var _test_viewport: SubViewport = null


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	_seed_ai_fixture_vendor()
	APP_SETTINGS.save_settings(_make_settings({
		APP_SETTINGS.AI_ENABLED: true,
		APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE,
		APP_SETTINGS.AI_MODEL: "fake-model",
		APP_SETTINGS.AI_CHAT_HISTORY_WINDOW: APP_SETTINGS.DEFAULT_AI_CHAT_HISTORY_WINDOW,
		APP_SETTINGS.AI_STREAMING_SPEED: 0.0,
		"ready": true,
	}))
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: true,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE,
		APP_SETTINGS.AI_MODEL: "fake-model",
		"ready": true,
	}))
	_test_viewport = _create_test_viewport()


func after_each() -> void:
	for node in _spawned_nodes:
		if node == null or not is_instance_valid(node):
			continue
		node.queue_free()
	_spawned_nodes.clear()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null
	AIManager.clear_provider_script_overrides()
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
	}))
	_delete_settings_file()
	APP_SETTINGS.reset_settings_path_for_testing()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func test_dialogue_screen_hybrid_ai_handoff_streams_and_returns_to_topics() -> void:
	var screen := _instantiate_dialogue_screen({
		"speaker_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
		"dialogue_resource": AI_HANDOFF_DIALOGUE,
		"dialogue_start": "start",
		"ai_mode": "hybrid",
	})

	await get_tree().process_frame
	await get_tree().process_frame

	var talk_freely_button := _find_button_with_text(screen, "Talk freely.")
	assert_not_null(talk_freely_button)
	if talk_freely_button == null:
		return

	talk_freely_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var handoff_snapshot := _read_dictionary(screen.call("get_debug_snapshot"))
	assert_true(bool(handoff_snapshot.get("ai_chat_active", false)))

	var ai_input := screen.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIInputRow/AIInput"
	) as LineEdit
	assert_not_null(ai_input)
	if ai_input == null:
		return
	ai_input.text = "Status report?"
	screen.call("_on_ai_send_button_pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var response_snapshot := _read_dictionary(screen.call("get_debug_snapshot"))
	assert_false(bool(response_snapshot.get("ai_request_in_flight", true)))
	assert_eq(str(response_snapshot.get("ai_response_text", "")), "fake response")
	var ai_service_value: Variant = response_snapshot.get("ai_service", {})
	assert_true(ai_service_value is Dictionary)
	if ai_service_value is Dictionary:
		var ai_service_snapshot: Dictionary = ai_service_value
		var history_value: Variant = ai_service_snapshot.get("history", [])
		assert_true(history_value is Array)
		if history_value is Array:
			var history: Array = history_value
			assert_eq(history.size(), 2)

	screen.call("_on_ai_back_to_topics_button_pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var return_snapshot := _read_dictionary(screen.call("get_debug_snapshot"))
	assert_false(bool(return_snapshot.get("ai_chat_active", true)))
	assert_not_null(_find_button_with_text(screen, "Talk freely."))


func test_hybrid_branch_is_hidden_when_ai_is_disabled() -> void:
	AIManager.initialize(_make_settings({
		APP_SETTINGS.AI_ENABLED: false,
		APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_DISABLED,
	}))
	var screen := _instantiate_dialogue_screen({
		"speaker_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
		"dialogue_resource": AI_HANDOFF_DIALOGUE,
		"dialogue_start": "start",
		"ai_mode": "hybrid",
	})

	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(_find_button_with_text(screen, "Talk freely."))
	assert_not_null(_find_button_with_text(screen, "Maybe later."))


func test_freeform_mode_opens_directly_into_ai_chat() -> void:
	var screen := _instantiate_dialogue_screen({
		"speaker_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
		"dialogue_resource": AI_HANDOFF_DIALOGUE,
		"dialogue_start": "start",
		"ai_mode": "freeform",
	})

	await get_tree().process_frame
	await get_tree().process_frame

	var snapshot := _read_dictionary(screen.call("get_debug_snapshot"))
	assert_true(bool(snapshot.get("ai_chat_active", false)))
	var back_to_topics_button := screen.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIBackToTopicsButton"
	) as Button
	assert_not_null(back_to_topics_button)
	if back_to_topics_button != null:
		assert_false(back_to_topics_button.visible)


func test_history_window_setting_limits_dialogue_ai_history() -> void:
	APP_SETTINGS.save_settings(_make_settings({
		APP_SETTINGS.AI_ENABLED: true,
		APP_SETTINGS.AI_PROVIDER: APP_SETTINGS.AI_PROVIDER_OPENAI_COMPATIBLE,
		APP_SETTINGS.AI_MODEL: "fake-model",
		APP_SETTINGS.AI_CHAT_HISTORY_WINDOW: 1,
		APP_SETTINGS.AI_STREAMING_SPEED: 0.0,
		"ready": true,
	}))
	var screen := _instantiate_dialogue_screen({
		"speaker_entity_id": TEST_FIXTURE_WORLD.fixture_vendor_id(),
		"dialogue_resource": AI_HANDOFF_DIALOGUE,
		"dialogue_start": "start",
		"ai_mode": "freeform",
	})

	await get_tree().process_frame
	await get_tree().process_frame

	var ai_input := screen.get_node(
		"MarginContainer/PanelContainer/VBoxContainer/MainContent/ConversationScroll/ConversationPanel/AIChatContainer/AIInputRow/AIInput"
	) as LineEdit
	assert_not_null(ai_input)
	if ai_input == null:
		return
	ai_input.text = "First question"
	screen.call("_on_ai_send_button_pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	ai_input.text = "Second question"
	screen.call("_on_ai_send_button_pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var snapshot := _read_dictionary(screen.call("get_debug_snapshot"))
	var ai_service_value: Variant = snapshot.get("ai_service", {})
	assert_true(ai_service_value is Dictionary)
	if not ai_service_value is Dictionary:
		return
	var ai_service_snapshot: Dictionary = ai_service_value
	assert_eq(int(ai_service_snapshot.get("history_window_turns", 0)), 1)
	var history_value: Variant = ai_service_snapshot.get("history", [])
	assert_true(history_value is Array)
	if history_value is Array:
		var history: Array = history_value
		assert_eq(history.size(), 2)
		assert_eq(str(history[0].get("content", "")), "Second question")
		assert_eq(str(history[1].get("content", "")), "fake response")


func _instantiate_dialogue_screen(params: Dictionary) -> Control:
	var instance_value: Variant = DIALOGUE_SCREEN_SCENE.instantiate()
	assert_true(instance_value is Control)
	var screen: Control = instance_value
	_spawned_nodes.append(screen)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(screen)
	screen.call("initialize", params)
	return screen


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	_spawned_nodes.append(viewport)
	return viewport


func _find_button_with_text(root: Node, text: String) -> Button:
	if root == null or not is_instance_valid(root):
		return null
	for child in root.get_children():
		var button := child as Button
		if button != null and button.text == text:
			return button
		var nested_button := _find_button_with_text(child, text)
		if nested_button != null:
			return nested_button
	return null


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _seed_ai_fixture_vendor() -> void:
	DataManager.ai_personas[FIXTURE_PERSONA_ID] = {
		"persona_id": FIXTURE_PERSONA_ID,
		"display_name": "Fixture Vendor Persona",
		"system_prompt_template": "You are {display_name} at {location_name} working for {faction_name}.",
		"personality_traits": ["steady", "professional"],
		"speech_style": "Brief and practical.",
		"knowledge_scope": ["fixture_faction"],
		"response_constraints": {
			"max_sentences": 3,
			"always_in_character": true,
		},
		"fallback_lines": [
			"I can stick to the basics.",
			"Let's keep this practical.",
		],
	}
	var fixture_vendor := DataManager.get_entity(TEST_FIXTURE_WORLD.fixture_vendor_id())
	fixture_vendor["ai_persona_id"] = FIXTURE_PERSONA_ID
	DataManager.entities[TEST_FIXTURE_WORLD.fixture_vendor_id()] = fixture_vendor
	DataManager.factions[FIXTURE_FACTION_ID] = {
		"faction_id": FIXTURE_FACTION_ID,
		"display_name": "Fixture Faction",
		"description": "Keeps the fixture district running.",
		"territory": [TEST_FIXTURE_WORLD.connected_location_id()],
	}


func _make_settings(ai_overrides: Dictionary) -> Dictionary:
	var settings := APP_SETTINGS.get_default_settings()
	var ai_settings := APP_SETTINGS.get_ai_settings(settings)
	for key_value in ai_overrides.keys():
		ai_settings[str(key_value)] = ai_overrides.get(key_value, null)
	settings[APP_SETTINGS.SECTION_AI] = ai_settings
	return settings


func _delete_settings_file() -> void:
	var settings_path := APP_SETTINGS.get_settings_path()
	if not FileAccess.file_exists(settings_path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
