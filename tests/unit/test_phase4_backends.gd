extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const EXCHANGE_BACKEND := preload("res://ui/screens/backends/exchange_backend.gd")
const CATALOG_LIST_BACKEND := preload("res://ui/screens/backends/catalog_list_backend.gd")
const LIST_BACKEND := preload("res://ui/screens/backends/list_backend.gd")
const CHALLENGE_BACKEND := preload("res://ui/screens/backends/challenge_backend.gd")
const TASK_PROVIDER_BACKEND := preload("res://ui/screens/backends/task_provider_backend.gd")
const DIALOGUE_BACKEND := preload("res://ui/screens/backends/dialogue_backend.gd")
const ENTITY_SHEET_BACKEND := preload("res://ui/screens/backends/entity_sheet_backend.gd")
const OWNED_ENTITIES_BACKEND := preload("res://ui/screens/backends/owned_entities_backend.gd")
const CRAFTING_BACKEND := preload("res://ui/screens/backends/crafting_backend.gd")
const WORLD_MAP_BACKEND := preload("res://ui/screens/backends/world_map_backend.gd")
const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")


func before_each() -> void:
	GameEvents.clear_event_history()
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()


func test_mod_loader_registers_phase4_backend_contracts() -> void:
	var registered_backend_classes := BACKEND_CONTRACT_REGISTRY.get_registered_backend_classes()

	assert_true(registered_backend_classes.has("AssemblyEditorBackend"))
	assert_true(registered_backend_classes.has("ExchangeBackend"))
	assert_true(registered_backend_classes.has("ListBackend"))
	assert_true(registered_backend_classes.has("ChallengeBackend"))
	assert_true(registered_backend_classes.has("TaskProviderBackend"))
	assert_true(registered_backend_classes.has("CatalogListBackend"))
	assert_true(registered_backend_classes.has("CraftingBackend"))
	assert_true(registered_backend_classes.has("DialogueBackend"))
	assert_true(registered_backend_classes.has("EntitySheetBackend"))
	assert_true(registered_backend_classes.has("OwnedEntitiesBackend"))
	assert_true(registered_backend_classes.has("ActiveQuestLogBackend"))
	assert_true(registered_backend_classes.has("FactionReputationBackend"))
	assert_true(registered_backend_classes.has("AchievementListBackend"))
	assert_true(registered_backend_classes.has("EventLogBackend"))
	assert_true(registered_backend_classes.has("WorldMapBackend"))
	assert_true(registered_backend_classes.has("EncounterBackend"))


func test_exchange_backend_moves_stocked_part_and_transfers_currency() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var vendor := TEST_FIXTURE_WORLD.add_runtime_vendor()

	var backend: RefCounted = EXCHANGE_BACKEND.new()
	backend.initialize({
		"source_inventory": "entity:base:test_vendor:inventory",
		"destination_inventory": "player:inventory",
		"currency_id": "credits",
	})

	var initial_player_inventory_size := player.inventory.size()
	var initial_player_credits := player.get_currency("credits")
	var initial_vendor_credits := vendor.get_currency("credits")
	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	var rows: Array = rows_value
	assert_eq(rows.size(), 1)

	backend.confirm()

	var updated_vendor := GameState.get_entity_instance("base:test_vendor")
	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.inventory.size(), initial_player_inventory_size + 1)
		assert_eq(updated_player.get_currency("credits"), initial_player_credits - 8.0)
	assert_not_null(updated_vendor)
	if updated_vendor != null:
		assert_eq(updated_vendor.inventory.size(), 0)
		assert_eq(updated_vendor.get_currency("credits"), initial_vendor_credits + 8.0)


func test_catalog_list_backend_mints_new_part_for_buyer() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var backend: RefCounted = CATALOG_LIST_BACKEND.new()
	backend.initialize({
		"data_source": "catalog",
		"action_payload": {"type": "buy_item"},
		"buyer_entity_id": "player",
		"currency_id": "credits",
		"template_ids": ["base:body_arm_standard"],
	})

	var initial_inventory_size := player.inventory.size()
	var initial_credits := player.get_currency("credits")
	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	var rows: Array = rows_value
	assert_eq(rows.size(), 1)

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.inventory.size(), initial_inventory_size + 1)
		assert_eq(updated_player.get_currency("credits"), initial_credits - 8.0)


