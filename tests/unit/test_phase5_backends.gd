extends GutTest

const ACTIVE_QUEST_LOG_BACKEND := preload("res://ui/screens/backends/active_quest_log_backend.gd")
const FACTION_REPUTATION_BACKEND := preload("res://ui/screens/backends/faction_reputation_backend.gd")
const ACHIEVEMENT_LIST_BACKEND := preload("res://ui/screens/backends/achievement_list_backend.gd")
const EVENT_LOG_BACKEND := preload("res://ui/screens/backends/event_log_backend.gd")


func before_each() -> void:
	GameEvents.clear_event_history()
	ModLoader.load_all_mods()
	GameState.new_game()
	TimeKeeper.stop()
	_seed_phase5_runtime()


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


func _seed_phase5_runtime() -> void:
	DataManager.quests["base:phase5_quest"] = {
		"quest_id": "base:phase5_quest",
		"display_name": "Phase 5 Quest",
		"stages": [
			{
				"title": "First Stage",
				"description": "Review the first Phase 5 stage.",
				"objectives": [
					{
						"type": "has_flag",
						"flag_id": "phase5_ready",
						"value": true,
						"description": "Set the Phase 5 flag.",
					},
				],
			},
		],
		"reward": {"credits": 3},
	}
	GameState.active_quests["base:phase5_quest"] = {
		"quest_id": "base:phase5_quest",
		"stage_index": 0,
	}
	DataManager.factions["base:phase5_faction"] = {
		"faction_id": "base:phase5_faction",
		"display_name": "Phase 5 Faction",
		"description": "A faction used by Phase 5 backend tests.",
		"faction_color": "primary",
		"territory": ["base:start"],
	}
	var player := GameState.player as EntityInstance
	if player != null:
		player.reputation["base:phase5_faction"] = 25.0
	DataManager.achievements["base:phase5_achievement"] = {
		"achievement_id": "base:phase5_achievement",
		"display_name": "Phase 5 Achievement",
		"description": "A seeded achievement.",
		"stat_name": "phase5_steps",
		"requirement": 3,
	}
	GameState.achievement_stats["phase5_steps"] = 1.0
