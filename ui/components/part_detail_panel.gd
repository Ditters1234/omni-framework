extends PanelContainer

class_name PartDetailPanel

const ROOT_FALLBACK := "res://mods/base/assets/images/fallbacks/root_fallback.png"
const SEMANTIC_THEME_TYPE := "OmniSemantic"
const FALLBACK_POSITIVE_COLOR := Color("#8fd18f")
const FALLBACK_NEGATIVE_COLOR := Color("#e07a7a")

## Emitted when the user changes a custom field value.
## Connect to this from whatever presenter wires the assembly editor.
signal custom_field_changed(slot_id: String, field_id: String, value: String)

@onready var _slot_label: Label = $MarginContainer/VBoxContainer/SlotLabel
@onready var _texture_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _price_label: Label = $MarginContainer/VBoxContainer/PriceLabel
@onready var _stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel
@onready var _custom_fields_container: VBoxContainer = $MarginContainer/VBoxContainer/CustomFieldsContainer

var _pending_view_model: Dictionary = {}
var _current_slot_id: String = ""
## Tracks which field definitions are currently rendered so we can skip
## rebuilding the controls when the same set of fields is shown again.
var _rendered_field_ids: Array[String] = []


func _ready() -> void:
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model.duplicate(true)
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func _apply_view_model(view_model: Dictionary) -> void:
	var slot_label := str(view_model.get("slot_label", "Selection"))
	var current_name := str(view_model.get("current_name", "<empty>"))
	var preview_name := str(view_model.get("preview_name", current_name))
	var description := str(view_model.get("description", "No part selected."))
	var price_text := str(view_model.get("price_text", "Price: 0"))
	var stats_lines_data: Variant = view_model.get("stats_lines", [])
	var affordable := bool(view_model.get("affordable", true))
	var part_template_data: Variant = view_model.get("part_template", {})
	var default_sprite_paths_data: Variant = view_model.get("default_sprite_paths", {})
	var default_sprite_paths: Dictionary = {}
	if default_sprite_paths_data is Dictionary:
		default_sprite_paths = default_sprite_paths_data

	_current_slot_id = str(view_model.get("slot_id", ""))

	_slot_label.text = slot_label
	_title_label.text = preview_name
	_subtitle_label.text = "Current: %s" % current_name
	_description_label.text = description
	_price_label.text = price_text
	_price_label.modulate = _get_semantic_color("positive", FALLBACK_POSITIVE_COLOR) if affordable else _get_semantic_color("negative", FALLBACK_NEGATIVE_COLOR)
	var sprite_path := _resolve_sprite_path(part_template_data, default_sprite_paths)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_texture_rect.texture = load(sprite_path) as Texture2D
	else:
		_texture_rect.texture = null
	_stats_label.text = "\n".join(_normalize_lines(stats_lines_data))

	# --- Custom fields ---
	var field_defs_data: Variant = view_model.get("custom_field_definitions", [])
	var custom_values_data: Variant = view_model.get("custom_values", {})
	var field_defs: Array = field_defs_data if field_defs_data is Array else []
	var custom_values: Dictionary = custom_values_data if custom_values_data is Dictionary else {}
	_rebuild_custom_fields(field_defs, custom_values)


# ---------------------------------------------------------------------------
# Custom field UI
# ---------------------------------------------------------------------------

func _rebuild_custom_fields(field_defs: Array, custom_values: Dictionary) -> void:
	if _custom_fields_container == null:
		return

	# Build list of incoming field IDs to compare with what's rendered.
	var incoming_ids: Array[String] = []
	for def_value in field_defs:
		if def_value is Dictionary:
			var def: Dictionary = def_value
			incoming_ids.append(str(def.get("id", "")))

	# If the field set hasn't changed, just update values in place.
	if incoming_ids == _rendered_field_ids:
		_update_custom_field_values(custom_values)
		return

	# Full rebuild.
	for child in _custom_fields_container.get_children():
		child.queue_free()
	_rendered_field_ids.clear()

	if field_defs.is_empty():
		_custom_fields_container.visible = false
		return

	_custom_fields_container.visible = true

	var header := Label.new()
	header.text = "Custom Fields"
	header.add_theme_font_size_override("font_size", 13)
	_custom_fields_container.add_child(header)

	for def_value in field_defs:
		if not def_value is Dictionary:
			continue
		var def: Dictionary = def_value
		var field_id := str(def.get("id", ""))
		if field_id.is_empty():
			continue
		var label_text := str(def.get("label", field_id))
		var current_value := str(custom_values.get(field_id, def.get("default_value", "")))
		var options_data: Variant = def.get("options", null)

		var row := HBoxContainer.new()
		row.set_meta("_field_id", field_id)

		var label := Label.new()
		label.text = "%s:" % label_text
		label.custom_minimum_size.x = 90
		row.add_child(label)

		if options_data is Array and not (options_data as Array).is_empty():
			var options: Array = options_data
			var option_btn := OptionButton.new()
			option_btn.set_meta("_field_id", field_id)
			option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var selected_index: int = 0
			for i in range(options.size()):
				var opt_text := str(options[i])
				option_btn.add_item(opt_text)
				if opt_text == current_value:
					selected_index = i
			option_btn.selected = selected_index
			option_btn.item_selected.connect(_on_option_selected.bind(field_id, option_btn))
			row.add_child(option_btn)
		else:
			var line_edit := LineEdit.new()
			line_edit.set_meta("_field_id", field_id)
			line_edit.text = current_value
			line_edit.placeholder_text = label_text
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text_submitted.connect(_on_line_edit_submitted.bind(field_id))
			line_edit.focus_exited.connect(_on_line_edit_focus_exited.bind(field_id, line_edit))
			row.add_child(line_edit)

		_custom_fields_container.add_child(row)
		_rendered_field_ids.append(field_id)


