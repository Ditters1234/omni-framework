extends RefCounted

class_name TestFixtureWorld

const SAMPLE_DIALOGUE_RESOURCE := "res://tests/fixtures/dialogue/sample_greeting.dialogue"
const START_LOCATION_ID := "base:start"
const CONNECTED_LOCATION_ID := "base:field"
const PLAYER_TEMPLATE_ID := "base:player"
const FIXTURE_VENDOR_ID := "base:fixture_vendor"

static func bootstrap_runtime_fixture(load_engine_bootstrap: bool = true) -> void:
	_prepare_fixture(load_engine_bootstrap, true)


static func bootstrap_data_fixture(load_engine_bootstrap: bool = true) -> void:
	_prepare_fixture(load_engine_bootstrap, false)


static func seed() -> void:
	_prepare_fixture(false, false)


static func _prepare_fixture(load_engine_bootstrap: bool, start_game: bool) -> void:
	if load_engine_bootstrap:
		ModLoader.load_all_mods()
	GameEvents.clear_event_history()
	GameState.reset()
	DataManager.clear_all()
	_seed_definitions()
	_seed_config()
	_seed_locations()
	_seed_parts()
	_seed_entities()
	_seed_factions()
	_seed_quests()
	_seed_tasks()
	_seed_achievements()
	DataManager.is_loaded = true
	if start_game:
		GameState.new_game()
	TimeKeeper.stop()


static func starting_player_template_id() -> String:
	return str(DataManager.get_config_value("game.starting_player_id", ""))


static func starting_location_id() -> String:
	return str(DataManager.get_config_value("game.starting_location", ""))


static func connected_location_id() -> String:
	return CONNECTED_LOCATION_ID


static func fixture_vendor_id() -> String:
	return FIXTURE_VENDOR_ID


static func sample_dialogue_resource_path() -> String:
	return SAMPLE_DIALOGUE_RESOURCE


static func starting_currency(currency_id: String) -> float:
	var player_template := DataManager.get_entity(starting_player_template_id())
	if player_template.is_empty():
		return 0.0
	var currencies_value: Variant = player_template.get("currencies", {})
	if not currencies_value is Dictionary:
		return 0.0
	return float(currencies_value.get(currency_id, 0.0))


static func add_runtime_vendor() -> EntityInstance:
	var vendor_template := {
		"entity_id": "base:test_vendor",
		"display_name": "Test Vendor",
		"description": "Stocks a single test item.",
		"location_id": starting_location_id(),
		"currencies": {"credits": 0},
		"inventory": [
			{"instance_id": "base:test_vendor:arm", "template_id": "base:body_arm_standard"},
		],
		"interactions": [],
	}
	DataManager.entities["base:test_vendor"] = vendor_template.duplicate(true)
	var vendor := EntityInstance.from_template(vendor_template)
	GameState.commit_entity_instance(vendor, vendor.entity_id)
	return vendor


static func add_runtime_implant_vendor() -> EntityInstance:
	var vendor_template := {
		"entity_id": "base:test_vendor",
		"display_name": "Implant Vendor",
		"description": "Stocks a fixture implant for assembly tests.",
		"location_id": connected_location_id(),
		"currencies": {"credits": 0},
		"inventory": [
			{"instance_id": "theta_implant_001", "template_id": "base:optic_implant"},
		],
		"interactions": [],
	}
	DataManager.entities["base:test_vendor"] = vendor_template.duplicate(true)
	var vendor := EntityInstance.from_template(vendor_template)
	GameState.commit_entity_instance(vendor, vendor.entity_id)
	return vendor


static func seed_phase5_runtime() -> void:
	DataManager.quests["base:phase5_quest"] = {
		"quest_id": "base:phase5_quest",
		"display_name": "Phase 5 Quest",
		"stages": [
			{
				"title": "First Stage",
				"description": "Review the first Phase 5 stage.",
				"objectives": [
					{
						"type": "has_flag",
						"flag_id": "phase5_ready",
						"value": true,
						"description": "Set the Phase 5 flag."
					}
				]
			}
		],
		"reward": {"credits": 3}
	}
	GameState.active_quests["base:phase5_quest"] = {
		"quest_id": "base:phase5_quest",
		"stage_index": 0
	}
	DataManager.factions["base:phase5_faction"] = {
		"faction_id": "base:phase5_faction",
		"display_name": "Phase 5 Faction",
		"description": "A faction used by Phase 5 backend tests.",
		"faction_color": "primary",
		"territory": [starting_location_id()]
	}
	var player := GameState.player as EntityInstance
	if player != null:
		player.reputation["base:phase5_faction"] = 25.0
	DataManager.achievements["base:phase5_achievement"] = {
		"achievement_id": "base:phase5_achievement",
		"display_name": "Phase 5 Achievement",
		"description": "A seeded achievement.",
		"stat_name": "phase5_steps",
		"requirement": 3
	}
	GameState.achievement_stats["phase5_steps"] = 1.0


static func _seed_definitions() -> void:
	DataManager.definitions = {
		"currencies": ["credits", "gold"],
		"stats": [
			{
				"id": "strength",
				"kind": "flat",
				"default_value": 0,
				"ui_group": "combat"
			},
			{
				"id": "power",
				"kind": "flat",
				"default_value": 0,
				"ui_group": "combat"
			},
			{
				"id": "health",
				"kind": "resource",
				"paired_capacity_id": "health_max",
				"default_value": 50,
				"default_capacity_value": 50,
				"ui_group": "survival"
			},
			{
				"id": "health_max",
				"kind": "capacity",
				"paired_base_id": "health",
				"default_value": 50,
				"ui_group": "survival"
			}
		]
	}


