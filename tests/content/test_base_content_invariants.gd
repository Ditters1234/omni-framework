extends GutTest

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")


func before_all() -> void:
	ModLoader.load_all_mods()


func test_base_bootstrap_content_exists() -> void:
	assert_false(DataManager.get_entity("base:player").is_empty())
	var starting_location_id := str(DataManager.get_config_value("game.starting_location", ""))
	assert_false(starting_location_id.is_empty())
	assert_eq(starting_location_id, "base:dorm_room")
	assert_false(DataManager.get_location(starting_location_id).is_empty())
	assert_eq(DataManager.get_config_value("game.starting_player_id", ""), "base:player")
	var player_template := DataManager.get_entity("base:player")
	assert_eq(str(player_template.get("location_id", "")), starting_location_id)


func test_base_player_starts_with_required_vanguard_body_sockets_equipped() -> void:
	var player_template := DataManager.get_entity("base:player")
	var expected_socket_ids: Array[String] = ["cognitive", "sensory", "manipulator", "locomotion", "framework"]
	var provides_sockets_value: Variant = player_template.get("provides_sockets", [])
	assert_true(provides_sockets_value is Array)
	if not provides_sockets_value is Array:
		return
	var provides_sockets: Array = provides_sockets_value
	var provided_socket_ids: Array[String] = []
	for socket_data in provides_sockets:
		if socket_data is Dictionary:
			var socket: Dictionary = socket_data
			provided_socket_ids.append(str(socket.get("id", "")))

	for socket_id in expected_socket_ids:
		assert_true(provided_socket_ids.has(socket_id), "Player is missing Vanguard socket '%s'" % socket_id)

	var assembly_socket_map_value: Variant = player_template.get("assembly_socket_map", {})
	assert_true(assembly_socket_map_value is Dictionary)
	if not assembly_socket_map_value is Dictionary:
		return
	var assembly_socket_map: Dictionary = assembly_socket_map_value
	var inventory_value: Variant = player_template.get("inventory", [])
	assert_true(inventory_value is Array)
	if not inventory_value is Array:
		return
	var inventory: Array = inventory_value

	for socket_id in expected_socket_ids:
		var instance_id := str(assembly_socket_map.get(socket_id, ""))
		assert_false(instance_id.is_empty(), "Player starts without an equipped part for '%s'" % socket_id)
		var inventory_entry := _inventory_entry_for_instance(inventory, instance_id)
		assert_false(inventory_entry.is_empty(), "Equipped instance '%s' is missing from player inventory" % instance_id)
		var part_id := str(inventory_entry.get("template_id", ""))
		var part_template := DataManager.get_part(part_id)
		assert_false(part_template.is_empty(), "Equipped part '%s' is missing from parts registry" % part_id)
		var required_tags_value: Variant = part_template.get("required_tags", [])
		assert_true(required_tags_value is Array)
		if required_tags_value is Array:
			var required_tags: Array = required_tags_value
			assert_true(required_tags.has(socket_id), "Equipped part '%s' does not match socket '%s'" % [part_id, socket_id])


func test_base_vanguard_ai_personas_exist_and_are_bound() -> void:
	var mara_template := DataManager.get_entity("base:roommate_mara")
	assert_eq(str(mara_template.get("ai_persona_id", "")), "base:mara_persona")
	var mara_persona := DataManager.get_ai_persona("base:mara_persona")
	assert_false(mara_persona.is_empty())
	assert_eq(str(mara_persona.get("display_name", "")), "Mara Vale")

	var ilex_template := DataManager.get_entity("base:professor_ilex")
	assert_eq(str(ilex_template.get("ai_persona_id", "")), "base:ilex_persona")
	var ilex_persona := DataManager.get_ai_persona("base:ilex_persona")
	assert_false(ilex_persona.is_empty())
	assert_eq(str(ilex_persona.get("display_name", "")), "Professor Ilex")


