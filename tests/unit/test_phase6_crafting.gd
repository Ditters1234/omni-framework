extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")
const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const CRAFTING_BACKEND := preload("res://ui/screens/backends/crafting_backend.gd")
const CRAFTING_SCREEN_SCENE := preload("res://ui/screens/backends/crafting_screen.tscn")


func before_each() -> void:
	GameEvents.clear_event_history()
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()
	BACKEND_CONTRACT_REGISTRY.clear()
	CRAFTING_BACKEND.register_contract()
	_seed_recipe_fixture()


func test_crafting_backend_lists_available_recipe_with_recipe_card() -> void:
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_tags": ["fixture_recipe"],
	})

	var view_model: Dictionary = backend.build_view_model()
	var rows_value: Variant = view_model.get("rows", [])
	var card_value: Variant = view_model.get("selected_recipe_card", {})

	assert_true(rows_value is Array)
	if rows_value is Array:
		var rows: Array = rows_value
		assert_eq(rows.size(), 1)
		if not rows.is_empty() and rows[0] is Dictionary:
			var row: Dictionary = rows[0]
			assert_eq(str(row.get("recipe_id", "")), "base:test_grip_recipe")
			assert_true(bool(row.get("craftable", false)))
	assert_true(card_value is Dictionary)
	if card_value is Dictionary:
		var card: Dictionary = card_value
		var input_status_value: Variant = card.get("input_status", [])
		assert_true(input_status_value is Array)


func test_crafting_backend_consumes_inputs_and_adds_output() -> void:
	var player := GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:test_grip_recipe"],
	})
	backend.build_view_model()

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:craft_material"), 0)
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:crafted_grip"), 1)


func test_instant_craft_emits_inventory_signals_per_consumed_and_created_part() -> void:
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:test_grip_recipe"],
	})
	backend.build_view_model()

	backend.confirm()

	assert_eq(GameEvents.get_event_history(0, "inventory", "part_removed").size(), 2)
	assert_eq(GameEvents.get_event_history(0, "inventory", "part_acquired").size(), 1)


func test_crafting_backend_starts_timed_recipe_task() -> void:
	_seed_timed_recipe_fixture()
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:timed_grip_recipe"],
	})
	backend.build_view_model()

	backend.confirm()

	assert_eq(GameState.active_tasks.size(), 1)
	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:craft_material"), 0)
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:crafted_grip"), 0)


func test_timed_craft_emits_task_started_without_output_signal() -> void:
	_seed_timed_recipe_fixture()
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:timed_grip_recipe"],
	})
	backend.build_view_model()

	backend.confirm()

	assert_eq(GameEvents.get_event_history(0, "inventory", "part_removed").size(), 2)
	assert_eq(GameEvents.get_event_history(0, "quests_tasks", "task_started").size(), 1)
	assert_eq(GameEvents.get_event_history(0, "inventory", "part_acquired").size(), 0)


func test_timed_recipe_without_task_template_does_not_consume_or_output() -> void:
	_seed_timed_recipe_fixture()
	DataManager.tasks.erase("base:recipe_craft")
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:timed_grip_recipe"],
	})
	backend.build_view_model()

	backend.confirm()

	assert_eq(GameState.active_tasks.size(), 0)
	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:craft_material"), 2)
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:crafted_grip"), 0)
	var view_model: Dictionary = backend.build_view_model()
	assert_true(str(view_model.get("status_text", "")).contains("Timed crafting is unavailable"))


func test_confirm_rejects_directly_selected_recipe_outside_station_filters() -> void:
	DataManager.recipes["base:other_bench_recipe"] = _recipe_fixture({
		"recipe_id": "base:other_bench_recipe",
		"required_stations": ["base:other_bench"],
	})
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
	})
	backend.select_row("base:other_bench_recipe")

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:craft_material"), 2)
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:crafted_grip"), 0)
	var view_model: Dictionary = backend.build_view_model()
	assert_true(str(view_model.get("status_text", "")).contains("not available"))


func test_confirm_rejects_directly_selected_hidden_recipe() -> void:
	DataManager.recipes["base:hidden_grip_recipe"] = _recipe_fixture({
		"recipe_id": "base:hidden_grip_recipe",
		"discovery": "learned_on_flag",
	})
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
	})
	backend.select_row("base:hidden_grip_recipe")

	backend.confirm()

	var updated_player := GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player != null:
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:craft_material"), 2)
		assert_eq(TransactionService.count_inventory_template(updated_player, "base:crafted_grip"), 0)
	var view_model: Dictionary = backend.build_view_model()
	assert_true(str(view_model.get("status_text", "")).contains("not available"))


func test_non_numeric_required_stat_makes_recipe_uncraftable() -> void:
	DataManager.recipes["base:bad_stat_recipe"] = _recipe_fixture({
		"recipe_id": "base:bad_stat_recipe",
		"required_stats": {"strength": "high"},
	})
	var backend: RefCounted = CRAFTING_BACKEND.new()
	backend.initialize({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:bad_stat_recipe"],
	})

	var view_model: Dictionary = backend.build_view_model()

	assert_false(bool(view_model.get("confirm_enabled", true)))
	assert_true(str(view_model.get("status_text", "")).contains("stats"))


