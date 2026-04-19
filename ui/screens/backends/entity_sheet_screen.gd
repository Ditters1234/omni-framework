extends Control

const ENTITY_SHEET_BACKEND := preload("res://ui/screens/backends/entity_sheet_backend.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const STAT_SHEET_SCENE := preload("res://ui/components/stat_sheet.tscn")
const FACTION_BADGE_SCENE := preload("res://ui/components/faction_badge.tscn")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _portrait_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/Sidebar/PortraitHost
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/Sidebar/SummaryLabel
@onready var _stat_sheet_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/StatSheetHost
@onready var _equipped_section_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/EquippedSectionLabel
@onready var _equipped_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/EquippedRows
@onready var _inventory_section_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/InventorySectionLabel
@onready var _inventory_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/InventoryRows
@onready var _reputation_section_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/ReputationSectionLabel
@onready var _reputation_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailsScroll/DetailsContainer/ReputationRows
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = ENTITY_SHEET_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _portrait: Control = null
var _stat_sheet: Control = null
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false

func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()
	call_deferred("_normalize_for_shell_host")

func _ready() -> void:
	_initialize_backend()
	_refresh_state()
	call_deferred("_normalize_for_shell_host")

func _normalize_for_shell_host() -> void:
	if not _opened_from_gameplay_shell:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2.ZERO

func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)

func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_pending_params = {}
	_backend_initialized = true

func _refresh_state() -> void:
	if not _backend_initialized:
		return
	var view_model: Dictionary = _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_last_view_model["opened_from_gameplay_shell"] = _opened_from_gameplay_shell
	_title_label.text = str(view_model.get("title", "Entity Sheet"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary_text", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = "Back" if _opened_from_gameplay_shell else str(view_model.get("cancel_label", "Back"))
	_render_portrait(_read_dictionary(view_model.get("portrait", {})))
	_render_stat_sheet(_read_dictionary(view_model.get("stat_sheet", {})))
	_render_equipped_section(view_model)
	_render_inventory_section(view_model)
	_render_reputation_section(view_model)

func _render_portrait(view_model: Dictionary) -> void:
	if _portrait == null:
		var portrait_value: Variant = ENTITY_PORTRAIT_SCENE.instantiate()
		if portrait_value is Control:
			_portrait = portrait_value
			_portrait_host.add_child(_portrait)
	if _portrait != null:
		_portrait.call("render", view_model)

func _render_stat_sheet(view_model: Dictionary) -> void:
	if _stat_sheet == null:
		var stat_sheet_value: Variant = STAT_SHEET_SCENE.instantiate()
		if stat_sheet_value is Control:
			_stat_sheet = stat_sheet_value
			_stat_sheet_host.add_child(_stat_sheet)
	if _stat_sheet != null:
		_stat_sheet.call("render", view_model)

func _render_equipped_section(view_model: Dictionary) -> void:
	var show_equipped := bool(view_model.get("show_equipped", true))
	_equipped_section_label.visible = show_equipped
	_equipped_rows.visible = show_equipped
	if not show_equipped:
		return
	var rows := _read_dictionary_array(view_model.get("equipped_rows", []))
	_render_text_rows(_equipped_rows, rows, str(view_model.get("equipped_empty_label", "No parts are equipped.")), "slot_label")

func _render_inventory_section(view_model: Dictionary) -> void:
	var show_inventory := bool(view_model.get("show_inventory", true))
	_inventory_section_label.visible = show_inventory
	_inventory_rows.visible = show_inventory
	if not show_inventory:
		return
	var rows := _read_dictionary_array(view_model.get("inventory_rows", []))
	var empty_label := str(view_model.get("inventory_empty_label", "Inventory is empty."))
	var overflow_count := int(view_model.get("inventory_overflow_count", 0))
	_render_text_rows(_inventory_rows, rows, empty_label, "")
	if overflow_count > 0:
		var overflow_label := Label.new()
		overflow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		overflow_label.text = "+ %s more inventory stacks." % str(overflow_count)
		_inventory_rows.add_child(overflow_label)

func _render_reputation_section(view_model: Dictionary) -> void:
	var show_reputation := bool(view_model.get("show_reputation", true))
	_reputation_section_label.visible = show_reputation
	_reputation_rows.visible = show_reputation
	if not show_reputation:
		return
	for child in _reputation_rows.get_children():
		_reputation_rows.remove_child(child)
		child.queue_free()
	var rows := _read_dictionary_array(view_model.get("reputation_rows", []))
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = str(view_model.get("reputation_empty_label", "No faction standing is recorded."))
		_reputation_rows.add_child(empty_label)
		return
	for row in rows:
		var badge_value: Variant = FACTION_BADGE_SCENE.instantiate()
		if badge_value is Control:
			var badge: Control = badge_value
			_reputation_rows.add_child(badge)
			badge.call("render", _read_dictionary(row.get("badge", {})))
		var description := str(row.get("description", ""))
		if description.is_empty():
			continue
		var description_label := Label.new()
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.text = description
		_reputation_rows.add_child(description_label)

func _render_text_rows(host: VBoxContainer, rows: Array[Dictionary], empty_label: String, prefix_field: String) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = empty_label
		host.add_child(label)
		return
	for row in rows:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _build_row_text(row, prefix_field)
		host.add_child(label)

func _build_row_text(row: Dictionary, prefix_field: String) -> String:
	var display_name := str(row.get("display_name", row.get("template_id", "Unknown Part")))
	var count := int(row.get("count", 0))
	var title := display_name
	if count > 1:
		title = "%s x%s" % [display_name, str(count)]
	if not prefix_field.is_empty():
		var prefix := str(row.get(prefix_field, ""))
		if not prefix.is_empty():
			title = "%s: %s" % [prefix, title]
	var stat_summary := str(row.get("stat_summary", ""))
	if stat_summary.is_empty():
		return title
	return "%s\n%s" % [title, stat_summary]

func _on_back_button_pressed() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_surface()
		return
	UIRouter.pop()

func _read_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var values: Array = value
	for item in values:
		if item is Dictionary:
			var dictionary_item: Dictionary = item
			result.append(dictionary_item.duplicate(true))
	return result

func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
