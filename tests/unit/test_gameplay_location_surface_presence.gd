extends GutTest


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

	var surface := GameplayLocationSurface.new()
	surface.set("_location_id", "test:room")
	surface.set("_location_template", DataManager.locations["test:room"])

	var ids: Array[String] = surface.call("_get_present_entity_ids")

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

	var surface := GameplayLocationSurface.new()
	surface.set("_location_id", "test:room")
	surface.set("_location_template", DataManager.locations["test:room"])

	var ids: Array[String] = surface.call("_get_present_entity_ids")

	assert_false(ids.has("test:player"))
	assert_true(ids.has("test:npc"))
