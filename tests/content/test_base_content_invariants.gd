extends GutTest

const LOCATION_VIEW_SCREEN := preload("res://ui/screens/location_view/location_view_screen.gd")


func before_all() -> void:
	ModLoader.load_all_mods()


func test_base_bootstrap_content_exists() -> void:
	assert_false(DataManager.get_entity("base:player").is_empty())
	assert_false(DataManager.get_location("base:start").is_empty())
	assert_eq(DataManager.get_config_value("game.starting_player_id", ""), "base:player")


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
				LOCATION_VIEW_SCREEN.BACKEND_SCREEN_MAP.has(backend_class),
				"Unmapped backend_class '%s' in location data" % backend_class
			)


func test_base_mod_ships_reference_dialogue_and_script_hook_fixtures() -> void:
	assert_true(FileAccess.file_exists("res://mods/base/dialogue/sample_greeting.dialogue"))
	assert_true(FileAccess.file_exists("res://mods/base/scripts/sample_script_hook.gd"))
