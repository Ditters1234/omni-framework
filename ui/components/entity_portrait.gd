## EntityPortrait view model contract:
## {
##   "display_name": String,
##   "emblem_path": String,
##   "emblem_id": String,
##   "description": String,
##   "faction_badge": Variant,
##   "stat_preview": Array[Dictionary]
## }
extends PanelContainer

class_name EntityPortrait

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")

@onready var _emblem_rect: TextureRect = $MarginContainer/VBoxContainer/TopRow/EmblemRect
@onready var _display_name_label: Label = $MarginContainer/VBoxContainer/TopRow/IdentityColumn/DisplayNameLabel
@onready var _faction_badge: Control = $MarginContainer/VBoxContainer/TopRow/IdentityColumn/FactionBadge
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

	_render_faction_badge(view_model.get("faction_badge", null))

	_apply_emblem(
		str(view_model.get("emblem_id", "")),
		str(view_model.get("emblem_path", ""))
	)
	_render_stat_preview(view_model.get("stat_preview", []))


func _apply_emblem(emblem_id: String, emblem_path: String) -> void:
	var resolved_path := BACKEND_HELPERS.resolve_visual_resource_path(emblem_id)
	if resolved_path.is_empty():
		resolved_path = emblem_path
	if resolved_path.is_empty() or not ResourceLoader.exists(resolved_path):
		_emblem_rect.texture = null
		_emblem_rect.visible = false
		return
	_emblem_rect.texture = load(resolved_path) as Texture2D
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


func _render_faction_badge(faction_badge_value: Variant) -> void:
	var faction_badge_view_model := _normalize_faction_badge(faction_badge_value)
	_faction_badge.visible = not faction_badge_view_model.is_empty()
	if faction_badge_view_model.is_empty():
		return
	_faction_badge.call("render", faction_badge_view_model)


func _normalize_faction_badge(faction_badge_value: Variant) -> Dictionary:
	if faction_badge_value is Dictionary:
		var faction_badge: Dictionary = faction_badge_value
		var badge_copy := faction_badge.duplicate(true)
		if badge_copy.has("label") and not badge_copy.has("faction_id"):
			badge_copy["faction_id"] = str(badge_copy.get("label", ""))
		return badge_copy
	if faction_badge_value == null:
		return {}
	var faction_badge_text := str(faction_badge_value)
	if faction_badge_text.is_empty():
		return {}
	return {
		"faction_id": faction_badge_text,
	}
