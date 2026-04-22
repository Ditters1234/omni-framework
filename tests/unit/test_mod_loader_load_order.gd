extends GutTest


func before_each() -> void:
	ModLoader.is_loaded = false
	ModLoader.loaded_mods.clear()
	ModLoader.load_report = ModLoader._create_empty_load_report()
	GameEvents.clear_event_history()


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
	assert_push_warning("Skipping mod because dependencies are unavailable")


func test_validate_manifest_normalizes_fields_and_deduplicates_dependencies() -> void:
	var manifest: Dictionary = {
		"id": " sample_mod ",
		"name": " Sample Mod ",
		"version": " 1.0.0 ",
		"load_order": 25.0,
		"enabled": true,
		"schema_version": 2.0,
		"dependencies": ["base", "base", " author:feature "]
	}

	assert_true(ModLoader._validate_manifest(manifest))
	assert_eq(str(manifest.get("id", "")), "sample_mod")
	assert_eq(str(manifest.get("name", "")), "Sample Mod")
	assert_eq(str(manifest.get("version", "")), "1.0.0")
	assert_eq(int(manifest.get("load_order", -1)), 25)
	assert_eq(int(manifest.get("schema_version", -1)), 2)
	assert_eq(manifest.get("dependencies", []), ["base", "author:feature"])


func test_validate_manifest_rejects_invalid_field_types() -> void:
	var manifest: Dictionary = {
		"id": "bad_mod",
		"name": "Bad Mod",
		"version": "1.0.0",
		"load_order": "first",
		"enabled": "yes",
		"dependencies": ["base"]
	}

	assert_false(ModLoader._validate_manifest(manifest))
	assert_push_warning("Manifest field 'load_order' must be an integer.")

	var errors := ModLoader.get_load_errors()
	assert_eq(errors.size(), 1)
	assert_eq(str(errors[0].get("stage", "")), ModLoader.ERROR_STAGE_VALIDATION)
	assert_true(str(errors[0].get("message", "")).contains("load_order"))


func test_validate_base_manifest_requires_enabled_base_with_zero_load_order() -> void:
	var base_manifest: Dictionary = {
		"id": "base",
		"name": "Base Game",
		"version": "1.0.0",
		"load_order": 10,
		"enabled": false,
		"dependencies": []
	}

	assert_false(ModLoader._validate_base_manifest(base_manifest))
	assert_push_error("Base mod cannot be disabled.")

	var errors := ModLoader.get_load_errors()
	assert_eq(errors.size(), 1)
	assert_true(bool(errors[0].get("fatal", false)))


func test_filter_loadable_mods_skips_duplicate_mod_ids() -> void:
	var manifests: Array[Dictionary] = [
		{"id": "base", "load_order": 0, "dependencies": []},
		{"id": "dup_mod", "load_order": 10, "dependencies": ["base"]},
		{"id": "dup_mod", "load_order": 20, "dependencies": ["base"]}
	]

	var filtered := ModLoader._filter_loadable_mods(manifests)

	assert_eq(ModLoader._manifest_id_list(filtered), ["base", "dup_mod"])
	assert_eq(ModLoader.get_load_errors().size(), 1)
	assert_push_warning("Duplicate mod id 'dup_mod' detected")


func test_debug_snapshot_and_boot_events_reflect_ready_state() -> void:
	watch_signals(GameEvents)

	ModLoader.loaded_mods = [
		{"id": "base", "version": "1.0.0", "load_order": 0, "dependencies": []}
	]
	ModLoader.load_report["discovered_mod_count"] = 1
	ModLoader.load_report["discovered_mod_ids"] = ["base"]
	ModLoader.load_report["load_order"] = ["base"]
	ModLoader.load_report["loaded_mod_ids"] = ["base"]
	ModLoader.load_report["loaded_mod_count"] = 1
	ModLoader.load_report["phase_one_ms"] = 4
	ModLoader.load_report["phase_two_ms"] = 2
	ModLoader.load_report["script_hook_preload_ms"] = 1
	ModLoader.is_loaded = true
	ModLoader._emit_loaded_mod_events(ModLoader.loaded_mods)
	GameEvents.all_mods_loaded.emit()
	ModLoader._finalize_load(Time.get_ticks_msec())

	assert_true(ModLoader.is_loaded)
	assert_signal_emitted(GameEvents, "mod_loaded")
	assert_signal_emitted(GameEvents, "all_mods_loaded")
	assert_eq(get_signal_parameters(GameEvents, "mod_loaded"), ["base"])

	var boot_events := GameEvents.get_event_history(10, "boot")
	assert_true(boot_events.size() >= 2)
	assert_eq(str(boot_events[boot_events.size() - 2].get("signal_name", "")), "mod_loaded")
	assert_eq(str(boot_events[boot_events.size() - 1].get("signal_name", "")), "all_mods_loaded")

	var snapshot := ModLoader.get_debug_snapshot()
	assert_eq(str(snapshot.get("status", "")), ModLoader.LOAD_STATUS_LOADED)
	assert_true(bool(snapshot.get("is_loaded", false)))
	assert_eq(int(snapshot.get("error_count", -1)), 0)
	assert_eq(snapshot.get("load_order", []), ["base"])
