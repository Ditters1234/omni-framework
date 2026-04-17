extends GutTest


func before_each() -> void:
	GameEvents.clear_event_history()


func test_signal_catalog_exposes_expected_domains_and_filters_deprecated_entries() -> void:
	var ui_signals := GameEvents.get_registered_signal_names("ui")
	var ui_signals_without_deprecated := GameEvents.get_registered_signal_names("ui", false)

	assert_true(ui_signals.has("ui_screen_pushed"))
	assert_true(ui_signals.has("screen_pushed"))
	assert_true(ui_signals_without_deprecated.has("ui_screen_pushed"))
	assert_false(ui_signals_without_deprecated.has("screen_pushed"))
	assert_eq(GameEvents.get_signal_domain("entity_currency_changed"), "economy")
	assert_eq(GameEvents.get_signal_arg_names("task_completed"), ["task_id", "entity_id"])
	assert_true(GameEvents.is_deprecated_signal("currency_changed"))


func test_emit_dynamic_emits_and_records_history() -> void:
	watch_signals(GameEvents)

	assert_true(GameEvents.emit_dynamic("ui_notification_requested", ["Ready", OmniConstants.NOTIFICATION_LEVEL_INFO]))
	assert_signal_emitted(GameEvents, "ui_notification_requested")
	assert_eq(
		get_signal_parameters(GameEvents, "ui_notification_requested"),
		["Ready", OmniConstants.NOTIFICATION_LEVEL_INFO]
	)

	var event_history := GameEvents.get_event_history(10, "ui", "ui_notification_requested")
	assert_eq(event_history.size(), 1)
	assert_eq(str(event_history[0].get("signal_name", "")), "ui_notification_requested")
	assert_eq(str(event_history[0].get("domain", "")), "ui")

	var args_data: Variant = event_history[0].get("args", [])
	assert_true(args_data is Array)
	var args: Array = args_data
	assert_eq(args, ["Ready", OmniConstants.NOTIFICATION_LEVEL_INFO])


func test_emit_dynamic_rejects_unknown_signal_or_wrong_arity() -> void:
	watch_signals(GameEvents)

	assert_false(GameEvents.emit_dynamic("not_a_real_signal", []))
	assert_false(GameEvents.emit_dynamic("quest_started", []))
	assert_signal_not_emitted(GameEvents, "quest_started")
	assert_eq(GameEvents.get_event_history().size(), 0)