func test_list_backend_builds_inventory_rows_from_player_inventory() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var template := DataManager.get_part("base:body_arm_standard")
	assert_false(template.is_empty())
	if template.is_empty():
		return
	player.add_part(PartInstance.from_template(template))

	var backend: RefCounted = LIST_BACKEND.new()
	backend.initialize({
		"data_source": "player:inventory",
		"screen_title": "Inventory",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_eq(str(view_model.get("title", "")), "Inventory")
	assert_true(rows_value is Array)
	var rows: Array = rows_value
	assert_true(rows.size() >= 1)
	assert_eq(str(view_model.get("detail_kind", "")), "part_card")


func test_list_backend_actions_use_selected_inventory_instance() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var template := DataManager.get_part("base:body_arm_standard")
	assert_false(template.is_empty())
	if template.is_empty():
		return
	var first_part := PartInstance.from_template(template)
	first_part.instance_id = "phase4_keep_arm"
	var second_part := PartInstance.from_template(template)
	second_part.instance_id = "phase4_remove_arm"
	player.add_part(first_part)
	player.add_part(second_part)

	var backend: RefCounted = LIST_BACKEND.new()
	backend.initialize({
		"data_source": "player:inventory",
		"action_payload": {"type": "remove_part"},
	})
	backend.build_view_model()
	backend.select_row("phase4_remove_arm")

	backend.confirm()

	assert_true(_inventory_has_instance(player, "phase4_keep_arm"))
	assert_false(_inventory_has_instance(player, "phase4_remove_arm"))


func test_list_backend_uses_shared_quest_card_view_model_for_active_quests() -> void:
	TEST_FIXTURE_WORLD.seed_phase5_runtime()
	GameState.flags["phase5_ready"] = true
	var backend: RefCounted = LIST_BACKEND.new()
	backend.initialize({
		"data_source": "game_state.active_quests",
		"screen_title": "Quest List",
	})

	var view_model: Dictionary = backend.build_view_model()
	var selected_detail_value: Variant = view_model.get("selected_detail", {})

	assert_eq(str(view_model.get("detail_kind", "")), "quest_card")
	assert_true(selected_detail_value is Dictionary)
	if selected_detail_value is Dictionary:
		var selected_detail: Dictionary = selected_detail_value
		assert_eq(str(selected_detail.get("quest_id", "")), "base:phase5_quest")
		var objectives_value: Variant = selected_detail.get("objectives", [])
		assert_true(objectives_value is Array)
		if objectives_value is Array:
			var objectives: Array = objectives_value
			assert_eq(objectives.size(), 1)
			if objectives[0] is Dictionary:
				var objective: Dictionary = objectives[0]
				assert_true(bool(objective.get("satisfied", false)))


func test_challenge_backend_applies_success_reward_to_player() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var backend: RefCounted = CHALLENGE_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"required_stat": "strength",
		"required_value": 1,
		"reward": {"credits": 15},
	})

	var initial_credits := player.get_currency("credits")
	var view_model: Dictionary = backend.build_view_model()

	assert_true(bool(view_model.get("confirm_enabled", false)))

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(updated_player.get_currency("credits"), initial_credits + 15.0)


func test_challenge_backend_defers_reward_events_until_after_commit() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var backend: RefCounted = CHALLENGE_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"required_stat": "strength",
		"required_value": 1,
		"reward": {
			"credits": 7,
			"items": ["base:body_arm_standard"],
			"flags": {"phase4_rewarded": true},
		},
	})

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player == null:
		return
	assert_eq(updated_player.get_flag("phase4_rewarded", false), true)
	assert_true(_inventory_has_template(updated_player, "base:body_arm_standard"))
	assert_true(_event_history_contains("entity_currency_changed"))
	assert_true(_event_history_contains("part_acquired"))
	assert_true(_event_history_contains("flag_changed"))


