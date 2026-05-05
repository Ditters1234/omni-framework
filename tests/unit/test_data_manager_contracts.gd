extends GutTest

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const ASSEMBLY_EDITOR_BACKEND := preload("res://ui/screens/backends/assembly_editor_backend.gd")
const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")

const TEMP_ROOT := "user://test_scratch/data_manager_contracts"


func before_each() -> void:
	_cleanup_directory(TEMP_ROOT)
	DataManager.clear_all()
	BACKEND_CONTRACT_REGISTRY.clear()
	ASSEMBLY_EDITOR_BACKEND.register_contract()


func after_each() -> void:
	_cleanup_directory(TEMP_ROOT)


func test_register_additions_rejects_wrong_section_type_without_mutating_registry() -> void:
	var data_path := _write_data_file("wrong_section", OmniConstants.DATA_PARTS, "{\"parts\": {\"id\": \"base:bad\"}}")

	var issues := DataManager.register_additions("test:wrong_section", data_path)

	assert_eq(DataManager.parts.size(), 0)
	assert_eq(issues.size(), 1)
	assert_true(str(issues[0].get("message", "")).contains("'parts' must be an array."))


func test_register_additions_rejects_missing_required_fields_and_duplicate_ids() -> void:
	var data_path := _write_data_file(
		"invalid_parts",
		OmniConstants.DATA_PARTS,
		"{\"parts\": [{\"id\": \"base:dup\", \"display_name\": \"First\", \"description\": \"Valid\", \"tags\": []}, {\"id\": \"base:dup\", \"display_name\": \"Second\", \"description\": \"Duplicate\", \"tags\": []}, {\"id\": \"base:missing_display\", \"description\": \"Missing\", \"tags\": []}]}"
	)

	var issues := DataManager.register_additions("test:invalid_parts", data_path)
	var issue_messages := _issue_messages(issues)

	assert_eq(DataManager.parts.size(), 1)
	assert_true(DataManager.parts.has("base:dup"))
	assert_true(_messages_contain(issue_messages, "Duplicate parts id 'base:dup'"))
	assert_true(_messages_contain(issue_messages, "missing required field 'display_name'"))


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


func test_apply_patches_reports_unknown_patch_operations() -> void:
	DataManager.parts["base:starter_arm"] = {
		"id": "base:starter_arm",
		"display_name": "Starter Arm",
		"description": "A test part.",
		"tags": [],
	}
	var data_path := _write_data_file(
		"unknown_patch_operation",
		OmniConstants.DATA_PARTS,
		"{\"patches\": [{\"target\": \"base:starter_arm\", \"teleport\": true}]}"
	)

	var issues := DataManager.apply_patches("test:unknown_patch_operation", data_path)
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "not a supported parts patch operation"))


func test_register_additions_loads_ai_personas_and_apply_patches_updates_tags() -> void:
	var data_path := _write_data_file(
		"ai_personas",
		OmniConstants.DATA_AI_PERSONAS,
		"{\"ai_personas\": [{\"persona_id\": \"base:test_persona\", \"display_name\": \"Test Persona\", \"system_prompt_template\": \"Stay in character.\", \"tags\": [\"merchant\"]}]}"
	)

	var issues := DataManager.register_additions("test:ai_personas", data_path)

	assert_eq(issues.size(), 0)
	assert_eq(str(DataManager.get_ai_persona("base:test_persona").get("display_name", "")), "Test Persona")

	var patch_data_path := _write_data_file(
		"ai_persona_patch",
		OmniConstants.DATA_AI_PERSONAS,
		"{\"patches\": [{\"target\": \"base:test_persona\", \"add_tags\": [\"quest_giver\"], \"remove_tags\": [\"merchant\"]}]}"
	)

	var patch_issues := DataManager.apply_patches("test:ai_persona_patch", patch_data_path)
	var persona := DataManager.get_ai_persona("base:test_persona")
	var tags_value: Variant = persona.get("tags", [])

	assert_eq(patch_issues.size(), 0)
	assert_true(tags_value is Array)
	if tags_value is Array:
		var tags: Array = tags_value
		assert_true(tags.has("quest_giver"))
		assert_false(tags.has("merchant"))


