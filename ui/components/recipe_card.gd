## RecipeCard view model contract:
## {
##   "recipe": Dictionary,
##   "input_status": Array[Dictionary],
##   "output_template": Variant
## }
extends PanelContainer

class_name RecipeCard

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")
const FALLBACK_MUTED_TEXT_COLOR := Color("#9aa8bf")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _inputs_container: VBoxContainer = $MarginContainer/VBoxContainer/InputsContainer
@onready var _output_label: Label = $MarginContainer/VBoxContainer/OutputLabel
@onready var _meta_label: Label = $MarginContainer/VBoxContainer/MetaLabel

var _pending_view_model: Dictionary = {}


func _ready() -> void:
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model.duplicate(true)
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	var recipe_value: Variant = view_model.get("recipe", {})
	var recipe: Dictionary = {}
	if recipe_value is Dictionary:
		recipe = recipe_value
	_title_label.text = str(recipe.get("display_name", "Unnamed Recipe"))
	_description_label.text = str(recipe.get("description", ""))
	_render_inputs(view_model.get("input_status", []))
	_output_label.text = _build_output_label(recipe, view_model.get("output_template", null))
	_meta_label.text = _build_meta_label(recipe)
	_meta_label.visible = not _meta_label.text.is_empty()


func _render_inputs(input_status_value: Variant) -> void:
	for child in _inputs_container.get_children():
		_inputs_container.remove_child(child)
		child.queue_free()
	if not input_status_value is Array:
		_add_input_label("No inputs listed.", false, true)
		return
	var input_status: Array = input_status_value
	if input_status.is_empty():
		_add_input_label("No inputs listed.", false, true)
		return
	for input_value in input_status:
		if not input_value is Dictionary:
			continue
		var input_status_entry: Dictionary = input_value
		var template_id := str(input_status_entry.get("template_id", "ingredient"))
		var required := int(input_status_entry.get("required", 0))
		var have := int(input_status_entry.get("have", 0))
		var satisfied := bool(input_status_entry.get("satisfied", false))
		var label := "%s: %d / %d" % [BACKEND_HELPERS.humanize_id(template_id), have, required]
		_add_input_label(label, satisfied, false)


func _add_input_label(text: String, satisfied: bool, muted: bool) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	if muted:
		label.modulate = _get_semantic_color("muted_text", FALLBACK_MUTED_TEXT_COLOR)
	elif satisfied:
		label.modulate = _get_semantic_color("positive", FALLBACK_POSITIVE_COLOR)
	else:
		label.modulate = _get_semantic_color("negative", FALLBACK_NEGATIVE_COLOR)
	_inputs_container.add_child(label)


func _build_output_label(recipe: Dictionary, output_template_value: Variant) -> String:
	var output_count := int(recipe.get("output_count", 1))
	if output_template_value is Dictionary:
		var output_template: Dictionary = output_template_value
		var display_name := str(output_template.get("display_name", output_template.get("id", "Output")))
		return "Output: %s x%d" % [display_name, output_count]
	var output_template_text := str(output_template_value)
	if output_template_text.is_empty():
		output_template_text = str(recipe.get("output_template_id", "Output"))
	return "Output: %s x%d" % [BACKEND_HELPERS.humanize_id(output_template_text), output_count]


func _build_meta_label(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var craft_time_ticks := int(recipe.get("craft_time_ticks", 0))
	if craft_time_ticks > 0:
		parts.append("Time: %d ticks" % craft_time_ticks)
	var stations_value: Variant = recipe.get("required_stations", [])
	if stations_value is Array:
		var stations: Array = stations_value
		if not stations.is_empty():
			var station_names: Array[String] = []
			for station_value in stations:
				station_names.append(BACKEND_HELPERS.humanize_id(str(station_value)))
			parts.append("Stations: %s" % ", ".join(station_names))
	var required_stats_value: Variant = recipe.get("required_stats", {})
	if required_stats_value is Dictionary:
		var required_stats: Dictionary = required_stats_value
		if not required_stats.is_empty():
			var stat_parts: Array[String] = []
			var stat_keys: Array = required_stats.keys()
			stat_keys.sort()
			for stat_key_value in stat_keys:
				stat_parts.append("%s %s" % [BACKEND_HELPERS.humanize_id(str(stat_key_value)), str(required_stats.get(stat_key_value, 0))])
			parts.append("Requires: %s" % ", ".join(stat_parts))
	return "\n".join(parts)


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
