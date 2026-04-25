extends GutTest

const APP_SETTINGS := preload("res://core/app_settings.gd")
const BT_ACTION_AI_QUERY := preload("res://systems/ai/bt_action_ai_query.gd")
const BT_CONDITION_AI_CHECK := preload("res://systems/ai/bt_condition_ai_check.gd")
const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")

const FAKE_PROVIDER_SCRIPT_PATH := "res://tests/doubles/fake_ai_provider.gd"


class TestSetGreetingAction:
	extends BTAction

	@export var greeting_var: StringName = &"greeting"
	@export var greeting_value: String = ""

	func _tick(_delta: float) -> Status:
		blackboard.set_var(greeting_var, greeting_value)
		return SUCCESS


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture(false)
	AIManager.clear_provider_script_overrides()
	AIManager.set_provider_script_override(AIManager.PROVIDER_OPENAI_COMPATIBLE, FAKE_PROVIDER_SCRIPT_PATH)
	_configure_fake_ai(false)


func after_each() -> void:
	AIManager.clear_provider_script_overrides()
	_configure_fake_ai(false)
	await get_tree().process_frame


func test_bt_action_ai_query_writes_text_result_to_blackboard() -> void:
	_configure_fake_ai(true, {"response": "Stay alert."})
	var task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	task.prompt_template = "Give Kael a greeting for {player_reputation} standing."
	task.result_var = &"greeting"
	task.response_format = "text"

	var blackboard := _initialize_task(task, {
		"player_reputation": "trusted",
	})

	var first_status: int = task.execute(0.0)
	assert_eq(first_status, task.RUNNING)
	await get_tree().process_frame

	var second_status: int = task.execute(0.1)
	assert_eq(second_status, task.SUCCESS)
	assert_eq(str(blackboard.get_var(&"greeting", "", false)), "Stay alert.")


func test_bt_action_ai_query_parses_enum_matches_with_casing_and_partial_text() -> void:
	_configure_fake_ai(true, {"response": "  SMALL discount  "})
	var first_task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	first_task.prompt_template = "Pick a price tier for {player_name}."
	first_task.result_var = &"price_tier"
	first_task.response_format = "enum"
	first_task.enum_options = PackedStringArray(["full_price", "small_discount", "big_discount"])

	var first_blackboard := _initialize_task(first_task, {
		"player_name": "Player",
	})
	var first_status: int = first_task.execute(0.0)
	assert_eq(first_status, first_task.RUNNING)
	await get_tree().process_frame
	assert_eq(first_task.execute(0.1), first_task.SUCCESS)
	assert_eq(str(first_blackboard.get_var(&"price_tier", "", false)), "small_discount")

	_configure_fake_ai(true, {"response": "full"})
	var second_task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	second_task.prompt_template = "Pick a price tier for {player_name}."
	second_task.result_var = &"price_tier"
	second_task.response_format = "enum"
	second_task.enum_options = PackedStringArray(["full_price", "small_discount", "big_discount"])

	var second_blackboard := _initialize_task(second_task, {
		"player_name": "Player",
	})
	assert_eq(second_task.execute(0.0), second_task.RUNNING)
	await get_tree().process_frame
	assert_eq(second_task.execute(0.1), second_task.SUCCESS)
	assert_eq(str(second_blackboard.get_var(&"price_tier", "", false)), "full_price")


func test_bt_action_ai_query_parses_json_and_falls_back_on_malformed_json() -> void:
	_configure_fake_ai(true, {"response": "{\"tone\":\"formal\",\"greeting\":\"Stay sharp.\"}"})
	var json_task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	json_task.prompt_template = "Return Kael's greeting JSON for {time_of_day}."
	json_task.result_var = &"greeting_payload"
	json_task.response_format = "json"

	var json_blackboard := _initialize_task(json_task, {
		"time_of_day": "evening",
	})
	assert_eq(json_task.execute(0.0), json_task.RUNNING)
	await get_tree().process_frame
	assert_eq(json_task.execute(0.1), json_task.SUCCESS)
	var payload_value: Variant = json_blackboard.get_var(&"greeting_payload", {}, false)
	assert_true(payload_value is Dictionary)
	var payload: Dictionary = payload_value
	assert_eq(str(payload.get("tone", "")), "formal")
	assert_eq(str(payload.get("greeting", "")), "Stay sharp.")

	_configure_fake_ai(true, {"response": "not valid json"})
	var invalid_task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	invalid_task.prompt_template = "Return Kael's greeting JSON for {time_of_day}."
	invalid_task.result_var = &"greeting_payload"
	invalid_task.response_format = "json"
	invalid_task.fallback_value = "fallback_json"

	var invalid_blackboard := _initialize_task(invalid_task, {
		"time_of_day": "evening",
	})
	assert_eq(invalid_task.execute(0.0), invalid_task.RUNNING)
	await get_tree().process_frame
	assert_eq(invalid_task.execute(0.1), invalid_task.FAILURE)
	assert_eq(str(invalid_blackboard.get_var(&"greeting_payload", "", false)), "fallback_json")


func test_bt_action_ai_query_times_out_and_writes_fallback_value() -> void:
	_configure_fake_ai(true, {
		"response": "Too late.",
		"delay_frames": 5,
	})
	var task: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	task.prompt_template = "Pick Kael's reply for {time_of_day}."
	task.result_var = &"greeting"
	task.timeout_seconds = 0.01
	task.fallback_value = "fallback_greeting"

	var blackboard := _initialize_task(task, {
		"time_of_day": "night",
	})

	assert_eq(task.execute(0.0), task.RUNNING)
	assert_eq(task.execute(0.02), task.FAILURE)
	assert_eq(str(blackboard.get_var(&"greeting", "", false)), "fallback_greeting")
	for _frame_index in range(6):
		await get_tree().process_frame
	assert_eq(str(blackboard.get_var(&"greeting", "", false)), "fallback_greeting")


