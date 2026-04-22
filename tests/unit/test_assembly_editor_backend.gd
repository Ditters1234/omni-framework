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


func test_owned_inventory_install_preserves_instance_values_without_spending_currency() -> void:
	var player: EntityInstance = GameState.player as EntityInstance
	assert_not_null(player)
	if player == null:
		return
	var spare_head := _make_part_instance("base:human_head", "spare_head_blue")
	spare_head.custom_values["eye_color"] = "blue"
	spare_head.custom_values["hair_color"] = "silver"
	player.add_part(spare_head)
	var initial_credits := player.get_currency("credits")

	var backend := ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"budget_entity_id": "player",
		"budget_currency_id": "credits",
		"option_source_entity_id": "player",
		"option_template_ids": ["base:human_head"],
	})
	var view_model := backend.build_view_model()
	var part_detail := _read_dictionary(view_model.get("part_detail", {}))
	assert_true(str(part_detail.get("price_text", "")).contains("Owned"))

	backend.apply_slot("head")
	backend.confirm()

	var updated_player: EntityInstance = GameState.player as EntityInstance
	assert_not_null(updated_player)
	if updated_player == null:
		return
	assert_eq(updated_player.get_currency("credits"), initial_credits)
	var equipped_head: PartInstance = updated_player.get_equipped("head")
	assert_not_null(equipped_head)
	if equipped_head == null:
		return
	assert_eq(equipped_head.instance_id, "spare_head_blue")
	assert_eq(str(equipped_head.custom_values.get("eye_color", "")), "blue")
	assert_eq(str(equipped_head.custom_values.get("hair_color", "")), "silver")
	assert_true(_inventory_has_instance(updated_player, "player_head_001"))
	assert_false(_inventory_has_instance(updated_player, "spare_head_blue"))


func test_vendor_inventory_install_charges_and_moves_exact_instance() -> void:
	var player: EntityInstance = GameState.player as EntityInstance
	var vendor := GameState.get_entity_instance("base:test_vendor")
	assert_not_null(player)
	assert_not_null(vendor)
	if player == null or vendor == null:
		return
	var initial_player_credits := player.get_currency("credits")
	var initial_vendor_credits := vendor.get_currency("credits")
	assert_true(_inventory_has_instance(vendor, "theta_implant_001"))

	var backend := ASSEMBLY_EDITOR_BACKEND.new()
	backend.initialize({
		"target_entity_id": "player",
		"budget_entity_id": "player",
		"budget_currency_id": "credits",
		"option_source_entity_id": "base:test_vendor",
		"payment_recipient_id": "base:test_vendor",
		"option_template_ids": ["base:optic_implant"],
	})

	backend.apply_slot("neural_slot")
	backend.confirm()

	var updated_player: EntityInstance = GameState.player as EntityInstance
	var updated_vendor := GameState.get_entity_instance("base:test_vendor")
	assert_not_null(updated_player)
	assert_not_null(updated_vendor)
	if updated_player == null or updated_vendor == null:
		return
	assert_eq(updated_player.get_currency("credits"), initial_player_credits - 150.0)
	assert_eq(updated_vendor.get_currency("credits"), initial_vendor_credits + 150.0)
	assert_false(_inventory_has_instance(updated_vendor, "theta_implant_001"))
	var equipped_implant: PartInstance = updated_player.get_equipped("neural_slot")
	assert_not_null(equipped_implant)
	if equipped_implant == null:
		return
	assert_eq(equipped_implant.instance_id, "theta_implant_001")


func _make_part_instance(template_id: String, instance_id: String) -> PartInstance:
	var part := PartInstance.from_template(DataManager.get_part(template_id))
	part.instance_id = instance_id
	return part


func _inventory_has_instance(entity: EntityInstance, instance_id: String) -> bool:
	if entity == null:
		return false
	for part_value in entity.inventory:
		var part: PartInstance = part_value as PartInstance
		if part == null:
			continue
		if part.instance_id == instance_id:
			return true
	return false


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}
