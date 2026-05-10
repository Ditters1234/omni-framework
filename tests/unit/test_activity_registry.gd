extends GutTest

const ACTIVITY_REGISTRY := preload("res://systems/loaders/activity_registry.gd")
const TEMP_ROOT := "user://test_scratch/activity_registry"


func before_each() -> void:
	_cleanup_directory(TEMP_ROOT)
	DataManager.clear_all()


func after_each() -> void:
	_cleanup_directory(TEMP_ROOT)


func test_register_additions_loads_and_normalizes_activity_defaults() -> void:
	var data_path := _write_data_file(
		"valid_activity",
		OmniConstants.DATA_ACTIVITIES,
		JSON.stringify({
			"activities": [
				{
					"activity_id": "base:study",
					"display_name": "Study",
					"category": "learning",
					"duration_ticks": 2,
					"location_id": "base:library",
					"actions": [
						{"type": "set_flag", "flag_id": "base:studied", "value": true}
					],
					"script_hook": "res://mods/base/scripts/study_hook.gd",
					"tags": ["quiet"],
					"custom_metadata": {"tone": "calm"},
				}
			]
		})
	)

	var issues := DataManager.register_additions("test:activities", data_path)
	var activity := DataManager.get_activity("base:study")
	var completion_actions_value: Variant = activity.get("completion_actions", [])
	var repeat_value: Variant = activity.get("repeat", {})

	assert_eq(issues.size(), 0)
	assert_true(DataManager.has_activity("base:study"))
	assert_eq(str(activity.get("travel_policy", "")), "must_be_present")
	assert_true(completion_actions_value is Array)
	if completion_actions_value is Array:
		var completion_actions: Array = completion_actions_value
		assert_eq(completion_actions.size(), 1)
	assert_true(repeat_value is Dictionary)
	if repeat_value is Dictionary:
		var repeat: Dictionary = repeat_value
		assert_eq(str(repeat.get("rule", "")), "always")
		assert_eq(int(repeat.get("max_completions", 0)), -1)
	assert_eq(str(activity.get("script_path", "")), "res://mods/base/scripts/study_hook.gd")
	var custom_metadata_value: Variant = activity.get("custom_metadata", {})
	assert_true(custom_metadata_value is Dictionary)
	if custom_metadata_value is Dictionary:
		var custom_metadata: Dictionary = custom_metadata_value
		assert_eq(str(custom_metadata.get("tone", "")), "calm")


func test_register_additions_rejects_missing_required_fields_and_duplicate_ids() -> void:
	var data_path := _write_data_file(
		"invalid_activity_additions",
		OmniConstants.DATA_ACTIVITIES,
		JSON.stringify({
			"activities": [
				{"activity_id": "base:dup", "display_name": "First", "category": "test", "duration_ticks": 1},
				{"activity_id": "base:dup", "display_name": "Second", "category": "test", "duration_ticks": 1},
				{"display_name": "Missing ID", "category": "test", "duration_ticks": 1},
				{"activity_id": "base:missing_category", "display_name": "Missing Category", "duration_ticks": 1},
			]
		})
	)

	var issues := DataManager.register_additions("test:activity_invalid", data_path)
	var issue_messages := _issue_messages(issues)

	assert_eq(DataManager.activities.size(), 1)
	assert_true(DataManager.activities.has("base:dup"))
	assert_true(_messages_contain(issue_messages, "Duplicate activities id 'base:dup'"))
	assert_true(_messages_contain(issue_messages, "missing required field 'activity_id'"))
	assert_true(_messages_contain(issue_messages, "missing required field 'category'"))