static func _seed_config() -> void:
	DataManager.config = {
		"game": {
			"title": "Fixture World",
			"starting_player_id": PLAYER_TEMPLATE_ID,
			"starting_location": START_LOCATION_ID,
			"starting_discovered_locations": [
				START_LOCATION_ID,
				CONNECTED_LOCATION_ID,
			],
			"ticks_per_day": 24,
			"ticks_per_hour": 1,
			"starting_money": {"credits": 100},
			"new_game_flow": {
				"screen_id": "gameplay_shell",
				"params": {
					"initial_surface_id": "assembly_editor",
					"disable_shell_chrome": true,
					"initial_surface_params": {
						"target_entity_id": "player",
						"pop_on_confirm": true,
						"allow_confirm_without_changes": true,
						"cancel_screen_id": "main_menu",
					},
				},
			},
		},
		"ui": {
			"main_menu": {
				"title": "Fixture World",
				"subtitle": "Stable engine-owned test data.",
				"new_game_label": "New Fixture Run",
				"continue_label": "Continue Fixture Run",
				"load_label": "Load Fixture Save",
				"settings_label": "Settings",
				"credits_label": "Credits",
				"quit_label": "Quit",
			},
			"time_advance_buttons": ["1 tick", "1 hour", "1 day"],
		},
		"stats": {
			"groups": {
				"combat": ["strength", "power"],
				"survival": ["health", "health_max"]
			}
		}
	}


static func _seed_locations() -> void:
	DataManager.locations = {
		START_LOCATION_ID: {
			"location_id": START_LOCATION_ID,
			"display_name": "Fixture Start",
			"description": "A stable starting location for engine-owned tests.",
			"connections": {
				CONNECTED_LOCATION_ID: 1
			},
			"screens": []
		},
		CONNECTED_LOCATION_ID: {
			"location_id": CONNECTED_LOCATION_ID,
			"display_name": "Fixture Field",
			"description": "A stable connected location with a fixture vendor.",
			"connections": {
				START_LOCATION_ID: 1
			},
			"screens": []
		}
	}


static func _seed_parts() -> void:
	DataManager.parts = {
		"base:human_head": {
			"id": "base:human_head",
			"display_name": "Fixture Head",
			"tags": ["head"],
			"price": {"credits": 12},
			"stats": {},
			"custom_fields": [
				{"id": "eye_color", "label": "Eye Color"},
				{"id": "hair_color", "label": "Hair Color"}
			]
		},
		"base:body_hair_short": {
			"id": "base:body_hair_short",
			"display_name": "Short Hair",
			"tags": ["hair"],
			"price": {"credits": 3},
			"stats": {}
		},
		"base:body_hair_long": {
			"id": "base:body_hair_long",
			"display_name": "Long Hair",
			"tags": ["hair"],
			"price": {"credits": 4},
			"stats": {}
		},
		"base:body_arm_standard": {
			"id": "base:body_arm_standard",
			"display_name": "Standard Arm",
			"tags": ["arm"],
			"price": {"credits": 8},
			"stats": {"power": 2}
		},
		"base:optic_implant": {
			"id": "base:optic_implant",
			"display_name": "Fixture Optic Implant",
			"tags": ["neural_implant"],
			"price": {"credits": 150},
			"stats": {"power": 1}
		}
	}


static func _seed_entities() -> void:
	DataManager.entities = {
		PLAYER_TEMPLATE_ID: {
			"entity_id": PLAYER_TEMPLATE_ID,
			"display_name": "Player",
			"description": "Fixture player entity.",
			"location_id": START_LOCATION_ID,
			"currencies": {"credits": 100},
			"stats": {"strength": 2, "power": 1, "health": 50, "health_max": 50},
			"provides_sockets": [
				{"id": "head", "accepted_tags": ["head"], "label": "Head"},
				{"id": "hair", "accepted_tags": ["hair"], "label": "Hair"},
				{"id": "left_arm", "accepted_tags": ["arm"], "label": "Left Arm"},
				{"id": "neural_slot", "accepted_tags": ["neural_implant"], "label": "Neural Slot"}
			],
			"inventory": [
				{
					"instance_id": "player_head_001",
					"template_id": "base:human_head",
					"custom_values": {
						"eye_color": "green",
						"hair_color": "black"
					}
				}
			],
			"assembly_socket_map": {
				"head": "player_head_001"
			}
		},
		FIXTURE_VENDOR_ID: {
			"entity_id": FIXTURE_VENDOR_ID,
			"display_name": "Fixture Vendor",
			"description": "Provides stable interaction buttons for gameplay shell tests.",
			"location_id": CONNECTED_LOCATION_ID,
			"currencies": {"credits": 500},
			"inventory": [
				{"instance_id": "fixture_vendor_implant_001", "template_id": "base:optic_implant"}
			],
			"interactions": [
				{
					"tab_id": "fixture_trade",
					"label": "Browse Stock",
					"description": "Browse the fixture vendor inventory.",
					"backend_class": "ExchangeBackend",
					"source_inventory": "entity:%s" % FIXTURE_VENDOR_ID,
					"destination_inventory": "player",
					"currency_id": "credits"
				},
				{
					"tab_id": "fixture_talk",
					"label": "Talk",
					"description": "Open the sample test dialogue.",
					"backend_class": "DialogueBackend",
					"dialogue_resource": SAMPLE_DIALOGUE_RESOURCE
				}
			]
		}
	}


static func _seed_factions() -> void:
	DataManager.factions = {}


static func _seed_quests() -> void:
	DataManager.quests = {}


static func _seed_tasks() -> void:
	DataManager.tasks = {}


static func _seed_achievements() -> void:
	DataManager.achievements = {}
