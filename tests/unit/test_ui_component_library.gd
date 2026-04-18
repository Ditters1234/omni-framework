extends GutTest

const CURRENCY_DISPLAY_SCENE := preload("res://ui/components/currency_display.tscn")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")
const STAT_SHEET_SCENE := preload("res://ui/components/stat_sheet.tscn")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")

var _spawned_controls: Array[Control] = []


func after_each() -> void:
	for control in _spawned_controls:
		if control == null or not is_instance_valid(control):
			continue
		control.queue_free()
	_spawned_controls.clear()
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
	var portrait_badge := entity_portrait.get_node("MarginContainer/VBoxContainer/TopRow/IdentityColumn/FactionBadgeLabel") as Label

	assert_eq(currency_title.text, "Credits")
	assert_eq(currency_value.text, "$125")
	assert_eq(stat_bar_label.text, "Health")
	assert_eq(stat_bar_value.text, "75 / 100")
	assert_eq(stat_sheet_title.text, "Player Stats")
	assert_gt(stat_sheet_groups.get_child_count(), 0)
	assert_eq(portrait_name.text, "Test Pilot")
	assert_eq(portrait_badge.text, "Runtime Profile")


func _spawn_and_attach(scene: PackedScene) -> Control:
	var instance_value: Variant = scene.instantiate()
	assert_true(instance_value is Control)
	var control: Control = instance_value
	_spawned_controls.append(control)
	get_tree().root.add_child(control)
	return control
