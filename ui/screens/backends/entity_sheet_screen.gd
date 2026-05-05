extends Control

const ENTITY_SHEET_BACKEND := preload("res://ui/screens/backends/entity_sheet_backend.gd")
const ACTIVE_QUEST_LOG_BACKEND := preload("res://ui/screens/backends/active_quest_log_backend.gd")
const ASSEMBLY_COMMIT_SERVICE := preload("res://systems/assembly_commit_service.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const STAT_SHEET_SCENE := preload("res://ui/components/stat_sheet.tscn")
const FACTION_BADGE_SCENE := preload("res://ui/components/faction_badge.tscn")
const QUEST_CARD_SCENE := preload("res://ui/components/quest_card.tscn")
const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const INVENTORY_CATEGORY_ALL := "__all"
const INVENTORY_SORT_NAME := "name"
const INVENTORY_SORT_COUNT := "count"
const INVENTORY_SORT_CATEGORY := "category"
const INVENTORY_STACKED_WIDTH := 760.0

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _tab_container: TabContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer
@onready var _portrait_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Overview/OverviewBox/PortraitHost
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Overview/OverviewBox/SummaryLabel
@onready var _overview_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Overview/OverviewBox/OverviewRows
@onready var _stat_sheet_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Stats/StatsBox/StatSheetHost
@onready var _currency_section_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Equipment/EquipmentBox/CurrencySectionLabel
@onready var _currency_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Equipment/EquipmentBox/CurrencyRows
@onready var _equipped_section_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Equipment/EquipmentBox/EquippedSectionLabel
@onready var _equipped_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Equipment/EquipmentBox/EquippedRows
@onready var _inventory_content: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent
@onready var _inventory_search_edit: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryToolbar/InventorySearchEdit
@onready var _inventory_category_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryToolbar/InventoryCategoryButton
@onready var _inventory_sort_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryToolbar/InventorySortButton
@onready var _inventory_include_equipped_toggle: CheckButton = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryToolbar/InventoryIncludeEquippedToggle
@onready var _inventory_summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventorySummaryLabel
@onready var _inventory_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryListPanel/InventoryRows
@onready var _inventory_detail_title: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/InventoryDetailTitle
@onready var _inventory_detail_meta: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/InventoryDetailMeta
@onready var _inventory_detail_description: Label = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/InventoryDetailDescription
@onready var _inventory_detail_stats: RichTextLabel = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/InventoryDetailStats
@onready var _open_assembly_button: Button = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/OpenAssemblyButton
@onready var _equip_item_button: Button = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/EquipItemButton
@onready var _use_item_button: Button = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/UseItemButton
@onready var _discard_item_button: Button = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Inventory/InventoryBox/InventoryContent/InventoryDetailPanel/DetailBox/DiscardItemButton
@onready var _quest_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Quests/QuestRows
@onready var _reputation_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Reputation/ReputationRows
@onready var _progress_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Progress/ProgressRows
@onready var _activity_rows: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TabContainer/Activity/ActivityRows
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _refresh_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/RefreshButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: RefCounted = ENTITY_SHEET_BACKEND.new()
var _quest_backend: RefCounted = ACTIVE_QUEST_LOG_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _portrait: Control = null
var _stat_sheet: Control = null
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false
var _ai_lore_template_id: String = ""
var _last_tab_index: int = 0
var _inventory_search_text: String = ""
var _inventory_category_filter: String = INVENTORY_CATEGORY_ALL
var _inventory_sort_mode: String = INVENTORY_SORT_NAME
var _inventory_include_equipped: bool = false
var _selected_inventory_key: String = ""
var _last_inventory_rows: Array[Dictionary] = []


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()
	call_deferred("_normalize_for_shell_host")


func _ready() -> void:
	_connect_runtime_signals()
	_connect_inventory_controls()
	_sync_responsive_layout()
	_initialize_backend()
	_refresh_state()
	call_deferred("_normalize_for_shell_host")
	call_deferred("_grab_default_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_responsive_layout()


func _normalize_for_shell_host() -> void:
	if not _opened_from_gameplay_shell:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2.ZERO


func _sync_responsive_layout() -> void:
	if not is_node_ready() or _inventory_content == null:
		return
	_inventory_content.columns = 1 if size.x < INVENTORY_STACKED_WIDTH else 2


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)


func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_quest_backend.initialize({
		"screen_title": "Quests",
		"screen_description": "Review active and completed quests.",
		"include_completed": true,
		"empty_label": "No active or completed quests.",
	})
	_pending_params = {}
	_backend_initialized = true


func _refresh_state() -> void:
	if not _backend_initialized:
		return
	_last_tab_index = _tab_container.current_tab if _tab_container != null else 0
	var view_model: Dictionary = _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_last_view_model["opened_from_gameplay_shell"] = _opened_from_gameplay_shell

	_title_label.text = str(view_model.get("title", "Character Menu"))
	_description_label.text = str(view_model.get("description", "Review character state, inventory, quests, and progress."))
	_summary_label.text = str(view_model.get("summary_text", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = "Back" if _opened_from_gameplay_shell else str(view_model.get("cancel_label", "Back"))

	_render_portrait(_read_dictionary(view_model.get("portrait", {})))
	_render_stat_sheet(_read_dictionary(view_model.get("stat_sheet", {})))
	_render_overview_section(view_model)
	_render_currency_section(view_model)
	_render_equipped_section(view_model)
	_render_inventory_section(view_model)
	_render_quest_section()
	_render_reputation_section(view_model)
	_render_progress_section()
	_render_activity_section()

	var ai_lore := str(view_model.get("ai_lore", "")).strip_edges()
	_ai_lore_template_id = str(view_model.get("ai_lore_template_id", ""))
	if not ai_lore.is_empty():
		_description_label.text = "%s\nLore: %s" % [str(view_model.get("description", "")), ai_lore]

	if _tab_container != null:
		_tab_container.current_tab = clampi(_last_tab_index, 0, max(_tab_container.get_tab_count() - 1, 0))


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


func _render_overview_section(view_model: Dictionary) -> void:
	var visible_inventory_rows := _build_visible_inventory_rows(view_model)
	var rows: Array[Dictionary] = []
	rows.append({"display_name": "Currency Balances", "stat_summary": str(view_model.get("currency_rows", []).size())})
	rows.append({"display_name": "Equipped Parts", "stat_summary": str(view_model.get("equipped_rows", []).size())})
	rows.append({"display_name": "Loose Inventory Items", "stat_summary": str(_count_inventory_row_instances(visible_inventory_rows))})
	rows.append({"display_name": "Loose Inventory Stacks", "stat_summary": str(visible_inventory_rows.size())})
	rows.append({"display_name": "Active Quests", "stat_summary": str(GameState.active_quests.size())})
	rows.append({"display_name": "Completed Quests", "stat_summary": str(GameState.completed_quests.size())})
	rows.append({"display_name": "Unlocked Achievements", "stat_summary": str(GameState.unlocked_achievements.size())})
	rows.append({"display_name": "Discovered Recipes", "stat_summary": str(GameState.discovered_recipes.size())})
	_render_text_rows(_overview_rows, rows, "No character summary is available.", "")


func _render_currency_section(view_model: Dictionary) -> void:
	var show_currencies := bool(view_model.get("show_currencies", true))
	_currency_section_label.visible = show_currencies
	_currency_rows.visible = show_currencies
	if not show_currencies:
		return
	var rows := _read_dictionary_array(view_model.get("currency_rows", []))
	_render_text_rows(_currency_rows, rows, str(view_model.get("currency_empty_label", "No currencies are recorded.")), "")


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
	_inventory_summary_label.visible = show_inventory
	_inventory_rows.visible = show_inventory
	if not show_inventory:
		return
	var rows := _build_inventory_browser_rows(view_model)
	_sync_inventory_filter_options(rows)
	var filtered_rows := _filter_inventory_rows(rows)
	_sort_inventory_rows(filtered_rows)
	_sync_selected_inventory_key(filtered_rows)
	_last_inventory_rows = _duplicate_dictionary_array(filtered_rows)
	var loose_rows := _build_visible_inventory_rows(view_model)
	_inventory_summary_label.text = "%s carried items, %s loose stacks, %s shown." % [
		str(_count_inventory_row_instances(loose_rows)),
		str(loose_rows.size()),
		str(filtered_rows.size()),
	]
	var empty_label := str(view_model.get("inventory_empty_label", "Inventory is empty."))
	var overflow_count := int(view_model.get("inventory_overflow_count", 0))
	_render_inventory_rows(filtered_rows, empty_label)
	_render_inventory_detail(filtered_rows)
	if overflow_count > 0:
		_add_wrapped_label(_inventory_rows, "+ %s more inventory stacks may be hidden by the inventory display limit." % str(overflow_count))


func _build_inventory_browser_rows(view_model: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in _build_visible_inventory_rows(view_model):
		var inventory_row := row.duplicate(true)
		inventory_row["source_label"] = "Inventory"
		inventory_row["selection_key"] = "inventory:%s" % str(inventory_row.get("template_id", ""))
		inventory_row["is_equipped"] = false
		rows.append(inventory_row)
	if not _inventory_include_equipped:
		return rows
	for row in _read_dictionary_array(view_model.get("equipped_rows", [])):
		var equipped_row := row.duplicate(true)
		var slot_label := str(equipped_row.get("slot_label", "Equipped"))
		var instance_id := str(equipped_row.get("instance_id", ""))
		equipped_row["source_label"] = "Equipped: %s" % slot_label
		equipped_row["selection_key"] = "equipped:%s:%s" % [slot_label, instance_id]
		equipped_row["is_equipped"] = true
		rows.append(equipped_row)
	return rows


func _sync_inventory_filter_options(rows: Array[Dictionary]) -> void:
	if _inventory_sort_button.item_count == 0:
		_inventory_sort_button.add_item("Name", 0)
		_inventory_sort_button.set_item_metadata(0, INVENTORY_SORT_NAME)
		_inventory_sort_button.add_item("Count", 1)
		_inventory_sort_button.set_item_metadata(1, INVENTORY_SORT_COUNT)
		_inventory_sort_button.add_item("Category", 2)
		_inventory_sort_button.set_item_metadata(2, INVENTORY_SORT_CATEGORY)
		_inventory_sort_button.select(0)

	var categories: Array[String] = []
	for row in rows:
		for tag in _read_string_array(row.get("tags", [])):
			if categories.has(tag):
				continue
			categories.append(tag)
	categories.sort()

	var selected_category := _inventory_category_filter
	_inventory_category_button.clear()
	_inventory_category_button.add_item("All categories", 0)
	_inventory_category_button.set_item_metadata(0, INVENTORY_CATEGORY_ALL)
	var selected_index := 0
	for index in range(categories.size()):
		var category := categories[index]
		var item_index := index + 1
		_inventory_category_button.add_item(_humanize_id(category), item_index)
		_inventory_category_button.set_item_metadata(item_index, category)
		if category == selected_category:
			selected_index = item_index
	if selected_category != INVENTORY_CATEGORY_ALL and selected_index == 0:
		_inventory_category_filter = INVENTORY_CATEGORY_ALL
	_inventory_category_button.select(selected_index)


func _filter_inventory_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var query := _inventory_search_text.strip_edges().to_lower()
	for row in rows:
		if _inventory_category_filter != INVENTORY_CATEGORY_ALL:
			var tags := _read_string_array(row.get("tags", []))
			if not tags.has(_inventory_category_filter):
				continue
		if not query.is_empty() and not _inventory_row_matches_query(row, query):
			continue
		results.append(row.duplicate(true))
	return results


func _inventory_row_matches_query(row: Dictionary, query: String) -> bool:
	var haystack := "%s %s %s %s" % [
		str(row.get("display_name", "")),
		str(row.get("template_id", "")),
		str(row.get("description", "")),
		", ".join(_read_string_array(row.get("tags", []))),
	]
	return haystack.to_lower().contains(query)


func _sort_inventory_rows(rows: Array[Dictionary]) -> void:
	match _inventory_sort_mode:
		INVENTORY_SORT_COUNT:
			rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var count_a := int(a.get("count", 1))
				var count_b := int(b.get("count", 1))
				if count_a != count_b:
					return count_a > count_b
				return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
			)
		INVENTORY_SORT_CATEGORY:
			rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var category_a := _read_primary_category(a)
				var category_b := _read_primary_category(b)
				if category_a != category_b:
					return category_a.naturalnocasecmp_to(category_b) < 0
				return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
			)
		_:
			rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
			)


func _sync_selected_inventory_key(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		_selected_inventory_key = ""
		return
	for row in rows:
		if str(row.get("selection_key", "")) == _selected_inventory_key:
			return
	_selected_inventory_key = str(rows[0].get("selection_key", ""))


func _render_inventory_rows(rows: Array[Dictionary], empty_label: String) -> void:
	_clear_children(_inventory_rows)
	if rows.is_empty():
		_add_wrapped_label(_inventory_rows, empty_label)
		return
	for row in rows:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _build_inventory_button_text(row)
		var selection_key := str(row.get("selection_key", ""))
		button.disabled = selection_key == _selected_inventory_key
		button.pressed.connect(_on_inventory_row_selected.bind(selection_key))
		_inventory_rows.add_child(button)


func _build_inventory_button_text(row: Dictionary) -> String:
	var title := str(row.get("display_name", row.get("template_id", "Unknown")))
	var count := int(row.get("count", 1))
	if count > 1:
		title = "%s x%s" % [title, str(count)]
	var source_label := str(row.get("source_label", "Inventory"))
	var category := _read_primary_category(row)
	if category.is_empty():
		return "%s  |  %s" % [title, source_label]
	return "%s  |  %s  |  %s" % [title, _humanize_id(category), source_label]


func _render_inventory_detail(rows: Array[Dictionary]) -> void:
	var selected := _find_inventory_row(rows, _selected_inventory_key)
	if selected.is_empty():
		_inventory_detail_title.text = "Select an item"
		_inventory_detail_meta.text = ""
		_inventory_detail_description.text = "Use search, category, and sort controls to inspect carried parts."
		_inventory_detail_stats.text = ""
		_open_assembly_button.visible = _is_player_sheet()
		_equip_item_button.visible = false
		_use_item_button.text = "Use Item"
		_use_item_button.visible = false
		_discard_item_button.visible = false
		return
	var display_name := str(selected.get("display_name", selected.get("template_id", "Unknown")))
	var count := int(selected.get("count", 1))
	_inventory_detail_title.text = "%s%s" % [display_name, " x%s" % str(count) if count > 1 else ""]
	_inventory_detail_meta.text = _build_inventory_detail_meta(selected)
	_inventory_detail_description.text = str(selected.get("description", "No description is available."))
	_inventory_detail_stats.text = _build_inventory_detail_stats(selected)
	_open_assembly_button.visible = _is_player_sheet()
	var recommended_slot_label := str(selected.get("recommended_slot_label", ""))
	_equip_item_button.text = "Equip" if recommended_slot_label.is_empty() else "Equip to %s" % recommended_slot_label
	_equip_item_button.visible = _is_player_sheet()
	_equip_item_button.disabled = not _can_equip_inventory_row(selected)
	var template := _read_dictionary(selected.get("template", {}))
	_use_item_button.text = str(template.get("use_label", "Use Item"))
	_use_item_button.visible = _is_player_sheet()
	_use_item_button.disabled = not _can_use_inventory_row(selected)
	_discard_item_button.visible = _is_player_sheet()
	_discard_item_button.disabled = not _can_discard_inventory_row(selected)


func _find_inventory_row(rows: Array[Dictionary], selection_key: String) -> Dictionary:
	for row in rows:
		if str(row.get("selection_key", "")) == selection_key:
			return row.duplicate(true)
	return {}


func _build_inventory_detail_meta(row: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(row.get("source_label", "Inventory")))
	var template_id := str(row.get("template_id", ""))
	if not template_id.is_empty():
		parts.append(template_id)
	var tags := _read_string_array(row.get("tags", []))
	if not tags.is_empty():
		var labels: Array[String] = []
		for tag in tags:
			labels.append(_humanize_id(tag))
		parts.append(", ".join(labels))
	return " | ".join(parts)


func _build_inventory_detail_stats(row: Dictionary) -> String:
	var lines: Array[String] = []
	var stat_summary := str(row.get("stat_summary", ""))
	if not stat_summary.is_empty():
		lines.append(stat_summary)
	var custom_summary := str(row.get("custom_summary", ""))
	if not custom_summary.is_empty():
		lines.append(custom_summary)
	var instance_ids := _read_string_array(row.get("instance_ids", []))
	if not instance_ids.is_empty():
		lines.append("Instances: %s" % ", ".join(instance_ids))
	if lines.is_empty():
		lines.append("No stat modifiers.")
	return "\n".join(lines)


func _read_primary_category(row: Dictionary) -> String:
	var tags := _read_string_array(row.get("tags", []))
	if tags.is_empty():
		return ""
	return tags[0]


func _render_quest_section() -> void:
	_clear_children(_quest_rows)
	var quest_model: Dictionary = _quest_backend.build_view_model()
	var cards := _read_dictionary_array(quest_model.get("cards", []))
	if cards.is_empty():
		_add_wrapped_label(_quest_rows, str(quest_model.get("empty_label", "No active or completed quests.")))
		return
	for card in cards:
		var card_value: Variant = QUEST_CARD_SCENE.instantiate()
		if card_value is Control:
			var quest_card: Control = card_value
			_quest_rows.add_child(quest_card)
			quest_card.call("render", card)


func _render_reputation_section(view_model: Dictionary) -> void:
	_clear_children(_reputation_rows)
	var rows := _read_dictionary_array(view_model.get("reputation_rows", []))
	if rows.is_empty():
		_add_wrapped_label(_reputation_rows, str(view_model.get("reputation_empty_label", "No faction standing is recorded.")))
		return
	for row in rows:
		var badge_value: Variant = FACTION_BADGE_SCENE.instantiate()
		if badge_value is Control:
			var badge: Control = badge_value
			_reputation_rows.add_child(badge)
			badge.call("render", _read_dictionary(row.get("badge", {})))
		var description := str(row.get("description", ""))
		if not description.is_empty():
			_add_wrapped_label(_reputation_rows, description)


func _render_progress_section() -> void:
	var rows: Array[Dictionary] = []
	rows.append({"display_name": "Unlocked Achievements", "stat_summary": _join_string_array(GameState.unlocked_achievements, "None")})
	rows.append({"display_name": "Discovered Recipes", "stat_summary": _join_string_array(GameState.discovered_recipes, "None")})
	rows.append({"display_name": "Completed Quests", "stat_summary": _join_string_array(GameState.completed_quests, "None")})
	rows.append({"display_name": "Completed Tasks", "stat_summary": _join_string_array(GameState.completed_task_templates, "None")})
	var flag_keys: Array = GameState.flags.keys()
	flag_keys.sort()
	rows.append({"display_name": "Flags", "stat_summary": _join_variant_array(flag_keys, "None")})
	_render_text_rows(_progress_rows, rows, "No progress has been recorded.", "")


func _render_activity_section() -> void:
	_clear_children(_activity_rows)
	if GameState.event_history.is_empty():
		_add_wrapped_label(_activity_rows, "No event history has been recorded.")
		return
	var start_index := maxi(GameState.event_history.size() - 25, 0)
	for index in range(GameState.event_history.size() - 1, start_index - 1, -1):
		var event_value: Variant = GameState.event_history[index]
		if not event_value is Dictionary:
			continue
		var event_entry: Dictionary = event_value
		var event_type := str(event_entry.get("event_type", "event"))
		var day := int(event_entry.get("day", 0))
		var tick := int(event_entry.get("tick", 0))
		var payload_text := _summarize_payload(_read_dictionary(event_entry.get("payload", {})))
		var text := "Day %s, Tick %s — %s" % [str(day), str(tick), event_type]
		if not payload_text.is_empty():
			text = "%s\n%s" % [text, payload_text]
		_add_wrapped_label(_activity_rows, text)


func _build_visible_inventory_rows(view_model: Dictionary) -> Array[Dictionary]:
	# EntitySheetBackend reports inventory and equipped rows independently.
	# Some runtime flows can leave equipped PartInstances mirrored in inventory;
	# the character menu should present those only in Equipment, not Inventory.
	var rows := _read_dictionary_array(view_model.get("inventory_rows", []))
	var equipped_counts := _build_equipped_template_counts(view_model)
	var equipped_instance_ids := _build_equipped_instance_id_lookup(view_model)
	if equipped_counts.is_empty():
		return rows

	var visible_rows: Array[Dictionary] = []
	for row in rows:
		var template_id := str(row.get("template_id", ""))
		var row_count := maxi(int(row.get("count", 1)), 1)
		var instance_ids := _read_string_array(row.get("instance_ids", []))
		var visible_instance_ids: Array[String] = []
		for instance_id in instance_ids:
			if equipped_instance_ids.has(instance_id):
				continue
			visible_instance_ids.append(instance_id)
		if not instance_ids.is_empty():
			row_count = visible_instance_ids.size()
		var equipped_count := int(equipped_counts.get(template_id, 0))
		if template_id.is_empty() or equipped_count <= 0:
			var unchanged_row := row.duplicate(true)
			if not instance_ids.is_empty():
				unchanged_row["count"] = row_count
				unchanged_row["instance_ids"] = visible_instance_ids
			if row_count > 0:
				visible_rows.append(unchanged_row)
			continue

		var remaining_count := row_count if not instance_ids.is_empty() else row_count - equipped_count
		equipped_counts[template_id] = maxi(equipped_count - row_count, 0)
		if remaining_count <= 0:
			continue

		var adjusted_row := row.duplicate(true)
		adjusted_row["count"] = remaining_count
		if not instance_ids.is_empty():
			adjusted_row["instance_ids"] = visible_instance_ids
		visible_rows.append(adjusted_row)
	return visible_rows


func _build_equipped_template_counts(view_model: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for row in _read_dictionary_array(view_model.get("equipped_rows", [])):
		var template_id := str(row.get("template_id", ""))
		if template_id.is_empty():
			continue
		counts[template_id] = int(counts.get(template_id, 0)) + 1
	return counts


func _build_equipped_instance_id_lookup(view_model: Dictionary) -> Dictionary:
	var instance_ids: Dictionary = {}
	for row in _read_dictionary_array(view_model.get("equipped_rows", [])):
		var instance_id := str(row.get("instance_id", ""))
		if not instance_id.is_empty():
			instance_ids[instance_id] = true
		for nested_instance_id in _read_string_array(row.get("instance_ids", [])):
			instance_ids[nested_instance_id] = true
	return instance_ids


func _count_inventory_row_instances(rows: Array[Dictionary]) -> int:
	var total := 0
	for row in rows:
		total += maxi(int(row.get("count", 1)), 1)
	return total


func _render_text_rows(host: VBoxContainer, rows: Array[Dictionary], empty_label: String, prefix_field: String) -> void:
	_clear_children(host)
	if rows.is_empty():
		_add_wrapped_label(host, empty_label)
		return
	for row in rows:
		_add_wrapped_label(host, _build_row_text(row, prefix_field))


func _build_row_text(row: Dictionary, prefix_field: String) -> String:
	var display_name := str(row.get("display_name", row.get("template_id", "Unknown")))
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


func _add_wrapped_label(host: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(label)
	return label


func _clear_children(host: Node) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


func _on_refresh_button_pressed() -> void:
	_refresh_state()


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


func _read_string_array(value: Variant) -> Array[String]:
	var results: Array[String] = []
	if not value is Array:
		return results
	var values: Array = value
	for item in values:
		var text := str(item)
		if text.is_empty():
			continue
		results.append(text)
	return results


func _humanize_id(value: String) -> String:
	var text := value
	if text.contains(":"):
		text = text.get_slice(":", text.get_slice_count(":") - 1)
	text = text.replace("_", " ").replace("-", " ").strip_edges()
	if text.is_empty():
		return ""
	var words := text.split(" ", false)
	var labels: Array[String] = []
	for word in words:
		labels.append(word.capitalize())
	return " ".join(labels)


func _is_player_sheet() -> bool:
	var player := GameState.player as EntityInstance
	if player == null:
		return false
	var target_entity_id := str(_last_view_model.get("target_entity_id", ""))
	return target_entity_id == player.entity_id or target_entity_id == "player"


func _connect_runtime_signals() -> void:
	if GameEvents == null:
		return
	var event_callback := Callable(self, "_on_event_narrated")
	if GameEvents.has_signal("event_narrated") and not GameEvents.is_connected("event_narrated", event_callback):
		GameEvents.event_narrated.connect(_on_event_narrated)
	var tick_callback := Callable(self, "_on_runtime_state_changed")
	if GameEvents.has_signal("tick_advanced") and not GameEvents.is_connected("tick_advanced", tick_callback):
		GameEvents.tick_advanced.connect(_on_runtime_state_changed)
	var day_callback := Callable(self, "_on_runtime_state_changed")
	if GameEvents.has_signal("day_advanced") and not GameEvents.is_connected("day_advanced", day_callback):
		GameEvents.day_advanced.connect(_on_runtime_state_changed)
	var location_callback := Callable(self, "_on_location_changed")
	if GameEvents.has_signal("location_changed") and not GameEvents.is_connected("location_changed", location_callback):
		GameEvents.location_changed.connect(_on_location_changed)


func _connect_inventory_controls() -> void:
	if _inventory_search_edit != null:
		var search_callback := Callable(self, "_on_inventory_search_changed")
		if not _inventory_search_edit.is_connected("text_changed", search_callback):
			_inventory_search_edit.text_changed.connect(_on_inventory_search_changed)
	if _inventory_category_button != null:
		var category_callback := Callable(self, "_on_inventory_category_selected")
		if not _inventory_category_button.is_connected("item_selected", category_callback):
			_inventory_category_button.item_selected.connect(_on_inventory_category_selected)
	if _inventory_sort_button != null:
		var sort_callback := Callable(self, "_on_inventory_sort_selected")
		if not _inventory_sort_button.is_connected("item_selected", sort_callback):
			_inventory_sort_button.item_selected.connect(_on_inventory_sort_selected)
	if _inventory_include_equipped_toggle != null:
		var include_callback := Callable(self, "_on_inventory_include_equipped_toggled")
		if not _inventory_include_equipped_toggle.is_connected("toggled", include_callback):
			_inventory_include_equipped_toggle.toggled.connect(_on_inventory_include_equipped_toggled)
	if _open_assembly_button != null:
		var assembly_callback := Callable(self, "_on_open_assembly_button_pressed")
		if not _open_assembly_button.is_connected("pressed", assembly_callback):
			_open_assembly_button.pressed.connect(_on_open_assembly_button_pressed)
	if _equip_item_button != null:
		var equip_callback := Callable(self, "_on_equip_item_button_pressed")
		if not _equip_item_button.is_connected("pressed", equip_callback):
			_equip_item_button.pressed.connect(_on_equip_item_button_pressed)
	if _use_item_button != null:
		var use_callback := Callable(self, "_on_use_item_button_pressed")
		if not _use_item_button.is_connected("pressed", use_callback):
			_use_item_button.pressed.connect(_on_use_item_button_pressed)
	if _discard_item_button != null:
		var discard_callback := Callable(self, "_on_discard_item_button_pressed")
		if not _discard_item_button.is_connected("pressed", discard_callback):
			_discard_item_button.pressed.connect(_on_discard_item_button_pressed)


func _on_inventory_search_changed(new_text: String) -> void:
	_inventory_search_text = new_text
	_refresh_state()


func _on_inventory_category_selected(index: int) -> void:
	var metadata: Variant = _inventory_category_button.get_item_metadata(index)
	_inventory_category_filter = str(metadata) if metadata != null else INVENTORY_CATEGORY_ALL
	_refresh_state()


func _on_inventory_sort_selected(index: int) -> void:
	var metadata: Variant = _inventory_sort_button.get_item_metadata(index)
	_inventory_sort_mode = str(metadata) if metadata != null else INVENTORY_SORT_NAME
	_refresh_state()


func _on_inventory_include_equipped_toggled(button_pressed: bool) -> void:
	_inventory_include_equipped = button_pressed
	_refresh_state()


func _on_inventory_row_selected(selection_key: String) -> void:
	_selected_inventory_key = selection_key
	_refresh_state()


func _on_open_assembly_button_pressed() -> void:
	var params := {
		"target_entity_id": "player",
		"budget_entity_id": "player",
		"budget_currency_id": "credits",
		"option_source_entity_id": "player",
		"screen_title": "Manage Equipment",
		"screen_description": "Equip carried parts and preview stat changes before committing.",
		"cancel_label": "Back",
		"confirm_label": "Apply",
		"pop_on_confirm": true,
	}
	if _opened_from_gameplay_shell and UIRouter.open_in_gameplay_shell(SCREEN_ASSEMBLY_EDITOR, params):
		return
	UIRouter.push(SCREEN_ASSEMBLY_EDITOR, params)


func _on_equip_item_button_pressed() -> void:
	var row := _find_inventory_row(_last_inventory_rows, _selected_inventory_key)
	if row.is_empty() or not _can_equip_inventory_row(row):
		return
	var player := GameState.player as EntityInstance
	if player == null:
		return
	var instance_id := _read_first_instance_id(row)
	var slot_id := str(row.get("recommended_slot_id", ""))
	if instance_id.is_empty() or slot_id.is_empty():
		return
	var previous_entity := player
	var committed_entity := player.duplicate_instance()
	if not committed_entity.equip(instance_id, slot_id):
		return
	ASSEMBLY_COMMIT_SERVICE.commit_entity(previous_entity, committed_entity, "player")
	var display_name := str(row.get("display_name", "item"))
	var slot_label := str(row.get("recommended_slot_label", slot_id))
	GameEvents.ui_notification_requested.emit("Equipped %s to %s." % [display_name, slot_label], "info")
	_refresh_state()


func _on_use_item_button_pressed() -> void:
	var row := _find_inventory_row(_last_inventory_rows, _selected_inventory_key)
	if row.is_empty() or not _can_use_inventory_row(row):
		return
	var display_name := str(row.get("display_name", "item"))
	var template := _read_dictionary(row.get("template", {}))
	var instance_id := _read_first_instance_id(row)
	var actions := _read_use_actions(template)
	for action in actions:
		var action_payload := action.duplicate(true)
		if not action_payload.has("entity_id"):
			action_payload["entity_id"] = "player"
		if not action_payload.has("instance_id") and not instance_id.is_empty():
			action_payload["instance_id"] = instance_id
		if not action_payload.has("template_id"):
			action_payload["template_id"] = str(row.get("template_id", ""))
		if not action_payload.has("part_id"):
			action_payload["part_id"] = str(row.get("template_id", ""))
		ActionDispatcher.dispatch(action_payload)
	if bool(template.get("consume_on_use", false)):
		ActionDispatcher.dispatch({
			"type": "consume",
			"entity_id": "player",
			"instance_id": instance_id,
			"template_id": str(row.get("template_id", "")),
		})
	GameEvents.ui_notification_requested.emit("Used %s." % display_name, "info")
	_refresh_state()


func _on_discard_item_button_pressed() -> void:
	var row := _find_inventory_row(_last_inventory_rows, _selected_inventory_key)
	if row.is_empty() or not _can_discard_inventory_row(row):
		return
	var display_name := str(row.get("display_name", "item"))
	var instance_id := _read_first_instance_id(row)
	ActionDispatcher.dispatch({
		"type": "consume",
		"entity_id": "player",
		"instance_id": instance_id,
		"template_id": str(row.get("template_id", "")),
	})
	GameEvents.ui_notification_requested.emit("Discarded %s." % display_name, "info")
	_refresh_state()


func _can_use_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	var template := _read_dictionary(row.get("template", {}))
	return not _read_use_actions(template).is_empty()


func _can_equip_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	if _read_first_instance_id(row).is_empty():
		return false
	return bool(row.get("can_equip", false)) and not str(row.get("recommended_slot_id", "")).is_empty()


func _can_discard_inventory_row(row: Dictionary) -> bool:
	if bool(row.get("is_equipped", false)):
		return false
	return not _read_first_instance_id(row).is_empty() or not str(row.get("template_id", "")).is_empty()


func _read_use_actions(template: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var actions_value: Variant = template.get("use_actions", [])
	if actions_value is Array:
		var raw_actions: Array = actions_value
		for action_value in raw_actions:
			if action_value is Dictionary:
				var action: Dictionary = action_value
				actions.append(action.duplicate(true))
	var action_payload_value: Variant = template.get("use_action_payload", {})
	if action_payload_value is Dictionary:
		var action_payload: Dictionary = action_payload_value
		if not action_payload.is_empty():
			actions.append(action_payload.duplicate(true))
	return actions


func _read_first_instance_id(row: Dictionary) -> String:
	var instance_ids := _read_string_array(row.get("instance_ids", []))
	if not instance_ids.is_empty():
		return instance_ids[0]
	return str(row.get("instance_id", ""))


func _duplicate_dictionary_array(rows: Array[Dictionary]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for row in rows:
		results.append(row.duplicate(true))
	return results


func _on_runtime_state_changed(_value: Variant = null) -> void:
	_refresh_state()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh_state()


func _on_event_narrated(source_signal: String, source_key: String, _narration: String) -> void:
	if source_signal != "entity_lore":
		return
	if _ai_lore_template_id.is_empty() or source_key != _ai_lore_template_id:
		return
	_refresh_state()


func _join_string_array(values: Array, empty_label: String) -> String:
	if values.is_empty():
		return empty_label
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)


func _join_variant_array(values: Array, empty_label: String) -> String:
	if values.is_empty():
		return empty_label
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)


func _summarize_payload(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var keys: Array = payload.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		var key := str(key_value)
		parts.append("%s: %s" % [key, str(payload.get(key_value, ""))])
	return ", ".join(parts)


func _grab_default_focus() -> void:
	# GUT treats Godot focus warnings as test failures. Only grab focus on
	# controls that are explicitly focusable and inside the active tree.
	if _refresh_button != null and is_instance_valid(_refresh_button):
		_refresh_button.focus_mode = Control.FOCUS_ALL
		if _refresh_button.is_inside_tree() and _refresh_button.is_visible_in_tree() and not _refresh_button.disabled:
			_refresh_button.grab_focus()
			return
	if _back_button != null and is_instance_valid(_back_button):
		_back_button.focus_mode = Control.FOCUS_ALL
		if _back_button.is_inside_tree() and _back_button.is_visible_in_tree() and not _back_button.disabled:
			_back_button.grab_focus()