func test_base_player_senses_have_custom_color_values_for_ui_testing() -> void:
	var senses_template := DataManager.get_part("base:human_senses")
	assert_false(senses_template.is_empty())
	var custom_fields_value: Variant = senses_template.get("custom_fields", [])
	assert_true(custom_fields_value is Array)
	if custom_fields_value is Array:
		var custom_fields: Array = custom_fields_value
		assert_gt(custom_fields.size(), 0)

	var player_template := DataManager.get_entity("base:player")
	var assembly_socket_map_value: Variant = player_template.get("assembly_socket_map", {})
	assert_true(assembly_socket_map_value is Dictionary)
	if not assembly_socket_map_value is Dictionary:
		return
	var assembly_socket_map: Dictionary = assembly_socket_map_value
	var senses_instance_id := str(assembly_socket_map.get("sensory", ""))
	assert_false(senses_instance_id.is_empty())
	if senses_instance_id.is_empty():
		return

	var player := EntityInstance.from_template(player_template)
	var senses := player.get_inventory_part(senses_instance_id)
	assert_not_null(senses)
	if senses != null:
		assert_eq(str(senses.get_custom_value("eye_color", "")), "brown")
	

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
	var stat_ids: Array[String] = _known_stat_ids()
	var currency_ids: Array[String] = _known_currency_ids()

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


func test_base_activity_references_are_valid() -> void:
	var stat_ids: Array[String] = _known_stat_ids()
	var currency_ids: Array[String] = _known_currency_ids()
	var faction_ids: Array[String] = _known_faction_ids()
	var part_ids: Array[String] = _known_part_ids()
	var status_effect_ids: Array[String] = _known_status_effect_ids()
	var location_ids: Array[String] = _known_location_ids()
	var entity_ids: Array[String] = _known_entity_ids()

	for activity_data in DataManager.activities.values():
		if not activity_data is Dictionary:
			continue
		var activity: Dictionary = activity_data
		var activity_id := str(activity.get("activity_id", ""))
		var location_id := str(activity.get("location_id", ""))
		assert_true(location_ids.has(location_id), "Activity '%s' references missing location '%s'" % [activity_id, location_id])

		var provider_entity_id := str(activity.get("provider_entity_id", ""))
		if not provider_entity_id.is_empty():
			assert_true(entity_ids.has(provider_entity_id), "Activity '%s' references missing provider '%s'" % [activity_id, provider_entity_id])

		_assert_conditions_reference_known_content(activity_id, activity.get("visible_if", []), stat_ids)
		_assert_conditions_reference_known_content(activity_id, activity.get("requirements", []), stat_ids)
		_assert_actions_reference_known_content(activity_id, activity.get("start_actions", []), stat_ids, currency_ids, faction_ids, part_ids, status_effect_ids)
		_assert_actions_reference_known_content(activity_id, activity.get("completion_actions", []), stat_ids, currency_ids, faction_ids, part_ids, status_effect_ids)
		_assert_actions_reference_known_content(activity_id, activity.get("failure_actions", []), stat_ids, currency_ids, faction_ids, part_ids, status_effect_ids)

		var outcomes_value: Variant = activity.get("outcomes", [])
		if not outcomes_value is Array:
			continue
		var outcomes: Array = outcomes_value
		for outcome_data in outcomes:
			if not outcome_data is Dictionary:
				continue
			var outcome: Dictionary = outcome_data
			_assert_conditions_reference_known_content(activity_id, outcome.get("conditions", []), stat_ids)
			_assert_actions_reference_known_content(activity_id, outcome.get("actions", []), stat_ids, currency_ids, faction_ids, part_ids, status_effect_ids)


func test_base_quest_activity_objectives_reference_existing_activities() -> void:
	var activity_ids: Array[String] = _known_activity_ids()
	for quest_data in DataManager.quests.values():
		if not quest_data is Dictionary:
			continue
		var quest: Dictionary = quest_data
		var quest_id := str(quest.get("quest_id", ""))
		var stages_value: Variant = quest.get("stages", [])
		if not stages_value is Array:
			continue
		var stages: Array = stages_value
		for stage_data in stages:
			if not stage_data is Dictionary:
				continue
			var stage: Dictionary = stage_data
			var objectives_value: Variant = stage.get("objectives", [])
			if not objectives_value is Array:
				continue
			var objectives: Array = objectives_value
			for objective_data in objectives:
				if not objective_data is Dictionary:
					continue
				var objective: Dictionary = objective_data
				if str(objective.get("type", "")) != "activity_completed":
					continue
				var objective_activity_id := str(objective.get("activity_id", ""))
				assert_true(activity_ids.has(objective_activity_id), "Quest '%s' references missing activity '%s'" % [quest_id, objective_activity_id])