func test_register_additions_loads_ai_templates_and_apply_patches_updates_tags() -> void:
	var data_path := _write_data_file(
		"ai_templates",
		OmniConstants.DATA_AI_TEMPLATES,
		"{\"ai_templates\": [{\"template_id\": \"base:test_task_flavor\", \"purpose\": \"task_description\", \"prompt_template\": \"Describe {display_name}.\", \"tags\": [\"briefing\"]}]}"
	)

	var issues := DataManager.register_additions("test:ai_templates", data_path)

	assert_eq(issues.size(), 0)
	assert_eq(str(DataManager.get_ai_template("base:test_task_flavor").get("purpose", "")), "task_description")

	var patch_data_path := _write_data_file(
		"ai_template_patch",
		OmniConstants.DATA_AI_TEMPLATES,
		"{\"patches\": [{\"target\": \"base:test_task_flavor\", \"add_tags\": [\"world_gen\"], \"remove_tags\": [\"briefing\"]}]}"
	)

	var patch_issues := DataManager.apply_patches("test:ai_template_patch", patch_data_path)
	var ai_template := DataManager.get_ai_template("base:test_task_flavor")
	var tags_value: Variant = ai_template.get("tags", [])

	assert_eq(patch_issues.size(), 0)
	assert_true(tags_value is Array)
	if tags_value is Array:
		var tags: Array = tags_value
		assert_true(tags.has("world_gen"))
		assert_false(tags.has("briefing"))


func test_validate_loaded_content_reports_cross_registry_reference_failures() -> void:
	DataManager.definitions["currencies"] = ["credits"]
	DataManager.definitions["stats"] = [
		{"id": "power", "kind": "flat"}
	]
	DataManager.parts["base:starter_arm"] = {
		"id": "base:starter_arm",
		"display_name": "Starter Arm",
		"description": "A test part.",
		"tags": [],
	}
	DataManager.locations["base:start"] = {
		"location_id": "base:start",
		"display_name": "Start",
		"connections": {"base:missing_location": 1}
	}
	DataManager.entities["base:player"] = {
		"entity_id": "base:player",
		"display_name": "Player",
		"location_id": "base:start"
	}
	DataManager.entities["base:broken_vendor"] = {
		"entity_id": "base:broken_vendor",
		"display_name": "Broken Vendor",
		"location_id": "base:missing_location",
		"owned_entity_ids": ["base:missing_owned_entity"],
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

	assert_eq(issues.size(), 5)
	assert_true(issue_messages.has("Entity 'base:broken_vendor' references unknown location 'base:missing_location'."))
	assert_true(issue_messages.has("Entity 'base:broken_vendor' owned_entity_ids[0] references unknown entity 'base:missing_owned_entity'."))
	assert_true(issue_messages.has("Entity 'base:broken_vendor' inventory references unknown part template 'base:missing_part'."))
	assert_true(issue_messages.has("Entity 'base:broken_vendor' socket 'left_arm' references missing inventory instance 'missing_instance'."))
	assert_true(issue_messages.has("Location 'base:start' connection 'base:missing_location' references unknown location 'base:missing_location'."))


func test_validate_loaded_content_reports_unknown_stats_and_currencies() -> void:
	DataManager.definitions["currencies"] = ["credits"]
	DataManager.definitions["stats"] = [
		{"id": "power", "kind": "flat"}
	]
	DataManager.parts["base:bad_part"] = {
		"id": "base:bad_part",
		"display_name": "Bad Part",
		"description": "References invalid definitions.",
		"tags": [],
		"stats": {"mystery": 1},
		"price": {"ghost_money": 5},
	}
	DataManager.entities["base:bad_entity"] = {
		"entity_id": "base:bad_entity",
		"display_name": "Bad Entity",
		"stats": {"mystery": 2},
		"currencies": {"ghost_money": 9},
	}
	DataManager.config = {}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "base:bad_part.stats references unknown stat 'mystery'"))
	assert_true(_messages_contain(issue_messages, "base:bad_part.price references unknown currency 'ghost_money'"))
	assert_true(_messages_contain(issue_messages, "base:bad_entity.stats references unknown stat 'mystery'"))
	assert_true(_messages_contain(issue_messages, "base:bad_entity.currencies references unknown currency 'ghost_money'"))


func test_validate_loaded_content_reports_encounter_contract_failures() -> void:
	DataManager.definitions["stats"] = [
		{"id": "health", "kind": "resource", "paired_capacity_id": "health_max"},
		{"id": "health_max", "kind": "capacity", "paired_base_id": "health"}
	]
	DataManager.entities["base:player"] = {
		"entity_id": "base:player",
		"display_name": "Player",
	}
	DataManager.encounters["base:bad_encounter"] = {
		"encounter_id": "base:bad_encounter",
		"participants": {
			"player": {"entity_id": "player"},
			"opponent": {"entity_id": "base:opponent"},
		},
		"encounter_stats": {
			"pressure": {"default": 0, "min": 0, "max": 100}
		},
		"actions": {
			"player": [
				{
					"action_id": "bad",
					"on_success": [
						{"effect": "modify_stat", "target": "opponent", "stat": "missing_stat", "delta": -1},
						{"effect": "modify_encounter_stat", "stat": "missing_meter", "delta": 1},
						{"effect": "resolve", "outcome_id": "missing_outcome"},
						{"effect": "apply_tag", "target": "player"}
					]
				}
			],
			"opponent": []
		},
		"resolution": {
			"outcomes": [
				{"outcome_id": "done", "action_payload": {"type": "push_screen", "screen_id": "missing_screen"}}
			],
			"cancel_outcome": "missing_cancel"
		},
		"opponent_strategy": {"kind": "scripted"}
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "references unknown real stat 'missing_stat'"))
	assert_true(_messages_contain(issue_messages, "references unknown encounter stat 'missing_meter'"))
	assert_true(_messages_contain(issue_messages, "references unknown outcome 'missing_outcome'"))
	assert_true(_messages_contain(issue_messages, "must declare a tag"))
	assert_true(_messages_contain(issue_messages, "cancel_outcome references unknown outcome 'missing_cancel'"))
	assert_true(_messages_contain(issue_messages, "screen_id references unknown routed screen 'missing_screen'"))
	assert_true(_messages_contain(issue_messages, "participants.opponent references unknown entity 'base:opponent'"))
	assert_true(_messages_contain(issue_messages, "opponent_strategy.kind has unsupported value 'scripted'"))