func test_task_provider_backend_lists_faction_contracts_and_accepts_selected_quest() -> void:
	DataManager.factions["base:test_faction"] = {
		"faction_id": "base:test_faction",
		"display_name": "Test Faction",
		"quest_pool": ["base:test_contract"],
	}
	DataManager.quests["base:test_contract"] = {
		"quest_id": "base:test_contract",
		"display_name": "Courier Run",
		"description": "Deliver the package to the marked drop point.",
		"stages": [
			{
				"description": "Wait for dispatch.",
				"objectives": [
					{"type": "has_flag", "flag_id": "dispatch_ready", "value": true}
				]
			}
		],
		"reward": {"credits": 5},
		"repeatable": true,
	}

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:test_faction",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])
	var portrait_value: Variant = view_model.get("portrait", {})

	assert_true(rows_value is Array)
	assert_true(portrait_value is Dictionary)
	if portrait_value is Dictionary:
		var portrait: Dictionary = portrait_value
		var faction_badge_value: Variant = portrait.get("faction_badge", {})
		assert_true(faction_badge_value is Dictionary)
		if faction_badge_value is Dictionary:
			var faction_badge: Dictionary = faction_badge_value
			assert_eq(str(faction_badge.get("faction_id", "")), "base:test_faction")
	var rows: Array = rows_value
	assert_eq(rows.size(), 1)

	backend.confirm()

	assert_eq(GameState.active_quests.size(), 1)
	assert_true(GameState.active_quests.has("base:test_contract"))


func test_task_provider_backend_can_assign_and_dispatch_owned_entity() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.tasks["base:test_assignment_travel"] = {
		"template_id": "base:test_assignment_travel",
		"display_name": "Travel",
		"type": "TRAVEL",
		"duration": 1,
		"repeatable": true,
	}
	DataManager.factions["base:test_faction"] = {
		"faction_id": "base:test_faction",
		"display_name": "Test Faction",
		"quest_pool": ["base:test_dispatch_contract"],
	}
	DataManager.quests["base:test_dispatch_contract"] = {
		"quest_id": "base:test_dispatch_contract",
		"display_name": "Field Delivery",
		"description": "Send an assigned entity to the field.",
		"stages": [
			{
				"description": "Reach the field.",
				"objectives": [
					{
						"type": "reach_location",
						"entity_id": "quest:assignee",
						"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
					}
				]
			}
		],
		"reward": {"credits": 5},
		"repeatable": true,
	}
	var drone_template := {
		"entity_id": "base:test_dispatch_drone",
		"display_name": "Dispatch Drone",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {},
	}
	DataManager.entities["base:test_dispatch_drone"] = drone_template.duplicate(true)
	GameState.commit_entity_instance(EntityInstance.from_template(drone_template), "base:test_dispatch_drone")
	player.owned_entity_ids = ["base:test_dispatch_drone"]
	GameEvents.clear_event_history()

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:test_faction",
		"assignee_entity_id": "base:test_dispatch_drone",
		"owner_entity_id": "player",
		"assignment_task_template_id": "base:test_assignment_travel",
		"auto_dispatch_first_reach_location": true,
		"return_to_owned_entities": true,
	})

	var view_model: Dictionary = backend.build_view_model()
	assert_eq(str(view_model.get("confirm_label", "")), "Assign and Dispatch")

	var action: Dictionary = backend.confirm()

	assert_true(GameState.active_quests.has("base:test_dispatch_contract"))
	assert_eq(GameState.active_tasks.size(), 1)
	if not GameState.active_tasks.is_empty():
		var task_value: Variant = GameState.active_tasks.values()[0]
		assert_true(task_value is Dictionary)
		if task_value is Dictionary:
			var task: Dictionary = task_value
			assert_eq(str(task.get("entity_id", "")), "base:test_dispatch_drone")
			assert_eq(str(task.get("target", "")), TEST_FIXTURE_WORLD.connected_location_id())
	assert_eq(str(action.get("screen_id", "")), "owned_entities")
	var action_params_value: Variant = action.get("params", {})
	assert_true(action_params_value is Dictionary)
	if action_params_value is Dictionary:
		var action_params: Dictionary = action_params_value
		assert_eq(str(action_params.get("selected_entity_id", "")), "base:test_dispatch_drone")
		assert_eq(str(action_params.get("suggested_location_id", "")), TEST_FIXTURE_WORLD.connected_location_id())
	var notifications := GameEvents.get_event_history(0, "ui", "ui_notification_requested")
	assert_eq(notifications.size(), 1)
	if not notifications.is_empty():
		var notification: Dictionary = notifications[0]
		var args_value: Variant = notification.get("args", [])
		assert_true(args_value is Array)
		if args_value is Array:
			var args: Array = args_value
			assert_eq(str(args[0]), "Accepted Field Delivery and sent Dispatch Drone to Fixture Field.")


