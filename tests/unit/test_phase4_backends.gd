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
const CRAFTING_BACKEND := preload("res://ui/screens/backends/crafting_backend.gd")
const WORLD_MAP_BACKEND := preload("res://ui/screens/backends/world_map_backend.gd")


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
	assert_true(registered_backend_classes.has("ActiveQuestLogBackend"))
	assert_true(registered_backend_classes.has("FactionReputationBackend"))
	assert_true(registered_backend_classes.has("AchievementListBackend"))
	assert_true(registered_backend_classes.has("EventLogBackend"))
	assert_true(registered_backend_classes.has("WorldMapBackend"))


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


func test_task_provider_backend_lists_faction_tasks_and_accepts_selected_task() -> void:
	DataManager.factions["base:test_faction"] = {
		"faction_id": "base:test_faction",
		"display_name": "Test Faction",
		"quest_pool": ["base:test_task"],
	}
	DataManager.tasks["base:test_task"] = {
		"template_id": "base:test_task",
		"display_name": "Courier Run",
		"description": "Deliver the package to the marked drop point.",
		"type": "DELIVER",
		"target": "base:start",
		"travel_cost": 2,
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

	assert_eq(GameState.active_tasks.size(), 1)


func test_dialogue_backend_resolves_sample_dialogue_resource() -> void:
	var backend: RefCounted = DIALOGUE_BACKEND.new()
	backend.initialize({
		"dialogue_resource": "res://tests/fixtures/dialogue/sample_greeting.dialogue",
		"screen_title": "Talk",
	})

	var view_model: Dictionary = backend.build_view_model()

	assert_eq(str(view_model.get("title", "")), "Talk")
	assert_eq(str(view_model.get("dialogue_resource", "")), "res://tests/fixtures/dialogue/sample_greeting.dialogue")
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
		var position: Dictionary = position_value
		var position_key := "%s|%s" % [str(position.get("x", "")), str(position.get("y", ""))]
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
