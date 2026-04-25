
extends GutTest

func before_each():
	GameState.reset()

func test_runtime_entity_presence():
	var e := EntityInstance.from_template({
		"entity_id": "test:npc",
		"location_id": "loc:a"
	})
	GameState.entity_instances[e.entity_id] = e

	var results = GameState.get_entity_instances_at_location("loc:a")
	assert_eq(results.size(), 1)

func test_entity_moves_between_locations():
	var e := EntityInstance.from_template({
		"entity_id": "test:npc",
		"location_id": "loc:a"
	})
	GameState.entity_instances[e.entity_id] = e

	e.location_id = "loc:b"

	var a = GameState.get_entity_instances_at_location("loc:a")
	var b = GameState.get_entity_instances_at_location("loc:b")

	assert_eq(a.size(), 0)
	assert_eq(b.size(), 1)
