extends GutTest


const TEMP_ROOT := "user://data_manager_contracts"


func before_each() -> void:
	DataManager.clear_all()


func test_register_additions_rejects_wrong_section_type_without_mutating_registry() -> void:
	var data_path := _write_data_file("wrong_section", OmniConstants.DATA_PARTS, "{\"parts\": {\"id\": \"base:bad\"}}")

	var issues := DataManager.register_additions("test:wrong_section", data_path)

	assert_eq(DataManager.parts.size(), 0)
	assert_eq(issues.size(), 1)
	assert_true(str(issues[0].get("message", "")).contains("'parts' must be an array."))


func test_apply_patches_supports_definition_patches() -> void:
	DataManager.definitions["currencies"] = ["credits"]
	var data_path := _write_data_file(
		"definition_patch",
		OmniConstants.DATA_DEFINITIONS,
		"{\"patches\": [{\"category\": \"currencies\", \"add\": [\"gold\"]}]}"
	)

	var issues := DataManager.apply_patches("test:definition_patch", data_path)

	assert_eq(issues.size(), 0)
	assert_eq(DataManager.get_definitions("currencies"), ["credits", "gold"])


func test_apply_patches_reports_missing_patch_targets() -> void:
	var data_path := _write_data_file(
		"missing_patch_target",
		OmniConstants.DATA_PARTS,
		"{\"patches\": [{\"target\": \"base:missing_part\", \"set\": {\"display_name\": \"Nope\"}}]}"
	)

	var issues := DataManager.apply_patches("test:missing_patch_target", data_path)

	assert_eq(issues.size(), 1)
	assert_true(str(issues[0].get("message", "")).contains("Patch target 'base:missing_part'"))


func test_validate_loaded_content_reports_cross_registry_reference_failures() -> void:
	DataManager.parts["base:starter_arm"] = {
		"id": "base:starter_arm"
	}
	DataManager.locations["base:start"] = {
		"location_id": "base:start",
		"connections": {"north": "base:missing_location"}
	}
	DataManager.entities["base:player"] = {
		"entity_id": "base:player",
		"location_id": "base:start"
	}
	DataManager.entities["base:broken_vendor"] = {
		"entity_id": "base:broken_vendor",
		"location_id": "base:missing_location",
		"inventory": [
			{"instance_id": "broken_arm", "template_id": "base:missing_part"}
		],
		"assembly_socket_map": {
			"left_arm": "missing_instance"
		}
	}
	DataManager.config = {
		"game": {
			"starting_player_id": "base:player",
			"starting_location": "base:start"
		}
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_eq(issues.size(), 4)
	assert_true(issue_messages.has("Entity 'base:broken_vendor' references unknown location 'base:missing_location'."))
	assert_true(issue_messages.has("Entity 'base:broken_vendor' inventory references unknown part template 'base:missing_part'."))
	assert_true(issue_messages.has("Entity 'base:broken_vendor' socket 'left_arm' references missing inventory instance 'missing_instance'."))
	assert_true(issue_messages.has("Location 'base:start' connection 'north' references unknown location 'base:missing_location'."))


func test_query_locations_filters_and_returns_copies() -> void:
	DataManager.locations["base:market"] = {
		"location_id": "base:market",
		"connections": {"east": "base:gate"},
		"screens": [
			{"backend_class": "ExchangeBackend", "ui_group": "commerce"}
		]
	}
	DataManager.locations["base:gate"] = {
		"location_id": "base:gate",
		"connections": {},
		"screens": []
	}

	var results := DataManager.query_locations({
		"connected_to": "base:gate",
		"backend_class": "ExchangeBackend",
		"ui_group": "commerce"
	})

	assert_eq(results.size(), 1)
	assert_eq(str(results[0].get("location_id", "")), "base:market")

	results[0]["location_id"] = "mutated"
	assert_eq(str(DataManager.locations["base:market"].get("location_id", "")), "base:market")


func test_debug_snapshot_reports_issue_counts_and_file_activity() -> void:
	var data_path := _write_data_file("snapshot_bad_json", OmniConstants.DATA_PARTS, "{bad json")

	DataManager.register_additions("test:snapshot_bad_json", data_path)
	DataManager.finish_load(false)

	var snapshot := DataManager.get_debug_snapshot()

	assert_eq(str(snapshot.get("status", "")), DataManager.LOAD_PHASE_FAILED)
	assert_false(bool(snapshot.get("is_loaded", true)))
	assert_eq(int(snapshot.get("issue_count", 0)), 1)
	assert_eq(int(snapshot.get("invalid_file_count", 0)), 1)
	assert_true(int(snapshot.get("processed_file_count", 0)) >= 1)


func _write_data_file(test_name: String, file_name: String, contents: String) -> String:
	var data_dir := TEMP_ROOT.path_join(test_name)
	var absolute_data_dir := ProjectSettings.globalize_path(data_dir)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(absolute_data_dir)
	assert_eq(make_dir_error, OK)

	var file_path := data_dir.path_join(file_name)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(contents)
		file.close()
	return data_dir


func _issue_messages(issues: Array[Dictionary]) -> Array[String]:
	var messages: Array[String] = []
	for issue in issues:
		messages.append(str(issue.get("message", "")))
	return messages
