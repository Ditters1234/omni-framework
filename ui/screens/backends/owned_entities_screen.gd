extends Control

const OWNED_ENTITIES_BACKEND := preload("res://ui/screens/backends/owned_entities_backend.gd")
const SCREEN_ENTITY_SHEET := "entity_sheet"
const SCREEN_ASSEMBLY_EDITOR := "assembly_editor"
const SCREEN_TASK_PROVIDER := "task_provider"
const STACKED_LAYOUT_WIDTH := 760.0

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _main_content: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _selected_title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/SelectedTitleLabel
@onready var _selected_description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/SelectedDescriptionLabel
@onready var _selected_meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/SelectedMetaLabel
@onready var _destination_button: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/DestinationRow/DestinationButton
@onready var _assign_location_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/DestinationRow/AssignLocationButton
@onready var _inspect_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/ActionRow/InspectButton
@onready var _manage_equipment_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/ActionRow/ManageEquipmentButton
@onready var _assign_contract_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/ActionRow/AssignContractButton
@onready var _recall_button: Button = $MarginContainer/PanelContainer/VBoxContainer/MainContent/DetailPanel/DetailBox/ActionRow/RecallButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniOwnedEntitiesBackend = OWNED_ENTITIES_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()


func _ready() -> void:
	_sync_responsive_layout()
	_initialize_backend()
	_refresh_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_responsive_layout()


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)


func _sync_responsive_layout() -> void:
	if not is_node_ready() or _main_content == null:
		return
	_main_content.columns = 1 if size.x < STACKED_LAYOUT_WIDTH else 2


func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_pending_params = {}
	_backend_initialized = true


func _refresh_state() -> void:
	if not _backend_initialized:
		return
	var view_model := _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_last_view_model["opened_from_gameplay_shell"] = _opened_from_gameplay_shell
	_title_label.text = str(view_model.get("title", "Owned Entities"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	var has_selection := bool(view_model.get("has_selection", false))
	_inspect_button.disabled = not has_selection
	_manage_equipment_button.disabled = not has_selection
	_assign_location_button.disabled = not has_selection
	_recall_button.disabled = not has_selection
	_assign_contract_button.disabled = not bool(view_model.get("can_assign_contract", false))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])), str(view_model.get("empty_label", "No owned entities are available.")))
	_render_selected(_read_dictionary(view_model.get("selected_entity", {})))
	_render_locations(_read_dictionary_array(view_model.get("locations", [])))


func _render_rows(rows: Array[Dictionary], empty_label: String) -> void:
	_clear_children(_rows_container)
	if rows.is_empty():
		_add_wrapped_label(_rows_container, empty_label)
		return
	for row in rows:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bool(row.get("selected", false))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _build_row_text(row)
		button.pressed.connect(_on_row_pressed.bind(str(row.get("entity_id", ""))))
		_rows_container.add_child(button)


func _render_selected(row: Dictionary) -> void:
	if row.is_empty():
		_selected_title_label.text = "Select an entity"
		_selected_description_label.text = ""
		_selected_meta_label.text = ""
		return
	_selected_title_label.text = str(row.get("display_name", row.get("entity_id", "Entity")))
	_selected_description_label.text = str(row.get("description", ""))
	_selected_meta_label.text = "Location: %s\nTask: %s\nStats: %s\nEquipment: %s equipped, %s inventory items" % [
		str(row.get("location_label", "Unknown")),
		str(row.get("active_task_text", "Idle")),
		str(row.get("stat_preview_text", "")),
		str(int(row.get("equipped_count", 0))),
		str(int(row.get("inventory_count", 0))),
	]


func _render_locations(rows: Array[Dictionary]) -> void:
	_destination_button.clear()
	var selected_index := 0
	if rows.is_empty():
		_destination_button.add_item("No destinations", 0)
		_destination_button.set_item_metadata(0, "")
		_destination_button.select(0)
		_assign_location_button.disabled = true
		return
	for index in range(rows.size()):
		var row := rows[index]
		var label := str(row.get("display_name", "Location"))
		if bool(row.get("is_current", false)):
			label = "%s (current)" % label
		elif int(row.get("route_cost", -1)) >= 0:
			label = "%s (%s ticks)" % [label, str(int(row.get("route_cost", 0)))]
		else:
			label = "%s (unreachable)" % label
		_destination_button.add_item(label, index)
		_destination_button.set_item_metadata(index, str(row.get("location_id", "")))
		_destination_button.set_item_disabled(index, not bool(row.get("enabled", false)))
		if index == 0 or bool(row.get("enabled", false)) and selected_index == 0:
			selected_index = index
	_destination_button.select(selected_index)


func _build_row_text(row: Dictionary) -> String:
	return "%s\n%s | %s" % [
		str(row.get("display_name", row.get("entity_id", "Entity"))),
		str(row.get("location_label", "Unknown")),
		str(row.get("active_task_text", "Idle")),
	]


func _on_row_pressed(entity_id: String) -> void:
	_backend.select_entity(entity_id)
	_refresh_state()


func _on_assign_location_button_pressed() -> void:
	var index := _destination_button.selected
	if index < 0:
		return
	var location_id := str(_destination_button.get_item_metadata(index))
	_backend.assign_selected_to_location(location_id)
	_refresh_state()


func _on_recall_button_pressed() -> void:
	_backend.recall_selected()
	_refresh_state()


func _on_inspect_button_pressed() -> void:
	var entity_id := _get_selected_entity_id()
	if entity_id.is_empty():
		return
	_open_screen(SCREEN_ENTITY_SHEET, {
		"target_entity_id": entity_id,
		"screen_title": "Entity Status",
	})


func _on_manage_equipment_button_pressed() -> void:
	var entity_id := _get_selected_entity_id()
	if entity_id.is_empty():
		return
	_open_screen(SCREEN_ASSEMBLY_EDITOR, {
		"target_entity_id": entity_id,
		"budget_entity_id": "player",
		"option_source_entity_id": entity_id,
		"screen_title": "Manage Owned Entity",
		"screen_description": "Equip carried parts and preview stat changes before committing.",
		"cancel_label": "Back",
		"confirm_label": "Apply",
		"pop_on_confirm": true,
	})


func _on_assign_contract_button_pressed() -> void:
	var entity_id := _get_selected_entity_id()
	var faction_id := str(_last_view_model.get("assignment_faction_id", ""))
	if entity_id.is_empty() or faction_id.is_empty():
		return
	var params := {
		"faction_id": faction_id,
		"assignee_entity_id": entity_id,
		"screen_title": "Assign Contract",
		"screen_description": "Pick a contract for the selected owned entity.",
		"cancel_label": "Back",
	}
	var provider_entity_id := str(_last_view_model.get("assignment_provider_entity_id", ""))
	if not provider_entity_id.is_empty():
		params["provider_entity_id"] = provider_entity_id
	_open_screen(SCREEN_TASK_PROVIDER, params)


func _on_refresh_button_pressed() -> void:
	_refresh_state()


func _on_back_button_pressed() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()


func _open_screen(screen_id: String, params: Dictionary) -> void:
	if _opened_from_gameplay_shell and UIRouter.open_in_gameplay_shell(screen_id, params):
		return
	UIRouter.push(screen_id, params)


func _get_selected_entity_id() -> String:
	var row := _read_dictionary(_last_view_model.get("selected_entity", {}))
	return str(row.get("entity_id", ""))


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
