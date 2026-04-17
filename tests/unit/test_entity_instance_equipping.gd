extends GutTest


func before_each() -> void:
	ModLoader.load_all_mods()
	GameState.reset()


func test_set_equipped_template_replaces_slot_contents() -> void:
	var entity := EntityInstance.from_template(DataManager.get_entity("base:player"))

	assert_true(entity.set_equipped_template("hair", "base:body_hair_short"))
	assert_eq(entity.get_equipped_template_id("hair"), "base:body_hair_short")

	assert_true(entity.set_equipped_template("hair", "base:body_hair_long"))
	assert_eq(entity.get_equipped_template_id("hair"), "base:body_hair_long")
	assert_eq(entity.equipped.size(), 1)


func test_inventory_equip_and_unequip_moves_part_between_inventory_and_slot() -> void:
	var entity := EntityInstance.from_template(DataManager.get_entity("base:player"))
	var part := PartInstance.from_template(DataManager.get_part("base:body_arm_standard"))
	entity.add_part(part)

	assert_true(entity.equip(part.instance_id, "left_arm"))
	assert_eq(entity.inventory.size(), 0)
	assert_eq(entity.get_equipped_template_id("left_arm"), "base:body_arm_standard")

	entity.unequip("left_arm")

	assert_eq(entity.get_equipped_template_id("left_arm"), "")
	assert_eq(entity.inventory.size(), 1)
