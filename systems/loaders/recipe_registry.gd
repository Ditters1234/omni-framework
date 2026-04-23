## RecipeRegistry -- Loads recipes.json into DataManager.recipes.
## Key field: "recipe_id" (namespaced, e.g. "base:diagnostic_grip")
extends RefCounted

class_name RecipeRegistry


## Parses recipes.json content and adds entries to DataManager.recipes.
static func load_additions(data: Array) -> void:
	for recipe in data:
		if not recipe is Dictionary:
			continue
		var recipe_id := str(recipe.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		DataManager.recipes[recipe_id] = recipe.duplicate(true)


## Applies patch operations to existing recipe entries.
static func apply_patch(patch: Array) -> void:
	for patch_entry in patch:
		if not patch_entry is Dictionary:
			continue
		var target := str(patch_entry.get("target", ""))
		if not DataManager.recipes.has(target):
			continue
		var entry: Dictionary = DataManager.recipes[target].duplicate(true)
		DataManager._apply_set_operations(entry, patch_entry)
		DataManager._append_array_field(entry, "tags", patch_entry.get("add_tags", []))
		DataManager._remove_array_values(entry, "tags", patch_entry.get("remove_tags", []))
		DataManager.recipes[target] = entry


## Returns a recipe template by id, or empty dict.
static func get_recipe(recipe_id: String) -> Dictionary:
	var recipe_value: Variant = DataManager.recipes.get(recipe_id, {})
	if recipe_value is Dictionary:
		var recipe: Dictionary = recipe_value
		return recipe.duplicate(true)
	return {}


## Returns all recipe templates.
static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_value in DataManager.recipes.values():
		if recipe_value is Dictionary:
			var recipe: Dictionary = recipe_value
			result.append(recipe.duplicate(true))
	return result


## Returns true if a recipe template with the given id exists.
static func has_recipe(recipe_id: String) -> bool:
	return DataManager.recipes.has(recipe_id)
