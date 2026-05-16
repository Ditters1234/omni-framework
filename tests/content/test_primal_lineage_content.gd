extends GutTest


func before_all() -> void:
	ModLoader.load_all_mods()


func test_primal_lineage_mod_loads_after_base() -> void:
	var loaded_ids: Array[String] = []
	for manifest_data in ModLoader.loaded_mods:
		if manifest_data is Dictionary:
			var manifest: Dictionary = manifest_data
			loaded_ids.append(str(manifest.get("id", "")))

	assert_true(loaded_ids.has("base"))
	assert_true(loaded_ids.has("omni:primal_lineage"))
	assert_lt(loaded_ids.find("base"), loaded_ids.find("omni:primal_lineage"))


func test_primal_lineage_adds_socket_compatible_parts() -> void:
	var expected_parts: Dictionary = {
		"omni:primal_lineage:pack_instinct": "cognitive",
		"omni:primal_lineage:hauling_grip": "manipulator",
		"omni:primal_lineage:yard_runner_legs": "locomotion",
		"omni:primal_lineage:dray_frame": "framework"
	}

	for part_id in expected_parts.keys():
		var part: Dictionary = DataManager.get_part(str(part_id))
		assert_false(part.is_empty(), "Missing primal lineage part '%s'" % str(part_id))
		var tags_value: Variant = part.get("tags", [])
		assert_true(tags_value is Array)
		if tags_value is Array:
			var tags: Array = tags_value
			assert_true(tags.has(str(expected_parts.get(part_id, ""))))
			assert_true(tags.has("primal"))
			assert_true(tags.has("lineage_primal"))

		var stats_value: Variant = part.get("stats", {})
		assert_true(stats_value is Dictionary)
		if stats_value is Dictionary:
			var stats: Dictionary = stats_value
			assert_true(stats.has("normalcy"), "Primal part '%s' should demonstrate normalcy tradeoffs" % str(part_id))


func test_primal_lineage_adds_industrial_ward_activity_variants() -> void:
	var expected_activity_ids: Array[String] = [
		"omni:primal_lineage:heavy_crate_run",
		"omni:primal_lineage:loading_dock_standoff",
		"omni:primal_lineage:primal_day_debrief"
	]
	for activity_id in expected_activity_ids:
		var activity: Dictionary = DataManager.get_activity(activity_id)
		assert_false(activity.is_empty(), "Missing primal lineage activity '%s'" % activity_id)

	var crate_run: Dictionary = DataManager.get_activity("omni:primal_lineage:heavy_crate_run")
	assert_eq(str(crate_run.get("location_id", "")), "base:industrial_ward")
	assert_eq(str(crate_run.get("provider_entity_id", "")), "base:foreman_briggs")

	var standoff: Dictionary = DataManager.get_activity("omni:primal_lineage:loading_dock_standoff")
	assert_eq(str(standoff.get("location_id", "")), "base:industrial_ward")
	var requirements_value: Variant = standoff.get("requirements", [])
	assert_true(requirements_value is Array)
	if requirements_value is Array:
		assert_true(_conditions_include_stat(requirements_value, "intimidation"))


func test_primal_lineage_achievement_can_be_unlocked_by_debrief_activity() -> void:
	var achievement: Dictionary = DataManager.get_achievement("omni:primal_lineage:mostly_primal_day")
	assert_false(achievement.is_empty())

	var activity: Dictionary = DataManager.get_activity("omni:primal_lineage:primal_day_debrief")
	var actions_value: Variant = activity.get("completion_actions", [])
	assert_true(actions_value is Array)
	if actions_value is Array:
		assert_true(_actions_unlock_achievement(actions_value, "omni:primal_lineage:mostly_primal_day"))


func _conditions_include_stat(conditions: Array, stat_id: String) -> bool:
	for condition_data in conditions:
		if not condition_data is Dictionary:
			continue
		var condition: Dictionary = condition_data
		if str(condition.get("type", "")) == "stat_check" and str(condition.get("stat", "")) == stat_id:
			return true
	return false


func _actions_unlock_achievement(actions: Array, achievement_id: String) -> bool:
	for action_data in actions:
		if not action_data is Dictionary:
			continue
		var action: Dictionary = action_data
		if str(action.get("type", "")) == "unlock_achievement" and str(action.get("achievement_id", "")) == achievement_id:
			return true
	return false
