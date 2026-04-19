extends GutTest

const ASSEMBLY_EDITOR_BACKEND := preload("res://ui/screens/backends/assembly_editor_backend.gd")
const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")


func before_each() -> void:
	BACKEND_CONTRACT_REGISTRY.clear()
	ASSEMBLY_EDITOR_BACKEND.register_contract()
	ModLoader.load_all_mods()
	GameState.new_game()


func test_build_view_model_returns_rows_and_sidebar_data_for_player_loadout() -> void:
	var backend: RefCounted = ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"screen_title": "Character Loadout",
		"confirm_label": "Done",
		"cancel_label": "Back",
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])
	var part_detail_value: Variant = view_model.get("part_detail", {})
	var currency_summary_value: Variant = view_model.get("currency_summary", {})
	var row_count := 0
	if rows_value is Array:
		var rows: Array = rows_value
		row_count = rows.size()

	assert_eq(str(view_model.get("title", "")), "Character Loadout")
	assert_eq(str(view_model.get("confirm_label", "")), "Done")
	assert_true(rows_value is Array)
	assert_true(row_count > 0)
	assert_true(part_detail_value is Dictionary)
	assert_true(currency_summary_value is Dictionary)


func test_build_cancel_action_returns_pop_when_cancel_screen_is_empty() -> void:
	var backend := ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"cancel_screen_id": "",
	})

	var action := backend.build_cancel_action()

	assert_eq(str(action.get("type", "")), "pop")


func test_confirm_requires_pending_changes_by_default() -> void:
	var backend := ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"next_screen_id": "gameplay_shell",
		"next_screen_params": {
			"source": "assembly_editor_test",
		},
	})

	var action := backend.confirm()

	assert_eq(action, {})


func test_confirm_returns_configured_next_screen_action_when_allowing_no_change_confirmation() -> void:
	var backend := ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"next_screen_id": "gameplay_shell",
		"next_screen_params": {
			"source": "assembly_editor_test",
		},
		"allow_confirm_without_changes": true,
	})

	var action := backend.confirm()

	assert_eq(str(action.get("type", "")), "replace_all")
	assert_eq(str(action.get("screen_id", "")), "gameplay_shell")
	var params_value: Variant = action.get("params", {})
	assert_true(params_value is Dictionary)
	var params: Dictionary = params_value
	assert_eq(str(params.get("source", "")), "assembly_editor_test")