func test_crafting_screen_hides_recipe_card_when_station_has_no_rows() -> void:
	var screen := _spawn_crafting_screen({
		"station_id": "base:empty_bench",
	})
	await get_tree().process_frame

	var card_host := screen.get_node("MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/CardHost") as VBoxContainer
	assert_not_null(card_host)
	if card_host != null and card_host.get_child_count() > 0:
		var recipe_card := card_host.get_child(0) as Control
		assert_not_null(recipe_card)
		if recipe_card != null:
			assert_false(recipe_card.visible)

	screen.queue_free()
	await get_tree().process_frame


func test_crafting_screen_row_text_includes_output_and_confirm_tooltip() -> void:
	var screen := _spawn_crafting_screen({
		"station_id": "base:test_bench",
		"recipe_ids": ["base:test_grip_recipe"],
	})
	await get_tree().process_frame

	var rows_container := screen.get_node("MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer") as VBoxContainer
	assert_not_null(rows_container)
	if rows_container != null and rows_container.get_child_count() > 0:
		var row_button := rows_container.get_child(0) as Button
		assert_not_null(row_button)
		if row_button != null:
			assert_true(row_button.text.contains("Creates Crafted Grip x1"))
			assert_true(row_button.tooltip_text.contains("Ready to craft"))
	var confirm_button := screen.get_node("MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton") as Button
	assert_not_null(confirm_button)
	if confirm_button != null:
		assert_eq(confirm_button.tooltip_text, "Craft Selected")

	screen.queue_free()
	await get_tree().process_frame


func _seed_recipe_fixture() -> void:
	DataManager.parts["base:craft_material"] = {
		"id": "base:craft_material",
		"display_name": "Craft Material",
		"description": "Fixture material.",
		"tags": ["material"],
		"price": {"credits": 1},
		"stats": {},
	}
	DataManager.parts["base:crafted_grip"] = {
		"id": "base:crafted_grip",
		"display_name": "Crafted Grip",
		"description": "Fixture output.",
		"tags": ["arm"],
		"price": {"credits": 4},
		"stats": {"power": 1},
	}
	DataManager.tasks["base:recipe_craft"] = {
		"template_id": "base:recipe_craft",
		"type": "CRAFT",
		"duration": 1,
		"reward": {},
		"repeatable": true,
	}
	DataManager.recipes["base:test_grip_recipe"] = {
		"recipe_id": "base:test_grip_recipe",
		"display_name": "Test Grip",
		"description": "Fixture recipe.",
		"output_template_id": "base:crafted_grip",
		"output_count": 1,
		"inputs": [
			{"template_id": "base:craft_material", "count": 2},
		],
		"required_stations": ["base:test_bench"],
		"required_stats": {"strength": 1},
		"required_flags": [],
		"craft_time_ticks": 0,
		"discovery": "always",
		"tags": ["fixture_recipe"],
	}
	var player := GameState.player as EntityInstance
	if player == null:
		return
	player.add_part(PartInstance.from_template(DataManager.get_part("base:craft_material")))
	player.add_part(PartInstance.from_template(DataManager.get_part("base:craft_material")))


func _recipe_fixture(overrides: Dictionary = {}) -> Dictionary:
	var recipe: Dictionary = {
		"recipe_id": "base:test_grip_recipe",
		"display_name": "Test Grip",
		"description": "Fixture recipe.",
		"output_template_id": "base:crafted_grip",
		"output_count": 1,
		"inputs": [
			{"template_id": "base:craft_material", "count": 2},
		],
		"required_stations": ["base:test_bench"],
		"required_stats": {"strength": 1},
		"required_flags": [],
		"craft_time_ticks": 0,
		"discovery": "always",
		"tags": ["fixture_recipe"],
	}
	for key_value in overrides.keys():
		var key := str(key_value)
		recipe[key] = overrides.get(key_value)
	return recipe


func _spawn_crafting_screen(params: Dictionary) -> Control:
	var instance_value: Variant = CRAFTING_SCREEN_SCENE.instantiate()
	assert_true(instance_value is Control)
	var screen := instance_value as Control
	get_tree().root.add_child(screen)
	if screen.has_method("initialize"):
		screen.call("initialize", params)
	return screen


func _seed_timed_recipe_fixture() -> void:
	DataManager.recipes["base:timed_grip_recipe"] = {
		"recipe_id": "base:timed_grip_recipe",
		"display_name": "Timed Grip",
		"output_template_id": "base:crafted_grip",
		"output_count": 1,
		"inputs": [
			{"template_id": "base:craft_material", "count": 2},
		],
		"required_stations": ["base:test_bench"],
		"craft_time_ticks": 2,
		"discovery": "always",
		"tags": ["fixture_recipe"],
	}
