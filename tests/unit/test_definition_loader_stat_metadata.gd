extends GutTest


func before_each() -> void:
	DataManager.clear_all()


func test_load_additions_normalizes_stat_kinds_and_pairs() -> void:
	DefinitionLoader.load_additions({
		"stats": [
			"strength",
			"health",
			"health_max"
		]
	})

	var strength := _find_stat("strength")
	var health := _find_stat("health")
	var health_max := _find_stat("health_max")

	assert_eq(strength.get("kind", ""), "flat")
	assert_eq(health.get("kind", ""), "resource")
	assert_eq(health.get("paired_capacity_id", ""), "health_max")
	assert_eq(health_max.get("kind", ""), "capacity")
	assert_eq(health_max.get("paired_base_id", ""), "health")
	assert_eq(health.get("clamp_min", -1), 0)
	assert_eq(health_max.get("clamp_min", -1), 0)


func _find_stat(stat_id: String) -> Dictionary:
	for stat_def in DataManager.get_definitions("stats"):
		if stat_def is Dictionary and str(stat_def.get("id", "")) == stat_id:
			return stat_def
	return {}
