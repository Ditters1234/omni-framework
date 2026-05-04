extends GutTest

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")


func before_all() -> void:
	ModLoader.load_all_mods()


func test_base_bootstrap_content_exists() -> void:
	assert_false(DataManager.get_entity("base:player").is_empty())
	var starting_location_id := str(DataManager.get_config_value("game.starting_location", ""))
	assert_false(starting_location_id.is_empty())
	assert_false(DataManager.get_location(starting_location_id).is_empty())
	assert_eq(DataManager.get_config_value("game.starting_player_id", ""), "base:player")
	var player_template := DataManager.get_entity("base:player")
	assert_eq(str(player_template.get("location_id", "")), starting_location_id)


func test_base_kael_ai_persona_exists_and_is_bound() -> void:
	var kael_template := DataManager.get_entity("base:npc_fixer")
	assert_eq(str(kael_template.get("ai_persona_id", "")), "base:kael_persona")
	var kael_persona := DataManager.get_ai_persona("base:kael_persona")
	assert_false(kael_persona.is_empty())
	assert_eq(str(kael_persona.get("display_name", "")), "Kael")

	var theta_template := DataManager.get_entity("base:npc_theta")
	assert_eq(str(theta_template.get("ai_persona_id", "")), "base:theta_persona")
	var theta_persona := DataManager.get_ai_persona("base:theta_persona")
	assert_false(theta_persona.is_empty())
	assert_eq(str(theta_persona.get("display_name", "")), "Quartermaster Theta")


func test_base_player_head_has_custom_color_values_for_ui_testing() -> void:
	var head_template := DataManager.get_part("base:human_head_male")
	assert_false(head_template.is_empty())
	var custom_fields_value: Variant = head_template.get("custom_fields", [])
	assert_true(custom_fields_value is Array)
	if custom_fields_value is Array:
		var custom_fields: Array = custom_fields_value
		assert_gt(custom_fields.size(), 1)

	var player_template := DataManager.get_entity("base:player")
	var assembly_socket_map_value: Variant = player_template.get("assembly_socket_map", {})
	assert_true(assembly_socket_map_value is Dictionary)
	if not assembly_socket_map_value is Dictionary:
		return
	var assembly_socket_map: Dictionary = assembly_socket_map_value
	var head_instance_id := str(assembly_socket_map.get("head", ""))
	assert_false(head_instance_id.is_empty())
	if head_instance_id.is_empty():
		return

	var player := EntityInstance.from_template(player_template)
	var head := player.get_inventory_part(head_instance_id)
	assert_not_null(head)
	if head != null:
		assert_eq(str(head.get_custom_value("eye_color", "")), "green")
		assert_eq(str(head.get_custom_value("hair_color", "")), "black")
	

func test_resource_and_capacity_stats_have_valid_pair_links() -> void:
	var stat_ids: Array[String] = []
	for stat_def in DataManager.get_definitions("stats"):
		if stat_def is Dictionary:
			stat_ids.append(str(stat_def.get("id", "")))

	for stat_def in DataManager.get_definitions("stats"):
		if not stat_def is Dictionary:
			continue
		var stat_id := str(stat_def.get("id", ""))
		var kind := str(stat_def.get("kind", "flat"))
		if kind == "resource":
			assert_true(
				stat_ids.has(str(stat_def.get("paired_capacity_id", ""))),
				"Missing capacity pair for %s" % stat_id
			)
		elif kind == "capacity":
			assert_true(
				stat_ids.has(str(stat_def.get("paired_base_id", ""))),
				"Missing base pair for %s" % stat_id
			)