func test_assigned_owned_entity_continues_through_multi_stage_reach_location_quest() -> void:
	var depot_location_id := "base:test_depot"
	var field_location: Variant = DataManager.locations.get(TEST_FIXTURE_WORLD.connected_location_id(), {})
	assert_true(field_location is Dictionary)
	if field_location is Dictionary:
		var field: Dictionary = field_location
		var field_connections_value: Variant = field.get("connections", {})
		if field_connections_value is Dictionary:
			var field_connections: Dictionary = field_connections_value
			field_connections[depot_location_id] = 1
			field["connections"] = field_connections
			DataManager.locations[TEST_FIXTURE_WORLD.connected_location_id()] = field
	DataManager.locations[depot_location_id] = {
		"location_id": depot_location_id,
		"display_name": "Fixture Depot",
		"description": "A second delivery stop.",
		"connections": {
			TEST_FIXTURE_WORLD.connected_location_id(): 1,
		},
		"screens": [],
	}
	DataManager.tasks["base:test_assignment_travel"] = {
		"template_id": "base:test_assignment_travel",
		"display_name": "Travel",
		"type": "TRAVEL",
		"duration": 1,
		"repeatable": true,
	}
	DataManager.factions["base:test_faction"] = {
		"faction_id": "base:test_faction",
		"display_name": "Test Faction",
		"quest_pool": ["base:test_multi_stop_contract"],
	}
	DataManager.quests["base:test_multi_stop_contract"] = {
		"quest_id": "base:test_multi_stop_contract",
		"display_name": "Multi Stop Delivery",
		"description": "Send an assigned entity through two stops.",
		"stages": [
			{
				"description": "Reach the field.",
				"objectives": [
					{
						"type": "reach_location",
						"entity_id": "quest:assignee",
						"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
					}
				],
			},
			{
				"description": "Reach the depot.",
				"objectives": [
					{
						"type": "reach_location",
						"entity_id": "quest:assignee",
						"location_id": depot_location_id,
					}
				],
			},
		],
		"reward": {"credits": 7},
		"repeatable": true,
	}
	var drone_template := {
		"entity_id": "base:test_multi_stop_drone",
		"display_name": "Route Drone",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {},
	}
	DataManager.entities["base:test_multi_stop_drone"] = drone_template.duplicate(true)
	GameState.commit_entity_instance(EntityInstance.from_template(drone_template), "base:test_multi_stop_drone")

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:test_faction",
		"assignee_entity_id": "base:test_multi_stop_drone",
		"owner_entity_id": "player",
		"assignment_task_template_id": "base:test_assignment_travel",
		"auto_dispatch_first_reach_location": true,
	})
	backend.build_view_model()

	backend.confirm()
	assert_true(GameState.active_quests.has("base:test_multi_stop_contract"))
	assert_eq(GameState.active_tasks.size(), 1)
	_assert_single_active_task_target("base:test_multi_stop_drone", TEST_FIXTURE_WORLD.connected_location_id())

	TimeKeeper.advance_tick()
	assert_true(GameState.active_quests.has("base:test_multi_stop_contract"))
	var quest_value: Variant = GameState.active_quests.get("base:test_multi_stop_contract", {})
	assert_true(quest_value is Dictionary)
	if quest_value is Dictionary:
		var quest: Dictionary = quest_value
		assert_eq(int(quest.get("stage_index", -1)), 1)
	_assert_single_active_task_target("base:test_multi_stop_drone", depot_location_id)
	var drone := GameState.get_entity_instance("base:test_multi_stop_drone")
	assert_not_null(drone)
	if drone != null:
		assert_eq(drone.location_id, TEST_FIXTURE_WORLD.connected_location_id())

	TimeKeeper.advance_tick()
	assert_false(GameState.active_quests.has("base:test_multi_stop_contract"))
	assert_true("base:test_multi_stop_contract" in GameState.completed_quests)
	assert_eq(GameState.active_tasks.size(), 0)
	if drone != null:
		assert_eq(drone.location_id, depot_location_id)


