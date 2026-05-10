extends GutTest

const ACTIVITY_SERVICE := preload("res://systems/activity_service.gd")
const APP_SETTINGS := preload("res://core/app_settings.gd")
const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")

const ACTIVITY_ID := "base:activity_encounter_handoff"
const ENCOUNTER_ID := "base:activity_handoff_encounter"
const OPPONENT_ID := "base:activity_handoff_opponent"

var _screen_container: CanvasLayer = null
var _test_viewport: SubViewport = null


func before_each() -> void:
	_configure_ai_disabled()
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	DataManager.activities.clear()
	_seed_encounter_fixture()
	_seed_encounter_activity()
	GameEvents.clear_event_history()
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	_screen_container = CanvasLayer.new()
	_test_viewport = _create_test_viewport()
	assert_not_null(_test_viewport)
	_test_viewport.add_child(_screen_container)
	UIRouter.initialize(_screen_container)
	UIRouter.register_screen(UI_ROUTE_CATALOG.SCREEN_ENCOUNTER, UI_ROUTE_CATALOG.ENCOUNTER_SCENE)


func after_each() -> void:
	while UIRouter.stack_depth() > 0:
		UIRouter.pop()
	await get_tree().process_frame
	if is_instance_valid(_screen_container):
		_screen_container.free()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	await get_tree().process_frame
	_test_viewport = null
	GameEvents.clear_event_history()
	GameState.reset()
	_configure_ai_disabled()


func test_activity_completion_action_routes_to_encounter_screen_without_resolving() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var credits_before := player.get_currency("credits")
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity(ACTIVITY_ID)
	await get_tree().process_frame

	assert_true(bool(result.get("success", false)))
	assert_eq(UIRouter.current_screen_id(), UI_ROUTE_CATALOG.SCREEN_ENCOUNTER)
	assert_eq(UIRouter.stack_depth(), 1)
	assert_eq(str(UIRouter.current_screen_params().get("encounter_id", "")), ENCOUNTER_ID)
	assert_signal_emitted(GameEvents, "encounter_started")
	assert_signal_not_emitted(GameEvents, "encounter_resolved")
	assert_false(_has_runtime_event("encounter_resolved"))
	assert_eq(player.get_currency("credits"), credits_before)


func test_encounter_backend_owns_resolution_and_rewards_after_activity_handoff() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var credits_before := player.get_currency("credits")
	watch_signals(GameEvents)

	var result := ACTIVITY_SERVICE.execute_activity(ACTIVITY_ID)
	await get_tree().process_frame

	assert_true(bool(result.get("success", false)))
	assert_signal_not_emitted(GameEvents, "encounter_resolved")
	assert_eq(player.get_currency("credits"), credits_before)

	var backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
	backend.initialize({"encounter_id": ENCOUNTER_ID})
	backend.select_action("finish")

	assert_signal_emitted(GameEvents, "encounter_resolved")
	assert_eq(backend.get_resolved_outcome_id(), "victory")
	assert_eq(player.get_currency("credits"), credits_before + 7.0)
	assert_true(_has_runtime_event("encounter_resolved"))


func _seed_encounter_activity() -> void:
	DataManager.activities[ACTIVITY_ID] = {
		"activity_id": ACTIVITY_ID,
		"display_name": "Encounter Handoff",
		"description": "Routes into an encounter through normal screen actions.",
		"category": "test",
		"duration_ticks": 0,
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"travel_policy": "must_be_present",
		"completion_actions": [
			{
				"type": "push_screen",
				"screen_id": UI_ROUTE_CATALOG.SCREEN_ENCOUNTER,
				"params": {
					"encounter_id": ENCOUNTER_ID,
				},
			}
		],
	}


func _seed_encounter_fixture() -> void:
	var opponent_template := {
		"entity_id": OPPONENT_ID,
		"display_name": "Activity Handoff Opponent",
		"description": "Fixture opponent for activity encounter handoff tests.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {"health": 10, "health_max": 10},
		"inventory": [],
	}
	DataManager.entities[OPPONENT_ID] = opponent_template.duplicate(true)
	var opponent := EntityInstance.from_template(opponent_template)
	GameState.commit_entity_instance(opponent)
	DataManager.encounters[ENCOUNTER_ID] = {
		"encounter_id": ENCOUNTER_ID,
		"display_name": "Activity Handoff Encounter",
		"participants": {
			"player": {"entity_id": "player"},
			"opponent": {"entity_id": OPPONENT_ID},
		},
		"actions": {
			"player": [
				{
					"action_id": "finish",
					"label": "Finish",
					"on_success": [
						{"effect": "resolve", "outcome_id": "victory"},
					],
				},
			],
			"opponent": [],
		},
		"resolution": {
			"outcomes": [
				{
					"outcome_id": "victory",
					"trigger": "manual",
					"screen_text": "Won.",
					"reward": {"credits": 7},
				},
			],
		},
	}


func _has_runtime_event(event_type: String) -> bool:
	for event_value in GameState.event_history:
		if not event_value is Dictionary:
			continue
		var event_entry: Dictionary = event_value
		if str(event_entry.get("event_type", "")) == event_type:
			return true
	return false


func _configure_ai_disabled() -> void:
	AIManager.initialize({
		APP_SETTINGS.SECTION_AI: {
			APP_SETTINGS.AI_ENABLED: false,
			APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_DISABLED,
			APP_SETTINGS.AI_ENABLE_WORLD_GEN: false,
		},
	})


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestActivityEncounterHandoffViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
