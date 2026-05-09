extends GutTest

const LOCATION_PRESENCE_SERVICE := preload("res://systems/location_presence_service.gd")


func before_each() -> void:
	DataManager.clear_all()
	GameState.reset()
	DataManager.locations.clear()
	DataManager.entities.clear()


func test_static_player_template_id_is_filtered_from_present_entity_ids() -> void:
	DataManager.locations["test:room"] = {
		"location_id": "test:room",
		"entities_present": ["test:player", "test:npc"]
	}
	DataManager.entities["test:player"] = {
		"entity_id": "test:player",
		"display_name": "Player",
		"location_id": "test:room"
	}
	DataManager.entities["test:npc"] = {
		"entity_id": "test:npc",
		"display_name": "NPC",
		"location_id": "test:room"
	}
	var player := EntityInstance.from_template(DataManager.entities["test:player"])
	GameState.player = player
	GameState.entity_instances[player.entity_id] = player

	var ids: Array[String] = LOCATION_PRESENCE_SERVICE.get_present_entity_ids("test:room", DataManager.locations["test:room"])

	assert_false(ids.has("test:player"))
	assert_true(ids.has("test:npc"))


func test_runtime_player_instance_is_filtered_from_present_entity_ids() -> void:
	DataManager.locations["test:room"] = {
		"location_id": "test:room",
		"entities_present": []
	}
	DataManager.entities["test:player"] = {
		"entity_id": "test:player",
		"display_name": "Player",
		"location_id": "test:room"
	}
	DataManager.entities["test:npc"] = {
		"entity_id": "test:npc",
		"display_name": "NPC",
		"location_id": "test:room"
	}
	var player := EntityInstance.from_template(DataManager.entities["test:player"])
	var npc := EntityInstance.from_template(DataManager.entities["test:npc"])
	GameState.player = player
	GameState.entity_instances[player.entity_id] = player
	GameState.entity_instances[npc.entity_id] = npc

	var ids: Array[String] = LOCATION_PRESENCE_SERVICE.get_present_entity_ids("test:room", DataManager.locations["test:room"])

	assert_false(ids.has("test:player"))
	assert_true(ids.has("test:npc"))
