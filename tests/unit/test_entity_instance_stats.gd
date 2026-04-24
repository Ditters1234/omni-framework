extends GutTest


func before_each() -> void:
	DataManager.clear_all()
	GameState.reset()
	DefinitionLoader.load_additions({
		"stats": [
			{
				"id": "strength",
				"kind": "flat",
				"default_value": 1
			},
			{
				"id": "health",
				"kind": "resource",
				"paired_capacity_id": "health_max",
				"default_value": 8,
				"default_capacity_value": 10
			},
			{
				"id": "health_max",
				"kind": "capacity",
				"paired_base_id": "health",
				"default_value": 10
			}
		]
	})


func test_from_template_applies_defaults_location_and_currencies() -> void:
	var entity := EntityInstance.from_template({
		"entity_id": "base:test_entity",
		"location_id": "base:start",
		"currencies": {
			"credits": 25
		},
		"stats": {
			"strength": 4
		}
	})

	assert_eq(entity.template_id, "base:test_entity")
	assert_eq(entity.location_id, "base:start")
	assert_eq(entity.get_currency("credits"), 25.0)
	assert_eq(entity.get_stat("strength"), 4.0)
	assert_eq(entity.get_stat("health"), 8.0)
	assert_eq(entity.get_stat("health_max"), 10.0)


func test_set_stat_clamps_resource_to_capacity_and_capacity_back_to_resource() -> void:
	var entity := EntityInstance.from_template({
		"entity_id": "base:test_entity"
	})

	entity.set_stat("health", 99)
	assert_eq(entity.get_stat("health"), 10.0)

	entity.set_stat("health_max", 6)
	assert_eq(entity.get_stat("health_max"), 6.0)
	assert_eq(entity.get_stat("health"), 6.0)


func test_owned_entity_ids_round_trip_through_runtime_serialization() -> void:
	var entity := EntityInstance.from_template({
		"entity_id": "base:test_owner",
		"owned_entity_ids": ["base:child_a", "base:child_b"],
	})
	var clone := EntityInstance.new()
	clone.from_dict(entity.to_dict())

	assert_eq(entity.owned_entity_ids, ["base:child_a", "base:child_b"])
	assert_eq(clone.owned_entity_ids, ["base:child_a", "base:child_b"])
