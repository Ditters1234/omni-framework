extends GutTest


func before_each() -> void:
	DataManager.clear_all()
	GameState.reset()


func test_from_template_initializes_custom_values_from_custom_fields() -> void:
	var part := PartInstance.from_template({
		"id": "base:test_head",
		"custom_fields": [
			{"id": "eye_color", "label": "Eye Color", "default_value": "brown"},
			{"id": "hair_color", "label": "Hair Color", "default_value": "black"},
		],
	})

	assert_eq(str(part.get_custom_value("eye_color", "")), "brown")
	assert_eq(str(part.get_custom_value("hair_color", "")), "black")


func test_from_template_keeps_legacy_custom_field_labels_as_blank_values() -> void:
	var part := PartInstance.from_template({
		"id": "base:test_legacy_head",
		"custom_field_labels": ["Eye Color"],
	})

	assert_true(part.custom_values.has("eye_color"))
	assert_eq(str(part.get_custom_value("eye_color", "fallback")), "")


func test_entity_inventory_entry_overrides_custom_field_defaults() -> void:
	DataManager.parts["base:test_head"] = {
		"id": "base:test_head",
		"display_name": "Test Head",
		"description": "Customizable head.",
		"tags": ["head"],
		"custom_fields": [
			{"id": "eye_color", "label": "Eye Color", "default_value": "brown"},
			{"id": "hair_color", "label": "Hair Color", "default_value": "black"},
		],
	}

	var entity := EntityInstance.from_template({
		"entity_id": "base:test_entity",
		"inventory": [
			{
				"instance_id": "test_head_001",
				"template_id": "base:test_head",
				"custom_values": {
					"eye_color": "green",
				},
			},
		],
	})
	var head := entity.get_inventory_part("test_head_001")

	assert_not_null(head)
	assert_eq(str(head.get_custom_value("eye_color", "")), "green")
	assert_eq(str(head.get_custom_value("hair_color", "")), "black")


func test_custom_values_round_trip_through_part_dict() -> void:
	var part := PartInstance.from_template({
		"id": "base:test_head",
		"custom_fields": [
			{"id": "eye_color", "label": "Eye Color", "default_value": "brown"},
		],
	})
	part.set_custom_value("eye_color", "violet")

	var clone := PartInstance.new()
	clone.from_dict(part.to_dict())

	assert_eq(str(clone.get_custom_value("eye_color", "")), "violet")