func test_apply_patches_updates_activity_fields() -> void:
	DataManager.activities["base:study"] = ACTIVITY_REGISTRY.normalize_activity({
		"activity_id": "base:study",
		"display_name": "Study",
		"category": "learning",
		"duration_ticks": 1,
		"tags": ["quiet", "old"],
		"requirements": [],
		"visible_if": [],
		"completion_actions": [],
		"outcomes": [],
	})
	var data_path := _write_data_file(
		"activity_patch",
		OmniConstants.DATA_ACTIVITIES,
		JSON.stringify({
			"patches": [
				{
					"target": "base:study",
					"set": {"display_name": "Focused Study", "duration_ticks": 3},
					"set_schedule": {"weekdays": ["Mon"], "start_tick": 8, "end_tick": 12},
					"add_tags": ["focused"],
					"remove_tags": ["old"],
					"add_requirements": [{"type": "has_flag", "flag_id": "base:ready"}],
					"set_visible_if": [{"type": "has_flag", "flag_id": "base:visible"}],
					"add_start_actions": [{"type": "set_flag", "flag_id": "base:started"}],
					"set_completion_actions": [{"type": "set_flag", "flag_id": "base:completed"}],
					"add_failure_actions": [{"type": "set_flag", "flag_id": "base:failed"}],
					"add_outcomes": [{"outcome_id": "good", "weight": 2.0, "actions": []}],
					"set_repeat": {"rule": "cooldown", "cooldown_ticks": 5}
				}
			]
		})
	)

	var issues := DataManager.apply_patches("test:activity_patch", data_path)
	var activity := DataManager.get_activity("base:study")
	var tags_value: Variant = activity.get("tags", [])
	var repeat_value: Variant = activity.get("repeat", {})

	assert_eq(issues.size(), 0)
	assert_eq(str(activity.get("display_name", "")), "Focused Study")
	assert_eq(int(activity.get("duration_ticks", 0)), 3)
	assert_true(tags_value is Array)
	if tags_value is Array:
		var tags: Array = tags_value
		assert_true(tags.has("focused"))
		assert_false(tags.has("old"))
	assert_eq(_array_size(activity, "requirements"), 1)
	assert_eq(_array_size(activity, "visible_if"), 1)
	assert_eq(_array_size(activity, "start_actions"), 1)
	assert_eq(_array_size(activity, "completion_actions"), 1)
	assert_eq(_array_size(activity, "failure_actions"), 1)
	assert_eq(_array_size(activity, "outcomes"), 1)
	assert_true(repeat_value is Dictionary)
	if repeat_value is Dictionary:
		var repeat: Dictionary = repeat_value
		assert_eq(str(repeat.get("rule", "")), "cooldown")
		assert_eq(int(repeat.get("cooldown_ticks", 0)), 5)
		assert_eq(int(repeat.get("cooldown_days", -1)), 0)


func test_validate_loaded_content_reports_activity_schema_and_reference_issues() -> void:
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
		},
	}
	DataManager.activities["base:bad_activity"] = {
		"activity_id": "base:bad_activity",
		"display_name": "Bad",
		"category": "bad",
		"duration_ticks": -1,
		"location_id": "base:missing_location",
		"provider_entity_id": "base:missing_provider",
		"schedule": {
			"weekdays": "Mon",
			"start_tick": 12,
			"end_tick": 8,
			"crosses_midnight": false,
			"must_fit_window": true,
		},
		"visible_if": ["not_a_condition"],
		"requirements": {},
		"start_actions": ["not_an_action"],
		"completion_actions": [{"type": "push_screen", "screen_id": "missing_screen"}],
		"outcomes": [
			{
				"weight": -1,
				"conditions": ["not_a_condition"],
				"actions": ["not_an_action"],
			}
		],
		"repeat": {"rule": "whenever"},
	}

	var issues := DataManager.validate_loaded_content()
	var issue_messages := _issue_messages(issues)

	assert_true(_messages_contain(issue_messages, "duration_ticks"))
	assert_true(_messages_contain(issue_messages, "location_id references unknown location"))
	assert_true(_messages_contain(issue_messages, "provider_entity_id references unknown entity"))
	assert_true(_messages_contain(issue_messages, "schedule.weekdays"))
	assert_true(_messages_contain(issue_messages, "schedule.end_tick"))
	assert_true(_messages_contain(issue_messages, "requirements must be an array"))
	assert_true(_messages_contain(issue_messages, "visible_if[0] must be an object"))
	assert_true(_messages_contain(issue_messages, "start_actions[0] must be an object"))
	assert_true(_messages_contain(issue_messages, "completion_actions[0].screen_id references unknown routed screen"))
	assert_true(_messages_contain(issue_messages, "outcomes[0].outcome_id"))
	assert_true(_messages_contain(issue_messages, "outcomes[0].weight"))
	assert_true(_messages_contain(issue_messages, "outcomes.0.conditions[0] must be an object"))
	assert_true(_messages_contain(issue_messages, "outcomes.0.actions[0] must be an object"))
	assert_true(_messages_contain(issue_messages, "repeat.rule"))


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


func _array_size(payload: Dictionary, field_name: String) -> int:
	var value: Variant = payload.get(field_name, [])
	if value is Array:
		var values: Array = value
		return values.size()
	return 0


func _messages_contain(messages: Array[String], expected_fragment: String) -> bool:
	for message in messages:
		if message.contains(expected_fragment):
			return true
	return false