func test_task_provider_backend_hides_contract_active_under_runtime_id() -> void:
	DataManager.factions["base:test_faction"] = {
		"faction_id": "base:test_faction",
		"display_name": "Test Faction",
		"quest_pool": ["base:test_contract"],
	}
	DataManager.quests["base:test_contract"] = {
		"quest_id": "base:test_contract",
		"display_name": "Courier Run",
		"description": "Deliver the package to the marked drop point.",
		"stages": [],
		"repeatable": true,
	}
	GameState.active_quests["runtime_contract_1"] = {
		"runtime_id": "runtime_contract_1",
		"quest_id": "base:test_contract",
		"stage_index": 0,
	}

	var backend: RefCounted = TASK_PROVIDER_BACKEND.new()
	backend.initialize({
		"faction_id": "base:test_faction",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 0)


func test_dialogue_backend_resolves_sample_dialogue_resource() -> void:
	var backend: RefCounted = DIALOGUE_BACKEND.new()
	backend.initialize({
		"dialogue_resource": "res://tests/fixtures/dialogue/fixture_dialogue_resource.tres",
		"screen_title": "Talk",
	})

	var view_model: Dictionary = backend.build_view_model()

	assert_eq(str(view_model.get("title", "")), "Talk")
	assert_eq(str(view_model.get("dialogue_resource", "")), "res://tests/fixtures/dialogue/fixture_dialogue_resource.tres")
	assert_eq(str(view_model.get("status_text", "")), "")


func test_world_map_backend_builds_graph_and_travels() -> void:
	var backend: RefCounted = WORLD_MAP_BACKEND.new()
	backend.initialize({
		"screen_title": "Map",
	})

	var view_model: Dictionary = backend.build_view_model()
	var locations_value: Variant = view_model.get("locations", [])
	var edges_value: Variant = view_model.get("edges", [])

	assert_eq(str(view_model.get("title", "")), "Map")
	assert_true(locations_value is Array)
	assert_true(edges_value is Array)
	if not locations_value is Array or not edges_value is Array:
		return
	var locations: Array = locations_value
	var edges: Array = edges_value
	assert_gt(locations.size(), 0)
	assert_gt(edges.size(), 0)
	assert_true(_map_rows_contain_location(locations, TEST_FIXTURE_WORLD.starting_location_id()))
	assert_true(_map_rows_have_distinct_positions(locations))

	var destination_id := _first_non_current_map_location(locations, GameState.current_location_id)
	assert_false(destination_id.is_empty())
	if destination_id.is_empty():
		return
	var tick_before := GameState.current_tick
	var result_value: Variant = backend.call("travel_to", destination_id)
	assert_true(result_value is Dictionary)
	if result_value is Dictionary:
		var result: Dictionary = result_value
		assert_eq(str(result.get("status", "")), "ok")
	assert_eq(GameState.current_location_id, destination_id)
	assert_eq(GameState.current_tick, tick_before + 1)


func test_world_map_backend_uses_total_route_cost_for_multi_hop_travel() -> void:
	var field_value: Variant = DataManager.locations.get("base:field", {})
	assert_true(field_value is Dictionary)
	if not field_value is Dictionary:
		return
	var field_location: Dictionary = field_value
	var field_connections_value: Variant = field_location.get("connections", {})
	assert_true(field_connections_value is Dictionary)
	if not field_connections_value is Dictionary:
		return
	var field_connections: Dictionary = field_connections_value
	field_connections["base:outpost"] = 2
	field_location["connections"] = field_connections
	DataManager.locations["base:field"] = field_location
	DataManager.locations["base:outpost"] = {
		"location_id": "base:outpost",
		"display_name": "Outpost",
		"description": "Fixture outpost location.",
		"connections": {
			"base:field": 2,
		},
		"screens": [],
	}

	var backend: RefCounted = WORLD_MAP_BACKEND.new()
	backend.initialize({})

	var tick_before := GameState.current_tick
	var result_value: Variant = backend.call("travel_to", "base:outpost")

	assert_true(result_value is Dictionary)
	if result_value is Dictionary:
		var result: Dictionary = result_value
		assert_eq(str(result.get("status", "")), "ok")
	assert_eq(GameState.current_location_id, "base:outpost")
	assert_eq(GameState.current_tick, tick_before + 3)


func test_owned_entities_backend_lists_owned_entities_and_assigns_travel_task() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.tasks["base:test_travel_assignment"] = {
		"template_id": "base:test_travel_assignment",
		"display_name": "Travel",
		"type": "TRAVEL",
		"duration": 1,
		"repeatable": true,
	}
	var drone_template := {
		"entity_id": "base:test_drone",
		"display_name": "Test Drone",
		"description": "Fixture owned entity.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {"power": 1, "health": 20, "health_max": 20},
		"inventory": [],
	}
	DataManager.entities["base:test_drone"] = drone_template.duplicate(true)
	var drone := EntityInstance.from_template(drone_template)
	GameState.commit_entity_instance(drone, "base:test_drone")
	player.owned_entity_ids = ["base:test_drone"]
	GameState.active_tasks["task_old"] = {
		"runtime_id": "task_old",
		"template_id": "base:test_travel_assignment",
		"entity_id": "base:test_drone",
		"type": "WAIT",
		"remaining_ticks": 9,
	}

	var backend: RefCounted = OWNED_ENTITIES_BACKEND.new()
	backend.initialize({
		"owner_entity_id": "player",
		"assignment_task_template_id": "base:test_travel_assignment",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])
	var locations_value: Variant = view_model.get("locations", [])

	assert_true(rows_value is Array)
	assert_true(locations_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if rows.size() > 0 and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("entity_id", "")), "base:test_drone")

	backend.assign_selected_to_location(TEST_FIXTURE_WORLD.connected_location_id())

	assert_eq(GameState.active_tasks.size(), 1)
	assert_false(GameState.active_tasks.has("task_old"))
	if GameState.active_tasks.is_empty():
		return
	var active_task_value: Variant = GameState.active_tasks.values()[0]
	assert_true(active_task_value is Dictionary)
	if active_task_value is Dictionary:
		var active_task: Dictionary = active_task_value
		assert_eq(str(active_task.get("entity_id", "")), "base:test_drone")
		assert_eq(str(active_task.get("target", "")), TEST_FIXTURE_WORLD.connected_location_id())
		assert_eq(str(active_task.get("type", "")), "TRAVEL")


