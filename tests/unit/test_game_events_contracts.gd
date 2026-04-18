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


func test_save_and_load_emit_documented_success_and_failure_signals() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	TimeKeeper.stop()

	watch_signals(GameEvents)
	SaveManager.save_game(1)
	assert_signal_emitted(GameEvents, "save_started")
	assert_signal_emitted(GameEvents, "save_completed")
	assert_signal_not_emitted(GameEvents, "save_failed")

	watch_signals(GameEvents)
	assert_true(SaveManager.load_game(1))
	assert_signal_emitted(GameEvents, "load_started")
	assert_signal_emitted(GameEvents, "load_completed")
	assert_signal_not_emitted(GameEvents, "load_failed")

	watch_signals(GameEvents)
	SaveManager.save_game(99)
	assert_signal_emitted(GameEvents, "save_failed")

	watch_signals(GameEvents)
	assert_false(SaveManager.load_game(99))
	assert_signal_emitted(GameEvents, "load_failed")


# ---------------------------------------------------------------------------
# Boot pipeline contracts
# ---------------------------------------------------------------------------


func test_mod_loader_can_discover_and_order_base_mod() -> void:
	ModLoader.load_report = ModLoader._create_empty_load_report()
	ModLoader.loaded_mods.clear()
	DataManager.clear_all()

	var discovered := ModLoader._discover_mods()
	var filtered := ModLoader._filter_loadable_mods(discovered)
	var ordered := ModLoader._resolve_load_order(filtered)

	assert_true(discovered.size() >= 1)
	assert_true(filtered.size() >= 1)
	assert_true(ordered.size() >= 1)
	assert_eq(str(ordered[0].get("id", "")), "base")


func test_mod_loader_phase_one_populates_registries() -> void:
	ModLoader.load_report = ModLoader._create_empty_load_report()
	DataManager.clear_all()

	var ordered := ModLoader._resolve_load_order(
		ModLoader._filter_loadable_mods(ModLoader._discover_mods())
	)

	ModLoader._phase_one_additions(ordered)

	assert_false(DataManager.get_entity("base:player").is_empty())
	assert_false(DataManager.get_location("base:start").is_empty())
	assert_true(DataManager.get_definitions("stats").size() > 0)


func test_mod_loader_phase_two_and_script_preload_complete() -> void:
	ModLoader.load_report = ModLoader._create_empty_load_report()
	DataManager.clear_all()

	var ordered := ModLoader._resolve_load_order(
		ModLoader._filter_loadable_mods(ModLoader._discover_mods())
	)

	ModLoader._phase_one_additions(ordered)
	ModLoader._phase_two_patches(ordered)

	var hook_loader := ScriptHookLoader.new()
	hook_loader.preload_all()

	assert_false(DataManager.get_entity("base:player").is_empty())
	assert_false(DataManager.get_config_value("game.starting_player_id", "").is_empty())


func test_mod_loader_load_all_mods_completes() -> void:
	ModLoader.load_all_mods()

	assert_true(ModLoader.is_loaded)
	assert_false(DataManager.get_entity("base:player").is_empty())
	assert_eq(str(ModLoader.get_debug_snapshot().get("status", "")), ModLoader.LOAD_STATUS_LOADED)


func test_boot_can_initialize_ai_and_start_new_game() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()

	assert_true(GameState.player != null)
	assert_eq(GameState.get_currency("credits"), 100.0)
	assert_eq(GameState.current_location_id, "base:start")


func test_repeated_boot_cycle_stays_stable() -> void:
	for _i in range(3):
		ModLoader.load_all_mods()
		AIManager.initialize()
		GameState.new_game()
		GameState.reset()

	assert_true(ModLoader.is_loaded)
	assert_false(DataManager.get_entity("base:player").is_empty())


func test_entity_instance_equipping_flow_matches_boot_suites() -> void:
	ModLoader.load_all_mods()
	GameState.reset()

	var entity := EntityInstance.from_template(DataManager.get_entity("base:player"))
	var part := PartInstance.from_template(DataManager.get_part("base:body_arm_standard"))
	entity.add_part(part)

	assert_true(entity.equip(part.instance_id, "left_arm"))
	assert_eq(entity.get_equipped_template_id("left_arm"), "base:body_arm_standard")

	entity.unequip("left_arm")

	assert_eq(entity.get_equipped_template_id("left_arm"), "")


func test_save_and_load_flow_matches_boot_suites() -> void:
	ModLoader.load_all_mods()
	AIManager.initialize()
	GameState.new_game()
	TimeKeeper.stop()

	GameState.player.set_stat("health", 40.0)
	GameState.add_currency("credits", 25.0)
	GameState.set_flag("debug_test_flag", true)
	GameState.current_tick = 7
	GameState.current_day = 2

	SaveManager.save_game(1)

	GameState.player.set_stat("health", 1.0)
	GameState.spend_currency("credits", 100.0)
	GameState.set_flag("debug_test_flag", false)
	GameState.current_tick = 0
	GameState.current_day = 1

	assert_true(SaveManager.load_game(1))
	assert_eq(GameState.player.get_stat("health"), 40.0)
	assert_eq(GameState.get_currency("credits"), 125.0)
