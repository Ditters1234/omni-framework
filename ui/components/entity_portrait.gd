## EntityPortrait view model contract:
## {
##   "display_name": String,
##   "emblem_path": String,
##   "description": String,
##   "faction_badge": Variant,
##   "stat_preview": Array[Dictionary]
## }
extends PanelContainer

class_name EntityPortrait

const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")

@onready var _emblem_rect: TextureRect = $MarginContainer/VBoxContainer/TopRow/EmblemRect
@onready var _display_name_label: Label = $MarginContainer/VBoxContainer/TopRow/IdentityColumn/DisplayNameLabel
@onready var _faction_badge_label: Label = $MarginContainer/VBoxContainer/TopRow/IdentityColumn/FactionBadgeLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _stat_preview_container: VBoxContainer = $MarginContainer/VBoxContainer/StatPreviewContainer
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
	_display_name_label.text = str(view_model.get("display_name", "Unknown Entity"))
	_description_label.text = str(view_model.get("description", ""))

	var faction_badge := _format_faction_badge(view_model.get("faction_badge", null))
	_faction_badge_label.visible = not faction_badge.is_empty()
	_faction_badge_label.text = faction_badge

	_apply_emblem(str(view_model.get("emblem_path", "")))
	_render_stat_preview(view_model.get("stat_preview", []))


func _apply_emblem(emblem_path: String) -> void:
	if emblem_path.is_empty() or not ResourceLoader.exists(emblem_path):
		_emblem_rect.texture = null
		_emblem_rect.visible = false
		return
	_emblem_rect.texture = load(emblem_path) as Texture2D
	_emblem_rect.visible = _emblem_rect.texture != null


func _render_stat_preview(stat_preview_value: Variant) -> void:
	for child in _stat_preview_container.get_children():
		_stat_preview_container.remove_child(child)
		child.queue_free()

	if not stat_preview_value is Array:
		return
	var stat_preview: Array = stat_preview_value
	for stat_line_value in stat_preview:
		if not stat_line_value is Dictionary:
			continue
		var stat_line: Dictionary = stat_line_value
		var stat_bar_value: Variant = STAT_BAR_SCENE.instantiate()
		if not stat_bar_value is Control:
			continue
		var stat_bar: Control = stat_bar_value
		_stat_preview_container.add_child(stat_bar)
		stat_bar.call("render", stat_line)


func _format_faction_badge(faction_badge_value: Variant) -> String:
	if faction_badge_value is Dictionary:
		var faction_badge: Dictionary = faction_badge_value
		var label := str(faction_badge.get("label", faction_badge.get("faction_id", "")))
		var reputation_text := str(faction_badge.get("reputation_tier", ""))
		if label.is_empty():
			return ""
		if reputation_text.is_empty():
			return label
		return "%s • %s" % [label, reputation_text]
	if faction_badge_value == null:
		return ""
	return str(faction_badge_value)
