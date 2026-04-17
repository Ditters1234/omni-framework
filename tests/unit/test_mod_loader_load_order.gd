extends GutTest


func before_each() -> void:
	ModLoader.load_report = ModLoader._create_empty_load_report()


func test_resolve_load_order_respects_dependencies_before_load_order() -> void:
	var manifests: Array[Dictionary] = [
		{"id": "base", "load_order": 0, "dependencies": []},
		{"id": "late_parent", "load_order": 100, "dependencies": ["base"]},
		{"id": "early_child", "load_order": 10, "dependencies": ["late_parent"]}
	]

	var ordered := ModLoader._resolve_load_order(manifests)

	assert_eq(ModLoader._manifest_id_list(ordered), ["base", "late_parent", "early_child"])


func test_filter_loadable_mods_skips_missing_dependencies() -> void:
	var manifests: Array[Dictionary] = [
		{"id": "base", "load_order": 0, "dependencies": []},
		{"id": "needs_missing", "load_order": 5, "dependencies": ["missing:mod"]}
	]

	var filtered := ModLoader._filter_loadable_mods(manifests)
	var errors_data: Variant = ModLoader.load_report.get("errors", [])
	var errors: Array = []
	if errors_data is Array:
		errors = errors_data

	assert_eq(ModLoader._manifest_id_list(filtered), ["base"])
	assert_true(errors.size() > 0)
