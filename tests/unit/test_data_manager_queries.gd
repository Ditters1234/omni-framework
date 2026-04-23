extends GutTest


func before_each() -> void:
	DataManager.clear_all()
	DataManager.parts["base:starter_sword"] = {
		"id": "base:starter_sword",
		"display_name": "Starter Sword",
		"tags": ["weapon", "melee"]
	}
	DataManager.parts["base:starter_hat"] = {
		"id": "base:starter_hat",
		"display_name": "Starter Hat",
		"tags": ["cosmetic"]
	}
	DataManager.entities["base:vendor"] = {
		"entity_id": "base:vendor",
		"display_name": "Vendor",
		"location_id": "base:town"
	}
	DataManager.entities["base:guard"] = {
		"entity_id": "base:guard",
		"display_name": "Guard",
		"location_id": "base:gate"
	}
	DataManager.recipes["base:starter_blade"] = {
		"recipe_id": "base:starter_blade",
		"display_name": "Starter Blade",
		"output_template_id": "base:starter_sword",
		"inputs": [
			{"template_id": "base:starter_hat", "count": 1}
		],
		"required_stations": ["base:forge"],
		"tags": ["weapon", "starter"]
	}


func test_query_parts_filters_by_tags_and_returns_copies() -> void:
	var results := DataManager.query_parts({
		"tags": ["weapon", "melee"]
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("id", "")), "base:starter_sword")

	results[0]["display_name"] = "Mutated"
	assert_eq(str(DataManager.parts["base:starter_sword"].get("display_name", "")), "Starter Sword")


func test_query_entities_filters_by_location() -> void:
	var results := DataManager.query_entities({
		"location_id": "base:town"
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("entity_id", "")), "base:vendor")


func test_query_recipes_filters_by_station_tags_and_returns_copies() -> void:
	var results := DataManager.query_recipes({
		"station_id": "base:forge",
		"tags": ["weapon"]
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("recipe_id", "")), "base:starter_blade")

	results[0]["display_name"] = "Mutated"
	assert_eq(str(DataManager.recipes["base:starter_blade"].get("display_name", "")), "Starter Blade")