func test_validate_loaded_content_reports_unknown_ai_persona_references() -> void:
	DataManager.entities["base:talker"] = {
		"entity_id": "base:talker",
		"display_name": "Talker",
		"ai_persona_id": "base:missing_persona"
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "references unknown AI persona 'base:missing_persona'"))


func test_validate_loaded_content_reports_recipe_reference_failures() -> void:
	DataManager.definitions["stats"] = [
		{"id": "power", "kind": "flat"}
	]
	DataManager.parts["base:known_output"] = {
		"id": "base:known_output",
		"display_name": "Known Output",
		"description": "Valid output.",
		"tags": [],
	}
	DataManager.recipes["base:broken_recipe"] = {
		"recipe_id": "base:broken_recipe",
		"display_name": "Broken Recipe",
		"output_template_id": "base:missing_output",
		"output_count": 0,
		"inputs": [
			{"template_id": "base:missing_input", "count": 0},
		],
		"required_stats": {"mystery": 1, "power": "high"},
		"required_stations": ["base:bench", 9, ""],
		"required_flags": ["base:flag", 4, ""],
		"tags": ["fixture", false, ""],
		"craft_time_ticks": -1,
		"discovery": "forgotten",
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "output_template_id references unknown part 'base:missing_output'"))
	assert_true(_messages_contain(issue_messages, "inputs[0] references unknown part 'base:missing_input'"))
	assert_true(_messages_contain(issue_messages, "inputs[0].count"))
	assert_true(_messages_contain(issue_messages, "output_count"))
	assert_true(_messages_contain(issue_messages, "craft_time_ticks"))
	assert_true(_messages_contain(issue_messages, "discovery has unknown mode"))
	assert_true(_messages_contain(issue_messages, "required_stats references unknown stat 'mystery'"))
	assert_true(_messages_contain(issue_messages, "required_stats.power must be numeric"))
	assert_true(_messages_contain(issue_messages, "required_stations[1] must be a string"))
	assert_true(_messages_contain(issue_messages, "required_stations[2] must be a non-empty string"))
	assert_true(_messages_contain(issue_messages, "required_flags[1] must be a string"))
	assert_true(_messages_contain(issue_messages, "required_flags[2] must be a non-empty string"))
	assert_true(_messages_contain(issue_messages, "tags[1] must be a string"))
	assert_true(_messages_contain(issue_messages, "tags[2] must be a non-empty string"))


func test_validate_loaded_content_reports_runtime_config_shape_issues() -> void:
	DataManager.definitions["currencies"] = ["credits"]
	DataManager.locations["base:start"] = {
		"location_id": "base:start",
		"display_name": "Start",
		"connections": {},
	}
	DataManager.entities["base:player"] = {
		"entity_id": "base:player",
		"display_name": "Player",
		"location_id": "base:start",
	}
	DataManager.config = {
		"game": {
			"starting_player_id": "base:player",
			"starting_location": "base:start",
			"starting_discovered_locations": ["base:start", "base:missing", ""],
			"ticks_per_day": 0,
			"ticks_per_hour": "fast",
		},
		"ui": {
			"time_advance_buttons": ["1 hour", "", 7, "soon"],
		},
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "starting_discovered_locations[1]"))
	assert_true(_messages_contain(issue_messages, "starting_discovered_locations[2]"))
	assert_true(_messages_contain(issue_messages, "game.ticks_per_day"))
	assert_true(_messages_contain(issue_messages, "game.ticks_per_hour"))
	assert_true(_messages_contain(issue_messages, "ui.time_advance_buttons[1]"))
	assert_true(_messages_contain(issue_messages, "ui.time_advance_buttons[2]"))
	assert_true(_messages_contain(issue_messages, "ui.time_advance_buttons[3]"))


