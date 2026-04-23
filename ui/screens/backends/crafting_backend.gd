extends "res://ui/screens/backends/backend_base.gd"

class_name OmniCraftingBackend

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const RECIPE_CRAFT_TASK_ID := "base:recipe_craft"

var _params: Dictionary = {}
var _selected_recipe_id: String = ""
var _status_text: String = ""


static func register_contract() -> void:
	BACKEND_CONTRACT_REGISTRY.register("CraftingBackend", {
		"required": ["station_id"],
		"optional": [
			"recipe_tags",
			"recipe_ids",
			"crafter_entity_id",
			"input_source_entity_id",
			"output_destination_entity_id",
			"screen_title",
			"screen_description",
			"screen_summary",
			"confirm_label",
			"cancel_label",
			"empty_label",
			"next_screen_id",
			"next_screen_params",
			"pop_on_confirm",
		],
		"field_types": {
			"station_id": TYPE_STRING,
			"recipe_tags": TYPE_ARRAY,
			"recipe_ids": TYPE_ARRAY,
			"crafter_entity_id": TYPE_STRING,
			"input_source_entity_id": TYPE_STRING,
			"output_destination_entity_id": TYPE_STRING,
			"screen_title": TYPE_STRING,
			"screen_description": TYPE_STRING,
			"screen_summary": TYPE_STRING,
			"confirm_label": TYPE_STRING,
			"cancel_label": TYPE_STRING,
			"empty_label": TYPE_STRING,
			"next_screen_id": TYPE_STRING,
			"next_screen_params": TYPE_DICTIONARY,
			"pop_on_confirm": TYPE_BOOL,
		},
		"array_element_types": {
			"recipe_tags": TYPE_STRING,
			"recipe_ids": TYPE_STRING,
		},
	})


