extends GutTest

const CURRENCY_DISPLAY_SCENE := preload("res://ui/components/currency_display.tscn")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")
const STAT_SHEET_SCENE := preload("res://ui/components/stat_sheet.tscn")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const PART_CARD_SCENE := preload("res://ui/components/part_card.tscn")
const FACTION_BADGE_SCENE := preload("res://ui/components/faction_badge.tscn")
const QUEST_CARD_SCENE := preload("res://ui/components/quest_card.tscn")
const RECIPE_CARD_SCENE := preload("res://ui/components/recipe_card.tscn")
const TAB_PANEL_SCENE := preload("res://ui/components/tab_panel.tscn")
const NOTIFICATION_POPUP_SCENE := preload("res://ui/components/notification_popup.tscn")
const ASSEMBLY_SLOT_ROW_SCENE := preload("res://ui/components/assembly_slot_row.tscn")
const TAB_PANEL_FIRST_SCENE := preload("res://tests/fixtures/ui/tab_panel_test_first.tscn")
const TAB_PANEL_SECOND_SCENE := preload("res://tests/fixtures/ui/tab_panel_test_second.tscn")

var _spawned_controls: Array[Control] = []
var _test_viewport: SubViewport = null


func before_each() -> void:
	_test_viewport = _create_test_viewport()


func after_each() -> void:
	for control in _spawned_controls:
		if control == null or not is_instance_valid(control):
			continue
		control.queue_free()
	_spawned_controls.clear()
	if _test_viewport != null and is_instance_valid(_test_viewport):
		_test_viewport.queue_free()
	_test_viewport = null
	await get_tree().process_frame


func test_foundational_component_library_renders_sample_view_models() -> void:
	var currency_display := _spawn_and_attach(CURRENCY_DISPLAY_SCENE)
	currency_display.call("render", {
		"currency_id": "credits",
		"label": "Credits",
		"amount": 125.0,
		"symbol": "$",
		"color_token": "primary",
	})

	var stat_bar := _spawn_and_attach(STAT_BAR_SCENE)
	stat_bar.call("render", {
		"stat_id": "health",
		"label": "Health",
		"value": 75.0,
		"max_value": 100.0,
		"color_token": "positive",
	})

	var stat_sheet := _spawn_and_attach(STAT_SHEET_SCENE)
	stat_sheet.call("render", {
		"title": "Player Stats",
		"groups": {
			"survival": [
				{
					"stat_id": "health",
					"label": "Health",
					"value": 75.0,
					"max_value": 100.0,
					"color_token": "positive",
				}
			],
			"combat": [
				{
					"stat_id": "strength",
					"label": "Strength",
					"value": 5.0,
					"color_token": "warning",
				}
			],
		},
	})

	var entity_portrait := _spawn_and_attach(ENTITY_PORTRAIT_SCENE)
	entity_portrait.call("render", {
		"display_name": "Test Pilot",
		"description": "A reusable entity card for gameplay shell and dialogue surfaces.",
		"faction_badge": {"label": "Runtime Profile"},
		"stat_preview": [
			{
				"stat_id": "health",
				"label": "Health",
				"value": 75.0,
				"max_value": 100.0,
				"color_token": "positive",
			}
		],
	})

	await get_tree().process_frame

	var currency_title := currency_display.get_node("MarginContainer/VBoxContainer/TitleLabel") as Label
	var currency_value := currency_display.get_node("MarginContainer/VBoxContainer/ValueLabel") as Label
	var stat_bar_label := stat_bar.get_node("MarginContainer/VBoxContainer/HeaderRow/Label") as Label
	var stat_bar_value := stat_bar.get_node("MarginContainer/VBoxContainer/HeaderRow/ValueLabel") as Label
	var stat_sheet_title := stat_sheet.get_node("MarginContainer/VBoxContainer/TitleLabel") as Label
	var stat_sheet_groups := stat_sheet.get_node("MarginContainer/VBoxContainer/GroupsContainer") as VBoxContainer
	var portrait_name := entity_portrait.get_node("MarginContainer/VBoxContainer/TopRow/IdentityColumn/DisplayNameLabel") as Label
	var portrait_badge := entity_portrait.get_node("MarginContainer/VBoxContainer/TopRow/IdentityColumn/FactionBadge/MarginContainer/HBoxContainer/TextColumn/NameLabel") as Label

	assert_eq(currency_title.text, "Credits")
	assert_eq(currency_value.text, "$125")
	assert_eq(stat_bar_label.text, "Health")
	assert_eq(stat_bar_value.text, "75 / 100")
	assert_eq(stat_sheet_title.text, "Player Stats")
	assert_gt(stat_sheet_groups.get_child_count(), 0)
	assert_eq(portrait_name.text, "Test Pilot")
	assert_eq(portrait_badge.text, "Runtime Profile")