func test_bt_condition_ai_check_handles_yes_no_edge_cases_and_default_result() -> void:
	_configure_fake_ai(true, {"response": " YES. "})
	var yes_task: BTConditionAICheck = BT_CONDITION_AI_CHECK.new()
	yes_task.prompt_template = "Should Kael be welcoming to {player_name}?"
	var yes_blackboard := _initialize_task(yes_task, {
		"player_name": "Player",
	})
	assert_true(yes_blackboard != null)
	assert_eq(yes_task.execute(0.0), yes_task.RUNNING)
	await get_tree().process_frame
	assert_eq(yes_task.execute(0.1), yes_task.SUCCESS)

	_configure_fake_ai(true, {"response": "nah"})
	var no_task: BTConditionAICheck = BT_CONDITION_AI_CHECK.new()
	no_task.prompt_template = "Should Kael offer a discount to {player_name}?"
	var no_blackboard := _initialize_task(no_task, {
		"player_name": "Player",
	})
	assert_true(no_blackboard != null)
	assert_eq(no_task.execute(0.0), no_task.RUNNING)
	await get_tree().process_frame
	assert_eq(no_task.execute(0.1), no_task.FAILURE)

	_configure_fake_ai(true, {"response": "maybe"})
	var default_task: BTConditionAICheck = BT_CONDITION_AI_CHECK.new()
	default_task.prompt_template = "Should Kael take the risky route?"
	default_task.default_result = true
	var default_blackboard := _initialize_task(default_task)
	assert_true(default_blackboard != null)
	assert_eq(default_task.execute(0.0), default_task.RUNNING)
	await get_tree().process_frame
	assert_eq(default_task.execute(0.1), default_task.SUCCESS)


func test_kael_reference_behavior_tree_uses_ai_path_and_falls_back_when_ai_is_disabled() -> void:
	_configure_fake_ai(true, {"response": "trusted_evening"})
	var ai_tree := _build_kael_greeting_tree()
	var ai_blackboard := Blackboard.new()
	ai_blackboard.populate_from_dict({
		"player_reputation": "trusted",
		"time_of_day": "evening",
	})
	var ai_agent := Node.new()
	add_child_autofree(ai_agent)
	ai_tree.initialize(ai_agent, ai_blackboard, ai_agent)
	assert_eq(ai_tree.execute(0.0), ai_tree.RUNNING)
	await get_tree().process_frame
	assert_eq(ai_tree.execute(0.1), ai_tree.SUCCESS)
	assert_eq(str(ai_blackboard.get_var(&"greeting", "", false)), "trusted_evening")

	_configure_fake_ai(false)
	var fallback_tree := _build_kael_greeting_tree()
	var fallback_blackboard := Blackboard.new()
	fallback_blackboard.populate_from_dict({
		"player_reputation": "stranger",
		"time_of_day": "night",
	})
	var fallback_agent := Node.new()
	add_child_autofree(fallback_agent)
	fallback_tree.initialize(fallback_agent, fallback_blackboard, fallback_agent)
	assert_eq(fallback_tree.execute(0.0), fallback_tree.SUCCESS)
	assert_eq(str(fallback_blackboard.get_var(&"greeting", "", false)), "Stick to business.")


func _initialize_task(task: BTTask, blackboard_values: Dictionary = {}) -> Blackboard:
	var blackboard := Blackboard.new()
	if not blackboard_values.is_empty():
		blackboard.populate_from_dict(blackboard_values)
	var agent := Node.new()
	add_child_autofree(agent)
	task.initialize(agent, blackboard, agent)
	return blackboard


func _build_kael_greeting_tree() -> BTSelector:
	var root := BTSelector.new()

	var ai_query: BTActionAIQuery = BT_ACTION_AI_QUERY.new()
	ai_query.prompt_template = "Choose Kael's greeting for reputation {player_reputation} during {time_of_day}."
	ai_query.result_var = &"greeting"
	ai_query.response_format = "enum"
	ai_query.enum_options = PackedStringArray(["trusted_evening", "neutral_day", "wary_night"])

	var fallback_action := TestSetGreetingAction.new()
	fallback_action.greeting_var = &"greeting"
	fallback_action.greeting_value = "Stick to business."

	root.add_child(ai_query)
	root.add_child(fallback_action)
	return root


func _configure_fake_ai(enabled: bool, provider_overrides: Dictionary = {}) -> void:
	var ai_settings := _make_settings({
		APP_SETTINGS.AI_ENABLED: enabled,
		APP_SETTINGS.AI_PROVIDER: AIManager.PROVIDER_OPENAI_COMPATIBLE if enabled else AIManager.PROVIDER_DISABLED,
		APP_SETTINGS.AI_MODEL: "fake-model",
	})
	if enabled:
		var ai_section_value: Variant = ai_settings.get(APP_SETTINGS.SECTION_AI, {})
		if ai_section_value is Dictionary:
			var ai_section: Dictionary = ai_section_value
			for key_value in provider_overrides.keys():
				ai_section[str(key_value)] = provider_overrides.get(key_value, null)
			ai_settings[APP_SETTINGS.SECTION_AI] = ai_section
	AIManager.initialize(ai_settings)


func _make_settings(ai_overrides: Dictionary) -> Dictionary:
	var settings := APP_SETTINGS.get_default_settings()
	var ai_settings := APP_SETTINGS.get_ai_settings(settings)
	for key_value in ai_overrides.keys():
		ai_settings[str(key_value)] = ai_overrides.get(key_value, null)
	settings[APP_SETTINGS.SECTION_AI] = ai_settings
	return settings
