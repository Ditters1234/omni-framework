extends GutTest


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
