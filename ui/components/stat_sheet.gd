## StatSheet view model contract:
## {
##   "title": String,
##   "groups": Dictionary[String, Array[Dictionary]]
## }
extends PanelContainer

class_name StatSheet

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _groups_container: VBoxContainer = $MarginContainer/VBoxContainer/GroupsContainer
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
	_title_label.text = str(view_model.get("title", "Stats"))
	_clear_groups()

	var groups_value: Variant = view_model.get("groups", {})
	if not groups_value is Dictionary:
		_add_empty_state("No stats available.")
		return
	var groups: Dictionary = groups_value
	if groups.is_empty():
		_add_empty_state("No stats available.")
		return

	var group_names: Array = groups.keys()
	group_names.sort()
	for group_name_value in group_names:
		var group_name := str(group_name_value)
		var lines_value: Variant = groups.get(group_name_value, [])
		if not lines_value is Array:
			continue
		var lines: Array = lines_value
		if lines.is_empty():
			continue
		_groups_container.add_child(_build_group_section(group_name, lines))

	if _groups_container.get_child_count() == 0:
		_add_empty_state("No stats available.")


func _clear_groups() -> void:
	for child in _groups_container.get_children():
		_groups_container.remove_child(child)
		child.queue_free()


func _build_group_section(group_name: String, lines: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	var header_text := BACKEND_HELPERS.humanize_id(group_name)
	header.text = header_text if not header_text.is_empty() else "Stats"
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	for line_value in lines:
		if not line_value is Dictionary:
			continue
		var line: Dictionary = line_value
		var stat_bar_value: Variant = STAT_BAR_SCENE.instantiate()
		if not stat_bar_value is Control:
			continue
		var stat_bar: Control = stat_bar_value
		section.add_child(stat_bar)
		stat_bar.call("render", line)

	return section


func _add_empty_state(message: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	_groups_container.add_child(label)