func test_owned_entities_backend_filters_sorts_and_uses_configured_summary_stats() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var idle_template := {
		"entity_id": "base:test_idle_drone",
		"display_name": "Alpha Drone",
		"description": "Idle fixture.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {"power": 3, "health": 10, "health_max": 10},
		"inventory": [],
	}
	var busy_template := {
		"entity_id": "base:test_busy_drone",
		"display_name": "Beta Drone",
		"description": "Busy fixture.",
		"location_id": TEST_FIXTURE_WORLD.connected_location_id(),
		"stats": {"power": 7, "health": 15, "health_max": 15},
		"inventory": [],
	}
	DataManager.entities["base:test_idle_drone"] = idle_template.duplicate(true)
	DataManager.entities["base:test_busy_drone"] = busy_template.duplicate(true)
	var idle_drone := EntityInstance.from_template(idle_template)
	var busy_drone := EntityInstance.from_template(busy_template)
	GameState.commit_entity_instance(idle_drone, "base:test_idle_drone")
	GameState.commit_entity_instance(busy_drone, "base:test_busy_drone")
	player.owned_entity_ids = ["base:test_busy_drone", "base:test_idle_drone"]
	GameState.active_tasks["task_busy"] = {
		"runtime_id": "task_busy",
		"template_id": "base:goto_location",
		"entity_id": "base:test_busy_drone",
		"type": "WAIT",
		"remaining_ticks": 4,
	}

	var backend: RefCounted = OWNED_ENTITIES_BACKEND.new()
	backend.initialize({
		"owner_entity_id": "player",
		"initial_filter": "idle",
		"initial_sort": "location",
		"summary_stat_ids": ["power"],
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if rows.size() > 0 and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("entity_id", "")), "base:test_idle_drone")
			assert_eq(str(row.get("stat_preview_text", "")), "Power 3")

	backend.set_roster_controls("beta", "all", "name")
	view_model = backend.build_view_model()
	rows_value = view_model.get("rows", [])
	assert_true(rows_value is Array)
	if rows_value is Array:
		var searched_rows: Array = rows_value
		assert_eq(searched_rows.size(), 1)
		if searched_rows.size() > 0 and searched_rows[0] is Dictionary:
			var searched_row: Dictionary = searched_rows[0]
			assert_eq(str(searched_row.get("entity_id", "")), "base:test_busy_drone")


