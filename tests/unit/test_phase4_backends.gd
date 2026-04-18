extends GutTest

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const EXCHANGE_BACKEND := preload("res://ui/screens/backends/exchange_backend.gd")
const CATALOG_LIST_BACKEND := preload("res://ui/screens/backends/catalog_list_backend.gd")
const LIST_BACKEND := preload("res://ui/screens/backends/list_backend.gd")
const CHALLENGE_BACKEND := preload("res://ui/screens/backends/challenge_backend.gd")
const TASK_PROVIDER_BACKEND := preload("res://ui/screens/backends/task_provider_backend.gd")
const DIALOGUE_BACKEND := preload("res://ui/screens/backends/dialogue_backend.gd")


func before_each() -> void:
	GameEvents.clear_event_history()
	ModLoader.load_all_mods()
	GameState.new_game()
	TimeKeeper.stop()


func test_mod_loader_registers_phase4_backend_contracts() -> void:
	var registered_backend_classes := BACKEND_CONTRACT_REGISTRY.get_registered_backend_classes()

	assert_true(registered_backend_classes.has("AssemblyEditorBackend"))
	assert_true(registered_backend_classes.has("ExchangeBackend"))
	assert_true(registered_backend_classes.has("ListBackend"))
	assert_true(registered_backend_classes.has("ChallengeBackend"))
	assert_true(registered_backend_classes.has("TaskProviderBackend"))
	assert_true(registered_backend_classes.has("CatalogListBackend"))
	assert_true(registered_backend_classes.has("DialogueBackend"))


func test_exchange_backend_moves_stocked_part_and_transfers_currency() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var vendor_template := {
		"entity_id": "base:test_vendor",
		"display_name": "Test Vendor",
		"description": "Stocks a single test item.",
		"location_id": GameState.current_location_id,
		"currencies": {"credits": 0},
		"inventory": [
			{"instance_id": "base:test_vendor:arm", "template_id": "base:body_arm_standard"},
		],
		"interactions": [],
	}
	DataManager.entities["base:test_vendor"] = vendor_template.duplicate(true)
	var vendor := EntityInstance.from_template(vendor_template)
	GameState.commit_entity_instance(vendor, vendor.entity_id)

	var backend: RefCounted = EXCHANGE_BACKEND.new()
	backend.initialize({
		"source_inventory": "entity:base:test_vendor",
		"destination_inventory": "player",
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

	assert_true(rows_value is Array)
	var rows: Array = rows_value
	assert_eq(rows.size(), 1)

	backend.confirm()

	assert_eq(GameState.active_tasks.size(), 1)


func test_dialogue_backend_resolves_sample_dialogue_resource() -> void:
	var backend: RefCounted = DIALOGUE_BACKEND.new()
	backend.initialize({
		"dialogue_resource": "res://mods/base/dialogue/sample_greeting.dialogue",
		"screen_title": "Talk",
	})

	var view_model: Dictionary = backend.build_view_model()

	assert_eq(str(view_model.get("title", "")), "Talk")
	assert_eq(str(view_model.get("dialogue_resource", "")), "res://mods/base/dialogue/sample_greeting.dialogue")
	assert_eq(str(view_model.get("status_text", "")), "")