func initialize(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_selected_recipe_id = ""
	_status_text = ""


func build_view_model() -> Dictionary:
	var title := str(_params.get("screen_title", "Crafting"))
	var description := str(_params.get("screen_description", "Use known recipes to turn inventory parts into new parts."))
	var summary := str(_params.get("screen_summary", "Select a recipe to inspect requirements and craft the selected output."))
	var empty_label := str(_params.get("empty_label", "No recipes match this station."))
	var crafter := _resolve_entity(_resolve_crafter_lookup())
	var input_source := _resolve_entity(_resolve_input_source_lookup())
	var output_destination := _resolve_entity(_resolve_output_destination_lookup())
	if crafter == null or input_source == null or output_destination == null:
		return {
			"title": title,
			"description": description,
			"summary": summary,
			"rows": [],
			"selected_recipe_card": {},
			"status_text": "Crafting could not resolve its crafter, input source, or output destination.",
			"confirm_label": str(_params.get("confirm_label", "Craft Selected")),
			"cancel_label": str(_params.get("cancel_label", "Back")),
			"empty_label": empty_label,
			"confirm_enabled": false,
		}
	var rows := _build_recipe_rows(crafter, input_source)
	_select_first_row_if_needed(rows)
	var selected_row := _get_selected_row(rows)
	return {
		"title": title,
		"description": description,
		"summary": summary,
		"rows": rows,
		"selected_recipe_card": _read_card_view_model(selected_row),
		"status_text": _build_status_text(rows, selected_row, crafter, input_source, empty_label),
		"confirm_label": str(_params.get("confirm_label", "Craft Selected")),
		"cancel_label": str(_params.get("cancel_label", "Back")),
		"empty_label": empty_label,
		"confirm_enabled": not selected_row.is_empty() and bool(selected_row.get("craftable", false)),
	}


func select_row(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	_status_text = ""


func confirm() -> Dictionary:
	var crafter := _resolve_entity(_resolve_crafter_lookup())
	var input_source := _resolve_entity(_resolve_input_source_lookup())
	var output_destination := _resolve_entity(_resolve_output_destination_lookup())
	if crafter == null or input_source == null or output_destination == null:
		_status_text = "Crafting could not resolve its crafter, input source, or output destination."
		return {}
	var recipe := DataManager.get_recipe(_selected_recipe_id)
	if recipe.is_empty():
		_status_text = "Select a valid recipe before crafting."
		return {}
	if not _recipe_is_available_for_current_context(recipe, crafter, input_source):
		_status_text = "The selected recipe is not available from this crafting station."
		return {}
	var row := _build_recipe_row(recipe, crafter, input_source)
	if row.is_empty() or not bool(row.get("craftable", false)):
		_status_text = str(row.get("status_text", "The selected recipe requirements are not satisfied."))
		return {}
	var output_template_id := str(recipe.get("output_template_id", ""))
	var output_count := maxi(int(recipe.get("output_count", 1)), 1)
	var craft_time_ticks := maxi(int(recipe.get("craft_time_ticks", 0)), 0)
	if output_template_id.is_empty() or not DataManager.has_part(output_template_id):
		_status_text = "Crafting failed because the recipe output is not registered."
		return {}
	if not _can_start_timed_craft(craft_time_ticks):
		return {}
	if not _consume_inputs(recipe, input_source, output_destination):
		_status_text = "Crafting failed while consuming inputs."
		return {}
	if craft_time_ticks > 0:
		var runtime_id := TimeKeeper.accept_task(RECIPE_CRAFT_TASK_ID, {
			"entity_id": output_destination.entity_id,
			"task_type": TaskRunner.TASK_TYPE_CRAFT,
			"duration": craft_time_ticks,
			"allow_duplicate": true,
			"reward": {
				"items": [
					{
						"template_id": output_template_id,
						"count": output_count,
					},
				],
			},
		})
		if runtime_id.is_empty():
			_refund_inputs(recipe, input_source)
			_status_text = "Timed crafting could not be started; inputs were returned."
			return {}
		else:
			_status_text = "Started crafting %s. It will finish in %d ticks." % [_get_recipe_display_name(recipe), craft_time_ticks]
	else:
		TransactionService.add_part_template_count(output_destination, output_template_id, output_count)
		GameState.commit_entity_instance(output_destination, _resolve_output_destination_lookup())
		_status_text = "Crafted %s." % _get_recipe_display_name(recipe)
	var next_screen_id := str(_params.get("next_screen_id", ""))
	if not next_screen_id.is_empty():
		return {
			"type": "push",
			"screen_id": next_screen_id,
			"params": _read_dictionary(_params.get("next_screen_params", {})),
		}
	if bool(_params.get("pop_on_confirm", false)):
		return {"type": "pop"}
	return {}


func _recipe_is_available_for_current_context(recipe: Dictionary, crafter: EntityInstance, input_source: EntityInstance) -> bool:
	return _recipe_matches_current_filters(recipe) and _is_recipe_visible(recipe, crafter, input_source)


func _recipe_matches_current_filters(recipe: Dictionary) -> bool:
	var recipe_id := str(recipe.get("recipe_id", ""))
	var recipe_ids := _read_string_array(_params.get("recipe_ids", []))
	if not recipe_ids.is_empty() and not recipe_ids.has(recipe_id):
		return false
	var recipe_tags := _read_string_array(recipe.get("tags", []))
	var tag_filters := _read_string_array(_params.get("recipe_tags", []))
	for tag_filter in tag_filters:
		if not recipe_tags.has(tag_filter):
			return false
	return _recipe_matches_station(recipe, str(_params.get("station_id", "")))


func _recipe_matches_station(recipe: Dictionary, station_id: String) -> bool:
	if station_id.is_empty():
		return true
	var stations_value: Variant = recipe.get("required_stations", [])
	if not stations_value is Array:
		return true
	var stations: Array = stations_value
	if stations.is_empty():
		return true
	return stations.has(station_id)


func _can_start_timed_craft(craft_time_ticks: int) -> bool:
	if craft_time_ticks <= 0:
		return true
	if not DataManager.has_task(RECIPE_CRAFT_TASK_ID):
		_status_text = "Timed crafting is unavailable because the craft task template is not registered."
		return false
	if TimeKeeper == null:
		_status_text = "Timed crafting is unavailable because the time keeper is not ready."
		return false
	return true


func _build_recipe_rows(crafter: EntityInstance, input_source: EntityInstance) -> Array[Dictionary]:
	var filters: Dictionary = {
		"station_id": str(_params.get("station_id", "")),
	}
	var recipe_tags := _read_string_array(_params.get("recipe_tags", []))
	if not recipe_tags.is_empty():
		filters["tags"] = recipe_tags
	var recipe_ids := _read_string_array(_params.get("recipe_ids", []))
	if not recipe_ids.is_empty():
		filters["recipe_ids"] = recipe_ids
	var candidates := DataManager.query_recipes(filters)
	var rows: Array[Dictionary] = []
	for recipe in candidates:
		if not _is_recipe_visible(recipe, crafter, input_source):
			continue
		var row := _build_recipe_row(recipe, crafter, input_source)
		if not row.is_empty():
			rows.append(row)
	var sort_callable := func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
	rows.sort_custom(sort_callable)
	return rows


func _build_recipe_row(recipe: Dictionary, crafter: EntityInstance, input_source: EntityInstance) -> Dictionary:
	var recipe_id := str(recipe.get("recipe_id", ""))
	if recipe_id.is_empty():
		return {}
	var input_status := _build_input_status(recipe, input_source)
	var inputs_satisfied := _input_status_is_satisfied(input_status)
	var stats_satisfied := _required_stats_are_satisfied(recipe, crafter)
	var flags_satisfied := _required_flags_are_satisfied(recipe, crafter)
	var craftable := inputs_satisfied and stats_satisfied and flags_satisfied
	var output_template := DataManager.get_part(str(recipe.get("output_template_id", "")))
	return {
		"recipe_id": recipe_id,
		"display_name": _get_recipe_display_name(recipe),
		"selected": recipe_id == _selected_recipe_id,
		"craftable": craftable,
		"status_text": _build_row_status_text(inputs_satisfied, stats_satisfied, flags_satisfied),
		"card_view_model": {
			"recipe": recipe.duplicate(true),
			"input_status": input_status,
			"output_template": output_template,
		},
	}


func _consume_inputs(recipe: Dictionary, input_source: EntityInstance, output_destination: EntityInstance) -> bool:
	var inputs_value: Variant = recipe.get("inputs", [])
	if not inputs_value is Array:
		return false
	var inputs: Array = inputs_value
	var required_by_template := _aggregate_required_inputs(inputs)
	for template_id_value in required_by_template.keys():
		var template_id := str(template_id_value)
		var required := int(required_by_template.get(template_id_value, 0))
		if TransactionService.count_inventory_template(input_source, template_id) < required:
			return false
	for input_value in inputs:
		if not input_value is Dictionary:
			continue
		var input: Dictionary = input_value
		var template_id := str(input.get("template_id", ""))
		var count := maxi(int(input.get("count", 1)), 1)
		if not TransactionService.remove_inventory_template_count(input_source, template_id, count):
			return false
	GameState.commit_entity_instance(input_source, _resolve_input_source_lookup())
	if input_source.entity_id != output_destination.entity_id:
		GameState.commit_entity_instance(output_destination, _resolve_output_destination_lookup())
	return true


func _refund_inputs(recipe: Dictionary, input_source: EntityInstance) -> void:
	var inputs_value: Variant = recipe.get("inputs", [])
	if not inputs_value is Array:
		return
	var inputs: Array = inputs_value
	var required_by_template := _aggregate_required_inputs(inputs)
	for template_id_value in required_by_template.keys():
		var template_id := str(template_id_value)
		var count := int(required_by_template.get(template_id_value, 0))
		TransactionService.add_part_template_count(input_source, template_id, count)
	GameState.commit_entity_instance(input_source, _resolve_input_source_lookup())


func _aggregate_required_inputs(inputs: Array) -> Dictionary:
	var required_by_template: Dictionary = {}
	for input_value in inputs:
		if not input_value is Dictionary:
			continue
		var input: Dictionary = input_value
		var template_id := str(input.get("template_id", ""))
		if template_id.is_empty():
			continue
		var current := int(required_by_template.get(template_id, 0))
		required_by_template[template_id] = current + maxi(int(input.get("count", 1)), 1)
	return required_by_template


func _build_input_status(recipe: Dictionary, input_source: EntityInstance) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var inputs_value: Variant = recipe.get("inputs", [])
	if not inputs_value is Array:
		return result
	var inputs: Array = inputs_value
	var required_by_template := _aggregate_required_inputs(inputs)
	var template_ids: Array = required_by_template.keys()
	template_ids.sort()
	for template_id_value in template_ids:
		var template_id := str(template_id_value)
		var required := int(required_by_template.get(template_id_value, 0))
		var have := TransactionService.count_inventory_template(input_source, template_id)
		result.append({
			"template_id": template_id,
			"required": required,
			"have": have,
			"satisfied": have >= required,
		})
	return result


func _input_status_is_satisfied(input_status: Array[Dictionary]) -> bool:
	if input_status.is_empty():
		return false
	for input_status_entry in input_status:
		if not bool(input_status_entry.get("satisfied", false)):
			return false
	return true


func _required_stats_are_satisfied(recipe: Dictionary, crafter: EntityInstance) -> bool:
	var required_stats_value: Variant = recipe.get("required_stats", {})
	if not required_stats_value is Dictionary:
		return true
	var required_stats: Dictionary = required_stats_value
	for stat_key_value in required_stats.keys():
		var stat_key := str(stat_key_value)
		var required_stat_value: Variant = required_stats.get(stat_key_value, 0.0)
		if not _is_number(required_stat_value):
			return false
		var required_value := float(required_stat_value)
		if crafter.effective_stat(stat_key) < required_value:
			return false
	return true


func _required_flags_are_satisfied(recipe: Dictionary, crafter: EntityInstance) -> bool:
	var flags := _read_string_array(recipe.get("required_flags", []))
	for flag_id in flags:
		if crafter.has_flag(flag_id) or GameState.has_flag(flag_id):
			continue
		return false
	return true


func _is_recipe_visible(recipe: Dictionary, crafter: EntityInstance, input_source: EntityInstance) -> bool:
	var discovery := str(recipe.get("discovery", "always"))
	match discovery:
		"always":
			return true
		"learned_on_flag":
			var recipe_id := str(recipe.get("recipe_id", ""))
			var learned_flag := "learned:%s" % recipe_id
			return crafter.has_flag(learned_flag) or GameState.has_flag(learned_flag)
		"auto_on_ingredient_owned":
			var input_status := _build_input_status(recipe, input_source)
			for input_status_entry in input_status:
				if int(input_status_entry.get("have", 0)) <= 0:
					return false
			return not input_status.is_empty()
		_:
			return false


func _select_first_row_if_needed(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_recipe_id = ""
		return
	for row in rows:
		if str(row.get("recipe_id", "")) == _selected_recipe_id:
			return
	_selected_recipe_id = str(rows[0].get("recipe_id", ""))


func _get_selected_row(rows: Array[Dictionary]) -> Dictionary:
	for row in rows:
		if str(row.get("recipe_id", "")) == _selected_recipe_id:
			return row
	return {}


func _read_card_view_model(row: Dictionary) -> Dictionary:
	var card_view_model_value: Variant = row.get("card_view_model", {})
	if card_view_model_value is Dictionary:
		var card_view_model: Dictionary = card_view_model_value
		return card_view_model.duplicate(true)
	return {}


func _build_status_text(
	rows: Array[Dictionary],
	selected_row: Dictionary,
	crafter: EntityInstance,
	input_source: EntityInstance,
	empty_label: String
) -> String:
	if not _status_text.is_empty():
		return _status_text
	if rows.is_empty():
		return empty_label
	if selected_row.is_empty():
		return "Select a recipe to inspect it."
	if bool(selected_row.get("craftable", false)):
		return "%s can craft this using %s inventory." % [
			BACKEND_HELPERS.get_entity_display_name(crafter, crafter.entity_id),
			BACKEND_HELPERS.get_entity_display_name(input_source, input_source.entity_id),
		]
	return str(selected_row.get("status_text", "The selected recipe requirements are not satisfied."))


func _build_row_status_text(inputs_satisfied: bool, stats_satisfied: bool, flags_satisfied: bool) -> String:
	if not inputs_satisfied:
		return "Missing required inputs."
	if not stats_satisfied:
		return "Crafter stats do not meet this recipe's requirements."
	if not flags_satisfied:
		return "Required recipe flags are missing."
	return "Ready to craft."


func _get_recipe_display_name(recipe: Dictionary) -> String:
	var recipe_id := str(recipe.get("recipe_id", ""))
	return str(recipe.get("display_name", BACKEND_HELPERS.humanize_id(recipe_id)))


func _resolve_crafter_lookup() -> String:
	var lookup := str(_params.get("crafter_entity_id", "player"))
	return "player" if lookup.is_empty() else lookup


func _resolve_input_source_lookup() -> String:
	var lookup := str(_params.get("input_source_entity_id", _resolve_crafter_lookup()))
	return _resolve_crafter_lookup() if lookup.is_empty() else lookup


func _resolve_output_destination_lookup() -> String:
	var lookup := str(_params.get("output_destination_entity_id", _resolve_crafter_lookup()))
	return _resolve_crafter_lookup() if lookup.is_empty() else lookup


func _resolve_entity(lookup: String) -> EntityInstance:
	return BACKEND_HELPERS.resolve_entity_lookup(lookup)


func _read_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for item in values:
		var text := str(item)
		if text.is_empty():
			continue
		result.append(text)
	return result


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}


func _is_number(value: Variant) -> bool:
	if value is int or value is float:
		return true
	return false