func test_owned_entities_backend_can_queue_assignment_behind_active_task() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.tasks["base:test_queue_travel"] = {
		"template_id": "base:test_queue_travel",
		"display_name": "Travel",
		"type": "TRAVEL",
		"repeatable": true,
	}
	DataManager.tasks["base:test_queue_wait"] = {
		"template_id": "base:test_queue_wait",
		"display_name": "Wait",
		"type": "WAIT",
		"duration": 1,
		"repeatable": true,
	}
	var drone_template := {
		"entity_id": "base:test_queue_drone",
		"display_name": "Queue Drone",
		"description": "Queue fixture.",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {"power": 1},
		"inventory": [],
	}
	DataManager.entities["base:test_queue_drone"] = drone_template.duplicate(true)
	var drone := EntityInstance.from_template(drone_template)
	GameState.commit_entity_instance(drone, "base:test_queue_drone")
	player.owned_entity_ids = ["base:test_queue_drone"]
	var wait_runtime_id := TimeKeeper.accept_task("base:test_queue_wait", {
		"entity_id": "base:test_queue_drone",
		"allow_duplicate": true,
	})
	assert_false(wait_runtime_id.is_empty())
	var backend: RefCounted = OWNED_ENTITIES_BACKEND.new()
	backend.initialize({
		"owner_entity_id": "player",
		"assignment_task_template_id": "base:test_queue_travel",
		"assignment_start_mode": "queue",
		"selected_entity_id": "base:test_queue_drone",
	})

	backend.assign_selected_to_location(TEST_FIXTURE_WORLD.connected_location_id())

	assert_eq(GameState.active_tasks.size(), 2)
	var queued_count := 0
	for task_value in GameState.active_tasks.values():
		if task_value is Dictionary:
			var task: Dictionary = task_value
			if str(task.get("entity_id", "")) == "base:test_queue_drone" and str(task.get("status", "active")) == "queued":
				queued_count += 1
	assert_eq(queued_count, 1)
	var queued_view: Dictionary = backend.build_view_model()
	var selected_value: Variant = queued_view.get("selected_entity", {})
	assert_true(selected_value is Dictionary)
	if selected_value is Dictionary:
		var selected: Dictionary = selected_value
		assert_eq(int(selected.get("queued_task_count", 0)), 1)

	TimeKeeper.advance_tick()

	assert_false(GameState.active_tasks.has(wait_runtime_id))
	var active_travel_count := 0
	for task_value in GameState.active_tasks.values():
		if task_value is Dictionary:
			var task: Dictionary = task_value
			if str(task.get("entity_id", "")) == "base:test_queue_drone" and str(task.get("status", "active")) == "active":
				active_travel_count += 1
	assert_eq(active_travel_count, 1)


func test_owned_entity_task_completion_notifies_player_owner() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	DataManager.tasks["base:test_owned_wait"] = {
		"template_id": "base:test_owned_wait",
		"display_name": "Calibration",
		"type": "WAIT",
		"duration": 1,
		"repeatable": true,
	}
	var drone_template := {
		"entity_id": "base:test_notify_drone",
		"display_name": "Notify Drone",
		"location_id": TEST_FIXTURE_WORLD.starting_location_id(),
		"stats": {},
	}
	DataManager.entities["base:test_notify_drone"] = drone_template.duplicate(true)
	GameState.commit_entity_instance(EntityInstance.from_template(drone_template), "base:test_notify_drone")
	player.owned_entity_ids = ["base:test_notify_drone"]
	GameEvents.clear_event_history()

	var runtime_id := TimeKeeper.accept_task("base:test_owned_wait", {
		"entity_id": "base:test_notify_drone",
		"duration": 1,
		"allow_duplicate": true,
	})
	assert_false(runtime_id.is_empty())

	TimeKeeper.advance_tick()

	var notifications := GameEvents.get_event_history(0, "ui", "ui_notification_requested")
	assert_eq(notifications.size(), 1)
	if notifications.size() > 0:
		var entry: Dictionary = notifications[0]
		var args_value: Variant = entry.get("args", [])
		assert_true(args_value is Array)
		if args_value is Array:
			var args: Array = args_value
			assert_eq(str(args[0]), "Notify Drone completed Calibration.")