func test_base_ritual_circle_is_only_exposed_in_the_dorm_room() -> void:
	var assembly_locations: Array[String] = []
	for location_data in DataManager.locations.values():
		if not location_data is Dictionary:
			continue
		var location: Dictionary = location_data
		var location_id := str(location.get("location_id", ""))
		var screens_value: Variant = location.get("screens", [])
		if not screens_value is Array:
			continue
		var screens: Array = screens_value
		for screen_data in screens:
			if not screen_data is Dictionary:
				continue
			var screen: Dictionary = screen_data
			if str(screen.get("backend_class", "")) == "AssemblyEditorBackend":
				assembly_locations.append(location_id)

	var expected_locations: Array[String] = ["base:dorm_room"]
	assert_eq(assembly_locations, expected_locations)


func test_base_dialogue_folder_has_no_legacy_starter_dialogue() -> void:
	var dialogue_files: Array[String] = _files_with_extension("res://mods/base/dialogue", ".dialogue")
	var expected_files: Array[String] = []
	assert_eq(dialogue_files, expected_files)


func test_base_content_has_no_legacy_neon_threshold_strings() -> void:
	var legacy_tokens: Array[String] = ["Neon", "Threshold", "Syndicate", "Quartermaster Theta"]
	var paths: Array[String] = [
		"res://mods/base/README.md",
		"res://mods/base/mod.json",
		"res://mods/base/data/achievements.json",
		"res://mods/base/data/activities.json",
		"res://mods/base/data/ai_personas.json",
		"res://mods/base/data/ai_templates.json",
		"res://mods/base/data/config.json",
		"res://mods/base/data/definitions.json",
		"res://mods/base/data/encounters.json",
		"res://mods/base/data/entities.json",
		"res://mods/base/data/factions.json",
		"res://mods/base/data/locations.json",
		"res://mods/base/data/parts.json",
		"res://mods/base/data/quests.json",
		"res://mods/base/data/recipes.json",
		"res://mods/base/data/status_effects.json",
		"res://mods/base/data/tasks.json",
	]
	for path in paths:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "Unable to read '%s'" % path)
		if file == null:
			continue
		var text := file.get_as_text()
		for legacy_token in legacy_tokens:
			assert_false(text.contains(legacy_token), "Legacy token '%s' remains in '%s'" % [legacy_token, path])


func _known_stat_ids() -> Array[String]:
	var stat_ids: Array[String] = []
	for stat_def in DataManager.get_definitions("stats"):
		if stat_def is Dictionary:
			stat_ids.append(str(stat_def.get("id", "")))
	return stat_ids


func _known_currency_ids() -> Array[String]:
	var currency_ids: Array[String] = []
	for currency_id in DataManager.get_definitions("currencies"):
		currency_ids.append(str(currency_id))
	return currency_ids


func _known_faction_ids() -> Array[String]:
	var faction_ids: Array[String] = []
	for faction_data in DataManager.factions.values():
		if faction_data is Dictionary:
			var faction: Dictionary = faction_data
			faction_ids.append(str(faction.get("faction_id", "")))
	return faction_ids


func _known_part_ids() -> Array[String]:
	var part_ids: Array[String] = []
	for part_data in DataManager.parts.values():
		if part_data is Dictionary:
			var part: Dictionary = part_data
			part_ids.append(str(part.get("id", "")))
	return part_ids


func _known_status_effect_ids() -> Array[String]:
	var status_effect_ids: Array[String] = []
	for status_effect_data in DataManager.status_effects.values():
		if status_effect_data is Dictionary:
			var status_effect: Dictionary = status_effect_data
			status_effect_ids.append(str(status_effect.get("status_effect_id", "")))
	return status_effect_ids


func _known_location_ids() -> Array[String]:
	var location_ids: Array[String] = []
	for location_data in DataManager.locations.values():
		if location_data is Dictionary:
			var location: Dictionary = location_data
			location_ids.append(str(location.get("location_id", "")))
	return location_ids


func _known_entity_ids() -> Array[String]:
	var entity_ids: Array[String] = []
	for entity_data in DataManager.entities.values():
		if entity_data is Dictionary:
			var entity: Dictionary = entity_data
			entity_ids.append(str(entity.get("entity_id", "")))
	return entity_ids


