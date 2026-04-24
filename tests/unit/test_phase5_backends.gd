extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const ACTIVE_QUEST_LOG_BACKEND := preload("res://ui/screens/backends/active_quest_log_backend.gd")
const FACTION_REPUTATION_BACKEND := preload("res://ui/screens/backends/faction_reputation_backend.gd")
const ACHIEVEMENT_LIST_BACKEND := preload("res://ui/screens/backends/achievement_list_backend.gd")
const EVENT_LOG_BACKEND := preload("res://ui/screens/backends/event_log_backend.gd")


func before_each() -> void:
	GameEvents.clear_event_history()
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	TEST_FIXTURE_WORLD.seed_phase5_runtime()


func test_active_quest_log_backend_builds_quest_cards() -> void:
	var backend: RefCounted = ACTIVE_QUEST_LOG_BACKEND.new()
	backend.initialize({
		"screen_title": "Quest Log",
	})

	var view_model: Dictionary = backend.build_view_model()
	var cards_value: Variant = view_model.get("cards", [])

	assert_eq(str(view_model.get("title", "")), "Quest Log")
	assert_true(cards_value is Array)
	if cards_value is Array:
		var cards: Array = cards_value
		assert_eq(cards.size(), 1)
		if not cards.is_empty() and cards[0] is Dictionary:
			var card: Dictionary = cards[0]
			assert_eq(str(card.get("quest_id", "")), "base:phase5_quest")


func test_faction_reputation_backend_lists_seeded_faction() -> void:
	var backend: RefCounted = FACTION_REPUTATION_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("faction_id", "")), "base:phase5_faction")


func test_achievement_list_backend_reports_progress_and_unlock_state() -> void:
	var backend: RefCounted = ACHIEVEMENT_LIST_BACKEND.new()
	backend.initialize({})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("achievement_id", "")), "base:phase5_achievement")
			assert_eq(str(row.get("progress_text", "")), "Phase5 Steps: 1 / 3")


func test_achievement_list_backend_hides_hidden_rows_until_unlocked() -> void:
	DataManager.achievements["base:phase5_hidden_achievement"] = {
		"achievement_id": "base:phase5_hidden_achievement",
		"display_name": "Hidden Goal",
		"description": "Should stay hidden until unlocked.",
		"stat_name": "phase5_steps",
		"requirement": 99,
		"hidden": true,
		"unlock_vfx": "res://tests/fixtures/vfx/test_unlock_vfx.tres",
	}
	var backend: RefCounted = ACHIEVEMENT_LIST_BACKEND.new()
	backend.initialize({})

	var locked_view_model: Dictionary = backend.build_view_model()
	var locked_rows_value: Variant = locked_view_model.get("rows", [])

	assert_true(locked_rows_value is Array)
	if locked_rows_value is Array:
		var locked_rows: Array = locked_rows_value
		assert_eq(locked_rows.size(), 1)

	assert_true(GameState.unlock_achievement("base:phase5_hidden_achievement"))

	var unlocked_view_model: Dictionary = backend.build_view_model()
	var unlocked_rows_value: Variant = unlocked_view_model.get("rows", [])

	assert_true(unlocked_rows_value is Array)
	if unlocked_rows_value is Array:
		var unlocked_rows: Array = unlocked_rows_value
		assert_eq(unlocked_rows.size(), 2)
		if not unlocked_rows.is_empty() and unlocked_rows[0] is Dictionary:
			var row: Dictionary = unlocked_rows[0]
			assert_eq(str(row.get("achievement_id", "")), "base:phase5_hidden_achievement")
			assert_true(bool(row.get("hidden", false)))
			assert_eq(str(row.get("unlock_vfx", "")), "res://tests/fixtures/vfx/test_unlock_vfx.tres")


func test_event_log_backend_reads_recent_game_events() -> void:
	GameEvents.ui_notification_requested.emit("Phase 5 notification", "info")
	var backend: RefCounted = EVENT_LOG_BACKEND.new()
	backend.initialize({
		"domain": "ui",
		"limit": 5,
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_true(rows.size() >= 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("signal_name", "")), "ui_notification_requested")