func _update_custom_field_values(custom_values: Dictionary) -> void:
	if _custom_fields_container == null:
		return
	for child in _custom_fields_container.get_children():
		if not child is HBoxContainer:
			continue
		var field_id := str(child.get_meta("_field_id", ""))
		if field_id.is_empty():
			continue
		var value := str(custom_values.get(field_id, ""))
		for sub in child.get_children():
			if sub is OptionButton:
				var option_btn: OptionButton = sub
				for i in range(option_btn.item_count):
					if option_btn.get_item_text(i) == value:
						if option_btn.selected != i:
							option_btn.selected = i
						break
			elif sub is LineEdit:
				var line_edit: LineEdit = sub
				if not line_edit.has_focus() and line_edit.text != value:
					line_edit.text = value


func _on_option_selected(_index: int, field_id: String, option_btn: OptionButton) -> void:
	var value := option_btn.get_item_text(option_btn.selected)
	custom_field_changed.emit(_current_slot_id, field_id, value)


func _on_line_edit_submitted(new_text: String, field_id: String) -> void:
	custom_field_changed.emit(_current_slot_id, field_id, new_text)


func _on_line_edit_focus_exited(field_id: String, line_edit: LineEdit) -> void:
	custom_field_changed.emit(_current_slot_id, field_id, line_edit.text)


# ---------------------------------------------------------------------------
# Helpers (unchanged)
# ---------------------------------------------------------------------------

func _normalize_lines(lines: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if not lines is Array:
		result.append("No stat changes.")
		return result
	for line in lines:
		result.append(str(line))
	if result.is_empty():
		result.append("No stat changes.")
	return result


func _resolve_sprite_path(part_template: Variant, default_sprite_paths: Dictionary) -> String:
	if not part_template is Dictionary:
		return ROOT_FALLBACK
	var template: Dictionary = part_template
	var explicit_sprite := str(template.get("sprite", ""))
	if not explicit_sprite.is_empty() and ResourceLoader.exists(explicit_sprite):
		return explicit_sprite

	var tags := _read_tags(template)
	var configured_sprite := _resolve_configured_default_sprite(tags, default_sprite_paths)
	if not configured_sprite.is_empty():
		return configured_sprite
	if "head" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_head.png"
	if "hair" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_hat.png"
	if "torso" in tags or "body_core" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_torso.png"
	if "arm" in tags or "wing" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_arm.png"
	if "leg" in tags or "tail" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_leg.png"
	if "hand" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_hand.png"
	if "foot" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_foot.png"
	if "nose_cone" in tags or "fin" in tags or "thruster" in tags or "vehicle_core" in tags or "rocket_core" in tags:
		return "res://mods/base/assets/images/fallbacks/generic_cyberware.png"

	return ROOT_FALLBACK


func _read_tags(part_template: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var tags_data: Variant = part_template.get("tags", [])
	if not tags_data is Array:
		return tags
	var raw_tags: Array = tags_data
	for raw_tag in raw_tags:
		var tag_text := str(raw_tag)
		if not tag_text.is_empty():
			tags.append(tag_text)
	return tags


func _resolve_configured_default_sprite(tags: Array[String], configured_sprites: Dictionary) -> String:
	for tag in tags:
		if not configured_sprites.has(tag):
			continue
		var sprite_path := str(configured_sprites.get(tag, ""))
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			return sprite_path
	var fallback_path := str(configured_sprites.get("default", ""))
	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		return fallback_path
	return ""


func _get_semantic_color(color_name: String, fallback: Color) -> Color:
	if has_theme_color(color_name, SEMANTIC_THEME_TYPE):
		return get_theme_color(color_name, SEMANTIC_THEME_TYPE)
	return fallback