func test_query_locations_filters_and_returns_copies() -> void:
	DataManager.locations["base:market"] = {
		"location_id": "base:market",
		"connections": {"base:gate": 1},
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


func test_validate_loaded_content_reports_unknown_backend_classes_and_contract_type_issues() -> void:
	DataManager.locations["base:market"] = {
		"location_id": "base:market",
		"connections": {},
		"screens": [
			{
				"backend_class": "AssemblyEditorBackend",
				"target_entity_id": ["player"],
			},
			{
				"backend_class": "UnknownBackend",
			},
		],
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "screens[0].target_entity_id"))
	assert_true(_messages_contain(issue_messages, "Unknown backend_class 'UnknownBackend'"))


func test_validate_loaded_content_reports_owned_entities_backend_reference_issues() -> void:
	DataManager.locations["base:market"] = {
		"location_id": "base:market",
		"display_name": "Market",
		"connections": {},
		"screens": [
			{
				"backend_class": "OwnedEntitiesBackend",
				"owner_entity_id": "base:missing_owner",
				"assignment_provider_entity_id": "entity:base:missing_provider",
				"assignment_task_template_id": "base:missing_task",
				"assignment_faction_id": "base:missing_faction",
			},
			{
				"backend_class": "TaskProviderBackend",
				"faction_id": "base:missing_task_faction",
				"provider_entity_id": "base:missing_task_provider",
				"assignee_entity_id": "base:missing_assignee",
				"owner_entity_id": "base:missing_task_owner",
				"assignment_task_template_id": "base:missing_assignment_task",
			},
		],
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "screens[0].owner_entity_id references unknown entity 'base:missing_owner'"))
	assert_true(_messages_contain(issue_messages, "screens[0].assignment_provider_entity_id references unknown entity 'base:missing_provider'"))
	assert_true(_messages_contain(issue_messages, "screens[0].assignment_task_template_id references unknown task 'base:missing_task'"))
	assert_true(_messages_contain(issue_messages, "screens[0].assignment_faction_id references unknown faction 'base:missing_faction'"))
	assert_true(_messages_contain(issue_messages, "screens[1].provider_entity_id references unknown entity 'base:missing_task_provider'"))
	assert_true(_messages_contain(issue_messages, "screens[1].assignee_entity_id references unknown entity 'base:missing_assignee'"))
	assert_true(_messages_contain(issue_messages, "screens[1].owner_entity_id references unknown entity 'base:missing_task_owner'"))
	assert_true(_messages_contain(issue_messages, "screens[1].faction_id references unknown faction 'base:missing_task_faction'"))
	assert_true(_messages_contain(issue_messages, "screens[1].assignment_task_template_id references unknown task 'base:missing_assignment_task'"))


func test_validate_loaded_content_reports_unknown_push_screen_targets() -> void:
	DataManager.locations["base:market"] = {
		"location_id": "base:market",
		"connections": {},
		"screens": [
			{
				"backend_class": "AssemblyEditorBackend",
				"action_payload": {
					"type": "push_screen",
					"screen_id": "exhcange",
				},
			},
		],
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "screens[0].action_payload.screen_id"))
	assert_true(_messages_contain(issue_messages, "unknown routed screen 'exhcange'"))


func test_validate_loaded_content_accepts_known_push_screen_targets_in_quest_actions() -> void:
	var known_screen_ids := UI_ROUTE_CATALOG.get_known_screen_ids()
	assert_true(known_screen_ids.has("main_menu"))
	DataManager.quests["base:test_quest"] = {
		"quest_id": "base:test_quest",
		"stages": [
			{
				"objectives": [],
				"actions": [
					{
						"type": "push_screen",
						"screen_id": "main_menu",
						"params": {
							"from": "quest_stage",
						},
					},
				],
			},
		],
		"action_payload": {
			"type": "push_screen",
			"screen_id": "assembly_editor",
		},
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_false(_messages_contain(issue_messages, "unknown routed screen"))
	assert_false(_messages_contain(issue_messages, "action_payload"))


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


func _cleanup_directory(path: String) -> void:
	if not path.begins_with("user://test_scratch/"):
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(absolute_path)
	if dir != null:
		dir.list_dir_begin()
		var child_name := dir.get_next()
		while not child_name.is_empty():
			if child_name != "." and child_name != "..":
				var child_path := path.path_join(child_name)
				if dir.current_is_dir():
					_cleanup_directory(child_path)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			child_name = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _issue_messages(issues: Array[Dictionary]) -> Array[String]:
	var messages: Array[String] = []
	for issue in issues:
		messages.append(str(issue.get("message", "")))
	return messages


func _messages_contain(messages: Array[String], expected_fragment: String) -> bool:
	for message in messages:
		if message.contains(expected_fragment):
			return true
	return false
