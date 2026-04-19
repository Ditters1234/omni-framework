extends GutTest

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")

const SCREEN_CASES := [
	{
		"scene_path": UI_ROUTE_CATALOG.ASSEMBLY_EDITOR_SCENE,
		"params": {
			"target_entity_id": "player",
			"screen_title": "Character Loadout",
			"confirm_label": "Done",
			"cancel_label": "Back",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.EXCHANGE_SCENE,
		"params": {
			"source_inventory": "entity:base:screen_smoke_vendor:inventory",
			"destination_inventory": "player:inventory",
			"currency_id": "credits",
			"screen_title": "Smoke Exchange",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.CATALOG_LIST_SCENE,
		"params": {
			"data_source": "catalog",
			"action_payload": {"type": "buy_item"},
			"buyer_entity_id": "player",
			"currency_id": "credits",
			"template_ids": ["base:body_arm_standard"],
			"screen_title": "Smoke Catalog",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.LIST_VIEW_SCENE,
		"params": {
			"data_source": "player:inventory",
			"screen_title": "Smoke Inventory",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.CHALLENGE_SCENE,
		"params": {
			"target_entity_id": "player",
			"required_stat": "strength",
			"required_value": 1,
			"screen_title": "Smoke Challenge",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.TASK_PROVIDER_SCENE,
		"params": {
			"faction_id": "base:screen_smoke_faction",
			"screen_title": "Smoke Jobs",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.DIALOGUE_SCENE,
		"params": {
			"dialogue_resource": "res://mods/base/dialogue/sample_greeting.dialogue",
			"speaker_entity_id": "player",
			"screen_title": "Smoke Dialogue",
		},
	},
	{
		"scene_path": UI_ROUTE_CATALOG.ENTITY_SHEET_SCENE,
		"params": {
			"target_entity_id": "player",
			"screen_title": "Smoke Entity Sheet",
		},
	},
]

var _spawned_screens: Array[Control] = []
var _test_viewport: SubViewport = null


func before_each() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	_seed_backend_screen_runtime()
	_test_viewport = _create_test_viewport()


func after_each() -> void:
	for screen in _spawned_screens:
		if screen == null or not is_instance_valid(screen):
			continue
		screen.queue_free()
	_spawned_screens.clear()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null
	await get_tree().process_frame


func test_phase4_backend_screens_instantiate_and_initialize_without_runtime_errors() -> void:
	for screen_case_value in SCREEN_CASES:
		assert_true(screen_case_value is Dictionary)
		var screen_case: Dictionary = screen_case_value
		var scene_path := str(screen_case.get("scene_path", ""))
		var packed_value: Variant = load(scene_path)
		assert_true(packed_value is PackedScene)
		var packed_scene: PackedScene = packed_value
		var instance_value: Variant = packed_scene.instantiate()
		assert_true(instance_value is Control)
		var screen: Control = instance_value
		_spawned_screens.append(screen)
		assert_not_null(_test_viewport)
		_test_viewport.add_child(screen)
		var params := _read_dictionary(screen_case.get("params", {}))
		if screen.has_method("initialize"):
			screen.call("initialize", params)
		await get_tree().process_frame
		assert_true(screen.is_inside_tree())
		if screen.has_method("get_debug_snapshot"):
			var snapshot_value: Variant = screen.call("get_debug_snapshot")
			assert_true(snapshot_value is Dictionary)


func _seed_backend_screen_runtime() -> void:
	var player := GameState.player as EntityInstance
	if player == null:
		return
	var part_template := DataManager.get_part("base:body_arm_standard")
	if not part_template.is_empty():
		player.add_part(PartInstance.from_template(part_template))
	var vendor_template := {
		"entity_id": "base:screen_smoke_vendor",
		"display_name": "Smoke Vendor",
		"description": "Stocks one smoke-test item.",
		"location_id": GameState.current_location_id,
		"currencies": {"credits": 0},
		"inventory": [
			{"instance_id": "base:screen_smoke_vendor:arm", "template_id": "base:body_arm_standard"},
		],
		"interactions": [],
	}
	DataManager.entities["base:screen_smoke_vendor"] = vendor_template.duplicate(true)
	GameState.commit_entity_instance(EntityInstance.from_template(vendor_template), "base:screen_smoke_vendor")
	DataManager.factions["base:screen_smoke_faction"] = {
		"faction_id": "base:screen_smoke_faction",
		"display_name": "Smoke Faction",
		"quest_pool": ["base:screen_smoke_task"],
	}
	DataManager.tasks["base:screen_smoke_task"] = {
		"template_id": "base:screen_smoke_task",
		"display_name": "Smoke Courier",
		"description": "Carry a test parcel.",
		"type": "DELIVER",
		"target": "base:start",
		"travel_cost": 1,
		"reward": {"credits": 1},
		"repeatable": true,
	}


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestBackendScreenViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