func test_base_content_uses_known_stats_currencies_and_location_backends() -> void:
	var stat_ids: Array[String] = []
	for stat_def in DataManager.get_definitions("stats"):
		if stat_def is Dictionary:
			stat_ids.append(str(stat_def.get("id", "")))

	var currency_ids: Array[String] = []
	for currency_id in DataManager.get_definitions("currencies"):
		currency_ids.append(str(currency_id))

	for part_data in DataManager.parts.values():
		if not part_data is Dictionary:
			continue
		var part: Dictionary = part_data
		var stats_data: Variant = part.get("stats", {})
		if stats_data is Dictionary:
			var stat_map: Dictionary = stats_data
			for stat_key_value in stat_map.keys():
				assert_true(stat_ids.has(str(stat_key_value)), "Unknown part stat '%s'" % str(stat_key_value))
		var price_data: Variant = part.get("price", {})
		if price_data is Dictionary:
			var price_map: Dictionary = price_data
			for currency_key_value in price_map.keys():
				assert_true(currency_ids.has(str(currency_key_value)), "Unknown part currency '%s'" % str(currency_key_value))

	for entity_data in DataManager.entities.values():
		if not entity_data is Dictionary:
			continue
		var entity: Dictionary = entity_data
		var entity_stats_data: Variant = entity.get("stats", {})
		if entity_stats_data is Dictionary:
			var entity_stats: Dictionary = entity_stats_data
			for stat_key_value in entity_stats.keys():
				assert_true(stat_ids.has(str(stat_key_value)), "Unknown entity stat '%s'" % str(stat_key_value))

	for location_data in DataManager.locations.values():
		if not location_data is Dictionary:
			continue
		var location: Dictionary = location_data
		var screens_data: Variant = location.get("screens", [])
		if not screens_data is Array:
			continue
		var screens: Array = screens_data
		for screen_entry_data in screens:
			if not screen_entry_data is Dictionary:
				continue
			var screen_entry: Dictionary = screen_entry_data
			var backend_class := str(screen_entry.get("backend_class", ""))
			assert_false(backend_class.is_empty(), "Location screen is missing backend_class")
			assert_true(
				UI_ROUTE_CATALOG.has_backend_class(backend_class),
				"Unmapped backend_class '%s' in location data" % backend_class
			)


func test_base_mod_ships_reference_dialogue_and_script_hook_fixtures() -> void:
	assert_true(FileAccess.file_exists("res://mods/base/dialogue/quartermaster_theta.dialogue"))
	# Remove this unless base actually promises a sample hook file:
	# assert_true(FileAccess.file_exists("res://mods/base/scripts/sample_script_hook.gd"))


func test_base_ships_the_timed_recipe_craft_task_shell() -> void:
	var craft_task := DataManager.get_task("base:recipe_craft")
	assert_false(craft_task.is_empty())
	assert_eq(str(craft_task.get("type", "")), "CRAFT")
	assert_eq(int(craft_task.get("duration", 0)), 1)
	assert_true(bool(craft_task.get("repeatable", false)))


func test_base_ships_reference_encounters_and_launch_interactions() -> void:
	var expected_encounter_ids := [
		"base:tutorial_brawl",
		"base:tutorial_negotiation",
		"base:tutorial_endurance",
	]
	for encounter_id in expected_encounter_ids:
		var encounter := DataManager.get_encounter(encounter_id)
		assert_false(encounter.is_empty(), "Missing reference encounter '%s'" % encounter_id)

	assert_true(_entity_has_encounter_interaction("base:training_drone", "base:tutorial_brawl"))
	assert_true(_entity_has_encounter_interaction("base:training_drone", "base:tutorial_endurance"))
	assert_true(_entity_has_encounter_interaction("base:npc_theta", "base:tutorial_negotiation"))


func _entity_has_encounter_interaction(entity_id: String, encounter_id: String) -> bool:
	var entity := DataManager.get_entity(entity_id)
	var interactions_value: Variant = entity.get("interactions", [])
	if not interactions_value is Array:
		return false
	var interactions: Array = interactions_value
	for interaction_value in interactions:
		if not interaction_value is Dictionary:
			continue
		var interaction: Dictionary = interaction_value
		if str(interaction.get("backend_class", "")) == "EncounterBackend" and str(interaction.get("encounter_id", "")) == encounter_id:
			return true
	return false
