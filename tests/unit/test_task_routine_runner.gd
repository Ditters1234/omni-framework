extends GutTest

var _runner: OmniTaskRoutineRunner = null


func before_each() -> void:
	DataManager.clear_all()
	GameState.reset()
	GameState.current_day = 1
	GameState.current_tick = 0
	DataManager.config = {
		"game": {
			"ticks_per_day": 24
		},
		"task_routines": []
	}
	DataManager.tasks.clear()
	DataManager.locations.clear()
	_runner = OmniTaskRoutineRunner.new()
	add_child_autofree(_runner)
	_runner.reset_runtime_cache()


func test_routine_starts_travel_task_for_entity_at_configured_tick() -> void:
	_register_location("test:home", {"test:market": 2})
	_register_location("test:market", {"test:home": 2})
	_register_entity("test:merchant", "test:home")
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market"
				}
			]
		}
	]

	var started := _runner.evaluate_current_tick()

	assert_eq(started.size(), 1)
	assert_eq(GameState.active_tasks.size(), 1)
	var task_instance: Dictionary = GameState.active_tasks.values()[0]
	assert_eq(str(task_instance.get("entity_id", "")), "test:merchant")
	assert_eq(str(task_instance.get("target", "")), "test:market")


func test_routine_uses_location_graph_route_cost_when_duration_is_omitted() -> void:
	_register_location("test:home", {"test:mid": 2})
	_register_location("test:mid", {"test:market": 3})
	_register_location("test:market", {})
	_register_entity("test:merchant", "test:home")
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market"
				}
			]
		}
	]

	_runner.evaluate_current_tick()

	var task_instance: Dictionary = GameState.active_tasks.values()[0]
	assert_eq(int(task_instance.get("remaining_ticks", 0)), 5)


func test_duration_override_wins_over_location_graph_route_cost() -> void:
	_register_location("test:home", {"test:market": 9})
	_register_location("test:market", {"test:home": 9})
	_register_entity("test:merchant", "test:home")
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market",
					"duration": 1
				}
			]
		}
	]

	_runner.evaluate_current_tick()

	var task_instance: Dictionary = GameState.active_tasks.values()[0]
	assert_eq(int(task_instance.get("remaining_ticks", 0)), 1)


func test_routine_does_not_start_same_entry_twice_on_same_day() -> void:
	_register_location("test:home", {"test:market": 2})
	_register_location("test:market", {"test:home": 2})
	_register_entity("test:merchant", "test:home")
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market"
				}
			]
		}
	]

	_runner.evaluate_current_tick()
	_runner.evaluate_current_tick()

	assert_eq(GameState.active_tasks.size(), 1)


func test_routine_can_start_same_entry_again_next_day() -> void:
	_register_location("test:home", {"test:market": 2})
	_register_location("test:market", {"test:home": 2})
	_register_entity("test:merchant", "test:home")
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market"
				}
			]
		}
	]

	_runner.evaluate_current_tick()
	GameState.current_day = 2
	GameState.current_tick = 24
	TimeKeeper.sync_from_game_state()
	_runner.evaluate_current_tick()

	assert_eq(GameState.active_tasks.size(), 2)


func test_travel_task_completion_moves_non_player_entity() -> void:
	var merchant := _register_entity("test:merchant", "test:home")
	_register_location("test:home", {"test:market": 1})
	_register_location("test:market", {"test:home": 1})
	_register_travel_task("test:merchant_to_market", "test:market")
	DataManager.config["task_routines"] = [
		{
			"routine_id": "test:merchant_daily",
			"entity_id": "test:merchant",
			"entries": [
				{
					"tick": 0,
					"task_template_id": "test:merchant_to_market"
				}
			]
		}
	]

	_runner.evaluate_current_tick()
	TimeKeeper.advance_tick()

	assert_eq(merchant.location_id, "test:market")


func _register_entity(entity_id: String, location_id: String) -> EntityInstance:
	DataManager.entities[entity_id] = {
		"entity_id": entity_id,
		"display_name": entity_id,
		"location_id": location_id
	}
	var entity := EntityInstance.from_template(DataManager.entities[entity_id])
	GameState.commit_entity_instance(entity)
	return entity


func _register_location(location_id: String, connections: Dictionary) -> void:
	DataManager.locations[location_id] = {
		"location_id": location_id,
		"display_name": location_id,
		"connections": connections.duplicate(true)
	}


func _register_travel_task(template_id: String, target: String) -> void:
	DataManager.tasks[template_id] = {
		"template_id": template_id,
		"type": "TRAVEL",
		"target": target,
		"repeatable": true,
		"reward": {}
	}
