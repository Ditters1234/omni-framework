extends RefCounted

class_name TestFixtureWorld

static func bootstrap_runtime_fixture(load_engine_bootstrap: bool = true) -> void:
	_prepare_fixture(load_engine_bootstrap, true)


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
			"starting_player_id": "base:player",
			"starting_location": "base:start",
			"starting_money": {"credits": 100}
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
		"base:start": {
			"location_id": "base:start",
			"display_name": "Start",
			"description": "Fixture starting location.",
			"connections": {
				"base:field": 1
			},
			"screens": []
		},
		"base:field": {
			"location_id": "base:field",
			"display_name": "Field",
			"description": "Fixture field location.",
			"connections": {
				"base:start": 1
			},
			"screens": []
		}
	}


static func _seed_parts() -> void:
	DataManager.parts = {
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
		}
	}


static func _seed_entities() -> void:
	DataManager.entities = {
		"base:player": {
			"entity_id": "base:player",
			"display_name": "Player",
			"description": "Fixture player entity.",
			"location_id": "base:start",
			"currencies": {"credits": 100},
			"stats": {"strength": 2, "health": 50, "health_max": 50},
			"provides_sockets": [
				{"id": "hair", "accepted_tags": ["hair"], "label": "Hair"},
				{"id": "left_arm", "accepted_tags": ["arm"], "label": "Left Arm"}
			],
			"inventory": [],
			"assembly_socket_map": {}
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
