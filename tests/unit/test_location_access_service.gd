extends GutTest

const LOCATION_ACCESS_SERVICE := preload("res://systems/location_access_service.gd")


func before_each() -> void:
	DataManager.clear_all()
	GameState.reset()
	DataManager.locations.clear()
	GameState.flags.clear()


func test_location_without_entry_condition_is_enterable() -> void:
	DataManager.locations["test:open"] = {
		"location_id": "test:open",
		"display_name": "Open"
	}

	var status := LOCATION_ACCESS_SERVICE.get_entry_status("test:open")

	assert_true(bool(status.get("can_enter", false)))


func test_location_entry_condition_blocks_when_flag_missing() -> void:
	DataManager.locations["test:locked"] = {
		"location_id": "test:locked",
		"display_name": "Locked",
		"locked_message": "Door locked.",
		"entry_condition": {
			"type": "has_flag",
			"flag_id": "test:door_open",
			"value": true
		}
	}

	var status := LOCATION_ACCESS_SERVICE.get_entry_status("test:locked")

	assert_false(bool(status.get("can_enter", true)))
	assert_eq(str(status.get("message", "")), "Door locked.")


func test_location_entry_condition_allows_when_flag_matches() -> void:
	DataManager.locations["test:locked"] = {
		"location_id": "test:locked",
		"display_name": "Locked",
		"entry_condition": {
			"type": "has_flag",
			"flag_id": "test:door_open",
			"value": true
		}
	}
	GameState.set_flag("test:door_open", true)

	var status := LOCATION_ACCESS_SERVICE.get_entry_status("test:locked")

	assert_true(bool(status.get("can_enter", false)))


func test_entry_conditions_array_uses_or_logic() -> void:
	DataManager.locations["test:conditional"] = {
		"location_id": "test:conditional",
		"display_name": "Conditional",
		"entry_conditions": [
			{
				"type": "has_flag",
				"flag_id": "test:first",
				"value": true
			},
			{
				"type": "has_flag",
				"flag_id": "test:second",
				"value": true
			}
		]
	}
	GameState.set_flag("test:second", true)

	var status := LOCATION_ACCESS_SERVICE.get_entry_status("test:conditional")

	assert_true(bool(status.get("can_enter", false)))