func test_entity_sheet_backend_builds_player_sheet_with_stats_and_equipment() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return

	player.set_equipped_template("hair", "base:body_hair_short")
	player.add_currency("gold", 12)

	var backend: RefCounted = ENTITY_SHEET_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"screen_title": "Character Sheet",
	})

	var view_model: Dictionary = backend.build_view_model()
	var stat_sheet_value: Variant = view_model.get("stat_sheet", {})
	var currency_rows_value: Variant = view_model.get("currency_rows", [])
	var equipped_rows_value: Variant = view_model.get("equipped_rows", [])

	assert_eq(str(view_model.get("title", "")), "Character Sheet")
	assert_true(stat_sheet_value is Dictionary)
	assert_true(currency_rows_value is Array)
	assert_true(equipped_rows_value is Array)
	if stat_sheet_value is Dictionary:
		var stat_sheet: Dictionary = stat_sheet_value
		var groups_value: Variant = stat_sheet.get("groups", {})
		assert_true(groups_value is Dictionary)
		if groups_value is Dictionary:
			var groups: Dictionary = groups_value
			assert_true(groups.has("combat"))
			assert_true(groups.has("survival"))
	if currency_rows_value is Array:
		var currency_rows: Array = currency_rows_value
		assert_true(currency_rows.size() >= 2)
		var found_credits := false
		for row_value in currency_rows:
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			if str(row.get("currency_id", "")) == "credits":
				found_credits = true
				break
		assert_true(found_credits)
	if equipped_rows_value is Array:
		var equipped_rows: Array = equipped_rows_value
		assert_true(equipped_rows.size() >= 2)
		var found_hair := false
		for row_value in equipped_rows:
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			if str(row.get("slot_id", "")) == "hair":
				found_hair = true
				break
		assert_true(found_hair)


func _inventory_has_instance(entity: EntityInstance, instance_id: String) -> bool:
	if entity == null:
		return false
	for part_value in entity.inventory:
		var part: PartInstance = part_value as PartInstance
		if part == null:
			continue
		if part.instance_id == instance_id:
			return true
	return false


func _inventory_has_template(entity: EntityInstance, template_id: String) -> bool:
	if entity == null:
		return false
	for part_value in entity.inventory:
		var part: PartInstance = part_value as PartInstance
		if part == null:
			continue
		if part.template_id == template_id:
			return true
	return false


func _event_history_contains(signal_name: String) -> bool:
	var history := GameEvents.get_event_history(0, "", signal_name)
	return not history.is_empty()


func _assert_single_active_task_target(entity_id: String, target_location_id: String) -> void:
	assert_eq(GameState.active_tasks.size(), 1)
	if GameState.active_tasks.is_empty():
		return
	var task_value: Variant = GameState.active_tasks.values()[0]
	assert_true(task_value is Dictionary)
	if not task_value is Dictionary:
		return
	var task: Dictionary = task_value
	assert_eq(str(task.get("entity_id", "")), entity_id)
	assert_eq(str(task.get("target", "")), target_location_id)


func _map_rows_contain_location(rows: Array, location_id: String) -> bool:
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		if str(row.get("location_id", "")) == location_id:
			return true
	return false


func _map_rows_have_distinct_positions(rows: Array) -> bool:
	var seen_positions: Dictionary = {}
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var position_value: Variant = row.get("position", {})
		if not position_value is Dictionary:
			continue
		var pos_dict: Dictionary = position_value
		var position_key := "%s|%s" % [str(pos_dict.get("x", "")), str(pos_dict.get("y", ""))]
		if seen_positions.has(position_key):
			return false
		seen_positions[position_key] = true
	return true


func _first_non_current_map_location(rows: Array, current_location_id: String) -> String:
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var location_id := str(row.get("location_id", ""))
		if not location_id.is_empty() and location_id != current_location_id:
			return location_id
	return ""
