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
	DataManager.ai_personas["base:vendor_persona"] = {
		"persona_id": "base:vendor_persona",
		"display_name": "Vendor",
		"system_prompt_template": "You are a vendor.",
		"tags": ["merchant", "helpful"]
	}
	DataManager.ai_personas["base:guard_persona"] = {
		"persona_id": "base:guard_persona",
		"display_name": "Guard",
		"system_prompt_template": "You are a guard.",
		"tags": ["security"]
	}
	DataManager.ai_templates["base:task_flavor"] = {
		"template_id": "base:task_flavor",
		"purpose": "task_description",
		"prompt_template": "Describe {display_name}.",
		"tags": ["task_board", "briefing"]
	}
	DataManager.ai_templates["base:event_narration"] = {
		"template_id": "base:event_narration",
		"purpose": "event_narration",
		"prompt_template": "Narrate {event_name}.",
		"tags": ["event_log"]
	}
	DataManager.encounters["base:training_brawl"] = {
		"encounter_id": "base:training_brawl",
		"display_name": "Training Brawl",
		"tags": ["tutorial", "combat"],
		"participants": {},
		"actions": {},
		"resolution": {},
	}
	DataManager.encounters["base:market_negotiation"] = {
		"encounter_id": "base:market_negotiation",
		"display_name": "Market Negotiation",
		"tags": ["tutorial", "negotiation"],
		"participants": {},
		"actions": {},
		"resolution": {},
	}
	DataManager.status_effects["base:test_status"] = {
		"status_effect_id": "base:test_status",
		"display_name": "Test Status",
		"tags": ["buff", "mental"],
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


func test_query_ai_personas_filters_by_tags_and_returns_copies() -> void:
	var results := DataManager.query_ai_personas({
		"tags": ["merchant"]
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("persona_id", "")), "base:vendor_persona")

	results[0]["display_name"] = "Mutated"
	assert_eq(str(DataManager.ai_personas["base:vendor_persona"].get("display_name", "")), "Vendor")


func test_query_ai_templates_filters_by_purpose_and_returns_copies() -> void:
	var results := DataManager.query_ai_templates({
		"purpose": "task_description",
		"tags": ["task_board"]
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("template_id", "")), "base:task_flavor")

	results[0]["prompt_template"] = "Mutated"
	assert_eq(str(DataManager.ai_templates["base:task_flavor"].get("prompt_template", "")), "Describe {display_name}.")


func test_query_encounters_filters_by_tags_and_returns_copies() -> void:
	var results := DataManager.query_encounters({
		"tags": ["tutorial", "combat"]
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("encounter_id", "")), "base:training_brawl")

	results[0]["display_name"] = "Mutated"
	assert_eq(str(DataManager.encounters["base:training_brawl"].get("display_name", "")), "Training Brawl")


func test_query_status_effects_filters_by_tags_and_returns_copies() -> void:
	var results := DataManager.query_status_effects({"tags": ["buff"]})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("status_effect_id", "")), "base:test_status")

	results[0]["display_name"] = "Mutated"
	assert_eq(str(DataManager.status_effects["base:test_status"].get("display_name", "")), "Test Status")