func test_remaining_component_library_renders_sample_view_models() -> void:
	var part_card := _spawn_and_attach(PART_CARD_SCENE)
	part_card.call("render", {
		"template": {
			"id": "base:body_arm_standard",
			"display_name": "Standard Arm",
			"description": "A reliable modular arm.",
			"tags": ["arm"],
			"price": {"credits": 8},
			"stats": {"strength": 2},
		},
		"default_sprite_paths": {},
		"price_text": "Price: 8 Credits",
		"badges": ["Inventory", {"label": "Affordable", "color_token": "positive"}],
		"affordable": true,
	})

	var faction_badge := _spawn_and_attach(FACTION_BADGE_SCENE)
	faction_badge.call("render", {
		"faction_id": "base:test_faction",
		"reputation_tier": "Friendly",
		"reputation_value": 25,
		"color": "secondary",
	})

	var quest_card := _spawn_and_attach(QUEST_CARD_SCENE)
	quest_card.call("render", {
		"quest_id": "base:first_gig",
		"display_name": "First Gig",
		"current_stage": "Reach the safehouse",
		"objectives": [
			{"label": "Find a weapon", "satisfied": true},
			{"label": "Reach the safehouse", "satisfied": false},
		],
		"rewards": {"gold": 1000},
	})

	var recipe_card := _spawn_and_attach(RECIPE_CARD_SCENE)
	recipe_card.call("render", {
		"recipe": {
			"display_name": "Iron Sword",
			"description": "A plain but reliable blade.",
			"output_count": 1,
			"output_template_id": "base:iron_sword_part",
			"craft_time_ticks": 4,
			"required_stations": ["base:forge"],
			"required_stats": {"smithing": 5},
		},
		"input_status": [
			{"template_id": "base:iron_ingot", "required": 2, "have": 2, "satisfied": true},
			{"template_id": "base:leather_strip", "required": 1, "have": 0, "satisfied": false},
		],
		"output_template": {"display_name": "Iron Sword Part"},
	})

	var notification_popup := _spawn_and_attach(NOTIFICATION_POPUP_SCENE)
	notification_popup.call("render", {
		"message": "Quest updated.",
		"level": "warning",
		"duration_ms": 1000,
	})

	await get_tree().process_frame

	var part_title := part_card.get_node("MarginContainer/VBoxContainer/TitleLabel") as Label
	var part_price := part_card.get_node("MarginContainer/VBoxContainer/PriceLabel") as Label
	var badge_name := faction_badge.get_node("MarginContainer/HBoxContainer/TextColumn/NameLabel") as Label
	var badge_rep := faction_badge.get_node("MarginContainer/HBoxContainer/TextColumn/ReputationLabel") as Label
	var quest_title := quest_card.get_node("MarginContainer/VBoxContainer/TitleLabel") as Label
	var quest_rewards := quest_card.get_node("MarginContainer/VBoxContainer/RewardsLabel") as Label
	var recipe_output := recipe_card.get_node("MarginContainer/VBoxContainer/OutputLabel") as Label
	var popup_message := notification_popup.get_node("MarginContainer/HBoxContainer/MessageLabel") as Label

	assert_eq(part_title.text, "Standard Arm")
	assert_eq(part_price.text, "Price: 8 Credits")
	assert_eq(badge_name.text, "Test Faction")
	assert_eq(badge_rep.text, "Friendly (+25)")
	assert_eq(quest_title.text, "First Gig")
	assert_eq(quest_rewards.text, "Rewards: Gold: 1000")
	assert_eq(recipe_output.text, "Output: Iron Sword Part x1")
	assert_eq(popup_message.text, "Quest updated.")
	assert_true(notification_popup.visible)


func test_tab_panel_switches_content_between_tabs() -> void:
	var tab_panel := _spawn_and_attach(TAB_PANEL_SCENE)
	tab_panel.call("render", {
		"tabs": [
			{
				"id": "first",
				"label": "First",
				"content_scene": TAB_PANEL_FIRST_SCENE,
			},
			{
				"id": "second",
				"label": "Second",
				"content_scene": TAB_PANEL_SECOND_SCENE,
			},
		],
		"selected_id": "first",
	})

	await get_tree().process_frame

	var content_label := tab_panel.get_node("MarginContainer/VBoxContainer/ContentContainer/TabPanelTestFirst/Label") as Label
	assert_eq(content_label.text, "First Tab Content")

	tab_panel.call("select_tab", "second")
	await get_tree().process_frame

	var second_label := tab_panel.get_node("MarginContainer/VBoxContainer/ContentContainer/TabPanelTestSecond/Label") as Label
	assert_eq(second_label.text, "Second Tab Content")


func test_assembly_slot_row_renders_selection_state_and_button_availability() -> void:
	var assembly_slot_row := _spawn_and_attach(ASSEMBLY_SLOT_ROW_SCENE)
	assembly_slot_row.call("render", {
		"slot_id": "left_arm",
		"slot_label": "Left Arm",
		"current_name": "Standard Arm",
		"preview_name": "Reinforced Arm",
		"has_options": true,
		"can_apply": true,
		"can_clear": true,
		"selected": true,
	})

	await get_tree().process_frame

	var slot_label := assembly_slot_row.get_node("MarginContainer/VBoxContainer/HeaderRow/SlotLabel") as Label
	var selection_label := assembly_slot_row.get_node("MarginContainer/VBoxContainer/HeaderRow/SelectionStateLabel") as Label
	var current_label := assembly_slot_row.get_node("MarginContainer/VBoxContainer/CurrentLabel") as Label
	var preview_label := assembly_slot_row.get_node("MarginContainer/VBoxContainer/PreviewLabel") as Label
	var apply_button := assembly_slot_row.get_node("MarginContainer/VBoxContainer/ButtonRow/ApplyButton") as Button
	var clear_button := assembly_slot_row.get_node("MarginContainer/VBoxContainer/ButtonRow/ClearButton") as Button

	assert_eq(slot_label.text, "Left Arm")
	assert_eq(selection_label.text, "Selected")
	assert_eq(current_label.text, "Current: Standard Arm")
	assert_eq(preview_label.text, "Preview: Reinforced Arm")
	assert_false(apply_button.disabled)
	assert_false(clear_button.disabled)


func _spawn_and_attach(scene: PackedScene) -> Control:
	var instance_value: Variant = scene.instantiate()
	assert_true(instance_value is Control)
	var control: Control = instance_value
	_spawned_controls.append(control)
	assert_not_null(_test_viewport)
	_test_viewport.add_child(control)
	return control


func _create_test_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "TestUIComponentViewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	get_tree().root.add_child(viewport)
	return viewport
