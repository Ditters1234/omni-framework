extends GutTest

const TEST_FIXTURE_WORLD := preload("res://tests/helpers/test_fixture_world.gd")


func before_each() -> void:
	TEST_FIXTURE_WORLD.bootstrap_runtime_fixture()


func test_set_equipped_template_replaces_slot_contents() -> void:
	var entity := EntityInstance.from_template(DataManager.get_entity("base:player"))
	var initial_equipped_count := entity.equipped.size()

	assert_true(entity.set_equipped_template("hair", "base:body_hair_short"))
	assert_eq(entity.get_equipped_template_id("hair"), "base:body_hair_short")
	assert_eq(entity.equipped.size(), initial_equipped_count + 1)

	assert_true(entity.set_equipped_template("hair", "base:body_hair_long"))
	assert_eq(entity.get_equipped_template_id("hair"), "base:body_hair_long")
	assert_eq(entity.equipped.size(), initial_equipped_count + 1)


func test_inventory_equip_and_unequip_moves_part_between_inventory_and_slot() -> void:
	var entity := EntityInstance.from_template(DataManager.get_entity("base:player"))
	var part := PartInstance.from_template(DataManager.get_part("base:body_arm_standard"))
	var initial_inventory_count := entity.inventory.size()
	entity.add_part(part)

	assert_true(entity.equip(part.instance_id, "left_arm"))
	assert_eq(entity.inventory.size(), initial_inventory_count)
	assert_eq(entity.get_equipped_template_id("left_arm"), "base:body_arm_standard")

	entity.unequip("left_arm")

	assert_eq(entity.get_equipped_template_id("left_arm"), "")
	assert_eq(entity.inventory.size(), initial_inventory_count + 1)


func test_unequip_prunes_parts_when_required_tags_disappear() -> void:
	DataManager.parts["base:test_torso"] = {
		"id": "base:test_torso",
		"display_name": "Test Torso",
		"tags": ["torso"],
	}
	DataManager.parts["base:test_arm"] = {
		"id": "base:test_arm",
		"display_name": "Test Arm",
		"tags": ["arm"],
		"required_tags": ["torso"],
	}
	DataManager.entities["base:test_body"] = {
		"entity_id": "base:test_body",
		"provides_sockets": [
			{"id": "torso", "accepted_tags": ["torso"], "label": "Torso"},
			{"id": "arm", "accepted_tags": ["arm"], "label": "Arm"},
		],
		"inventory": [
			{"instance_id": "test_torso_001", "template_id": "base:test_torso"},
			{"instance_id": "test_arm_001", "template_id": "base:test_arm"},
		],
		"assembly_socket_map": {
			"torso": "test_torso_001",
			"arm": "test_arm_001",
		},
	}
	var entity := EntityInstance.from_template(DataManager.get_entity("base:test_body"))

	entity.unequip("torso")

	assert_eq(entity.get_equipped_template_id("torso"), "")
	assert_eq(entity.get_equipped_template_id("arm"), "")
	var arm := entity.get_inventory_part("test_arm_001")
	assert_not_null(arm)
	assert_false(arm.is_equipped)


func test_inventory_replacement_prunes_only_after_new_part_is_equipped() -> void:
	DataManager.parts["base:test_torso"] = {
		"id": "base:test_torso",
		"display_name": "Test Torso",
		"tags": ["torso"],
	}
	DataManager.parts["base:test_arm"] = {
		"id": "base:test_arm",
		"display_name": "Test Arm",
		"tags": ["arm"],
		"required_tags": ["torso"],
	}
	DataManager.entities["base:test_body"] = {
		"entity_id": "base:test_body",
		"provides_sockets": [
			{"id": "torso", "accepted_tags": ["torso"], "label": "Torso"},
			{"id": "arm", "accepted_tags": ["arm"], "label": "Arm"},
		],
		"inventory": [
			{"instance_id": "test_torso_001", "template_id": "base:test_torso"},
			{"instance_id": "test_torso_002", "template_id": "base:test_torso"},
			{"instance_id": "test_arm_001", "template_id": "base:test_arm"},
		],
		"assembly_socket_map": {
			"torso": "test_torso_001",
			"arm": "test_arm_001",
		},
	}
	var entity := EntityInstance.from_template(DataManager.get_entity("base:test_body"))

	assert_true(entity.equip("test_torso_002", "torso"))

	var torso: PartInstance = entity.get_equipped("torso")
	var arm: PartInstance = entity.get_equipped("arm")
	assert_not_null(torso)
	assert_not_null(arm)
	if torso == null or arm == null:
		return
	assert_eq(torso.instance_id, "test_torso_002")
	assert_eq(arm.instance_id, "test_arm_001")


func test_unequip_prunes_parts_when_dynamic_socket_disappears() -> void:
	DataManager.parts["base:test_frame"] = {
		"id": "base:test_frame",
		"display_name": "Test Frame",
		"tags": ["frame"],
		"provides_sockets": [
			{"id": "module", "accepted_tags": ["module"], "label": "Module"},
		],
	}
	DataManager.parts["base:test_module"] = {
		"id": "base:test_module",
		"display_name": "Test Module",
		"tags": ["module"],
	}
	DataManager.entities["base:test_frame_entity"] = {
		"entity_id": "base:test_frame_entity",
		"provides_sockets": [
			{"id": "frame", "accepted_tags": ["frame"], "label": "Frame"},
		],
		"inventory": [
			{"instance_id": "test_frame_001", "template_id": "base:test_frame"},
			{"instance_id": "test_module_001", "template_id": "base:test_module"},
		],
		"assembly_socket_map": {
			"frame": "test_frame_001",
			"module": "test_module_001",
		},
	}
	var entity := EntityInstance.from_template(DataManager.get_entity("base:test_frame_entity"))

	entity.unequip("frame")

	assert_eq(entity.get_equipped_template_id("frame"), "")
	assert_eq(entity.get_equipped_template_id("module"), "")
	var module := entity.get_inventory_part("test_module_001")
	assert_not_null(module)
	assert_false(module.is_equipped)