func _known_activity_ids() -> Array[String]:
	var activity_ids: Array[String] = []
	for activity_data in DataManager.activities.values():
		if activity_data is Dictionary:
			var activity: Dictionary = activity_data
			activity_ids.append(str(activity.get("activity_id", "")))
	return activity_ids


func _assert_conditions_reference_known_content(source_id: String, conditions_value: Variant, stat_ids: Array[String]) -> void:
	if not conditions_value is Array:
		return
	var conditions: Array = conditions_value
	for condition_data in conditions:
		if not condition_data is Dictionary:
			continue
		var condition: Dictionary = condition_data
		var condition_type := str(condition.get("type", ""))
		if condition_type == "stat_check":
			var stat_id := str(condition.get("stat", ""))
			assert_true(stat_ids.has(stat_id), "Condition in '%s' references missing stat '%s'" % [source_id, stat_id])
		_assert_conditions_reference_known_content(source_id, condition.get("conditions", []), stat_ids)


func _assert_actions_reference_known_content(
	source_id: String,
	actions_value: Variant,
	stat_ids: Array[String],
	currency_ids: Array[String],
	faction_ids: Array[String],
	part_ids: Array[String],
	status_effect_ids: Array[String]
) -> void:
	if not actions_value is Array:
		return
	var actions: Array = actions_value
	for action_data in actions:
		if not action_data is Dictionary:
			continue
		var action: Dictionary = action_data
		var action_type := str(action.get("type", ""))
		match action_type:
			"modify_stat":
				var stat_id := str(action.get("stat", ""))
				assert_true(stat_ids.has(stat_id), "Action in '%s' references missing stat '%s'" % [source_id, stat_id])
			"give_currency":
				var currency_id := str(action.get("currency_id", ""))
				assert_true(currency_ids.has(currency_id), "Action in '%s' references missing currency '%s'" % [source_id, currency_id])
			"modify_reputation":
				var faction_id := str(action.get("faction_id", ""))
				assert_true(faction_ids.has(faction_id), "Action in '%s' references missing faction '%s'" % [source_id, faction_id])
			"give_part", "remove_part":
				var part_id := str(action.get("part_id", ""))
				assert_true(part_ids.has(part_id), "Action in '%s' references missing part '%s'" % [source_id, part_id])
			"apply_status_effect":
				var status_effect_id := str(action.get("status_effect_id", ""))
				assert_true(status_effect_ids.has(status_effect_id), "Action in '%s' references missing status effect '%s'" % [source_id, status_effect_id])


func _inventory_entry_for_instance(inventory: Array, instance_id: String) -> Dictionary:
	for entry_data in inventory:
		if not entry_data is Dictionary:
			continue
		var entry: Dictionary = entry_data
		if str(entry.get("instance_id", "")) == instance_id:
			return entry
	return {}


func _files_with_extension(path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return files
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(extension):
			files.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


func test_base_ships_the_timed_recipe_craft_task_shell() -> void:
	var craft_task := DataManager.get_task("base:ritual_craft")
	assert_false(craft_task.is_empty())
	assert_eq(str(craft_task.get("type", "")), "CRAFT")
	assert_eq(int(craft_task.get("duration", 0)), 1)
	assert_true(bool(craft_task.get("repeatable", false)))


func test_base_ships_vanguard_activities_and_quests() -> void:
	var expected_activity_ids := [
		"base:attend_arcana_lecture",
		"base:study_at_library",
		"base:warehouse_shift",
		"base:student_mixer",
		"base:prepare_ritual_circle",
		"base:sleep_in_dorm",
	]
	for activity_id in expected_activity_ids:
		assert_false(DataManager.get_activity(activity_id).is_empty(), "Missing activity '%s'" % activity_id)

	assert_false(DataManager.get_quest("base:orientation").is_empty())
	assert_false(DataManager.get_quest("base:first_assignment").is_empty())
	assert_false(DataManager.get_quest("base:tuition_pressure").is_empty())


func test_base_ships_reference_status_effects() -> void:
	var centered_effect := DataManager.get_status_effect("base:centered")
	assert_false(centered_effect.is_empty())
	var frazzled_effect := DataManager.get_status_effect("base:frazzled")
	assert_false(frazzled_effect.is_empty())
	assert_true(DataManager.has_status_effect("base:well_rested"))
