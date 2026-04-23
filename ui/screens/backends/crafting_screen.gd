extends Control

const CRAFTING_BACKEND := preload("res://ui/screens/backends/crafting_backend.gd")
const RECIPE_CARD_SCENE := preload("res://ui/components/recipe_card.tscn")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _summary_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SummaryLabel
@onready var _rows_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/RowsScroll/RowsContainer
@onready var _card_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/SidebarScroll/Sidebar/CardHost
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniCraftingBackend = CRAFTING_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _recipe_card: Control = null
var _last_view_model: Dictionary = {}
var _opened_from_gameplay_shell: bool = false


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()


func _ready() -> void:
	_initialize_backend()
	_refresh_state()


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
	_title_label.text = str(view_model.get("title", "Crafting"))
	_description_label.text = str(view_model.get("description", ""))
	_summary_label.text = str(view_model.get("summary", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_confirm_button.text = str(view_model.get("confirm_label", "Craft Selected"))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_render_rows(_read_dictionary_array(view_model.get("rows", [])))
	_render_recipe_card(_read_dictionary(view_model.get("selected_recipe_card", {})))


func _render_rows(rows: Array[Dictionary]) -> void:
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = str(_last_view_model.get("empty_label", "No recipes available."))
		_rows_container.add_child(empty_label)
		return
	for row in rows:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = bool(row.get("selected", false))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [
			str(row.get("display_name", "Unnamed Recipe")),
			str(row.get("status_text", "")),
		]
		button.pressed.connect(_on_row_pressed.bind(str(row.get("recipe_id", ""))))
		_rows_container.add_child(button)


func _render_recipe_card(view_model: Dictionary) -> void:
	if _recipe_card == null:
		var recipe_card_value: Variant = RECIPE_CARD_SCENE.instantiate()
		if recipe_card_value is Control:
			_recipe_card = recipe_card_value
			_card_host.add_child(_recipe_card)
	if _recipe_card != null:
		_recipe_card.call("render", view_model)


func _on_row_pressed(recipe_id: String) -> void:
	_backend.select_row(recipe_id)
	_refresh_state()


func _on_confirm_button_pressed() -> void:
	var action: Dictionary = _backend.confirm()
	_execute_navigation_action(action)
	_refresh_state()


func _on_back_button_pressed() -> void:
	_navigate_back()


func _navigate_back() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()


func _execute_navigation_action(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	var screen_id := str(action.get("screen_id", ""))
	var params := _read_dictionary(action.get("params", {}))
	if _opened_from_gameplay_shell:
		match action_type:
			"pop":
				UIRouter.close_gameplay_shell_screen()
			"replace_all", "push":
				if not screen_id.is_empty() and UIRouter.open_screen_in_gameplay_shell(screen_id, params):
					return
				if action_type == "replace_all":
					UIRouter.replace_all(screen_id, params)
				else:
					UIRouter.push(screen_id, params)
			_:
				pass
		return
	match action_type:
		"pop":
			UIRouter.pop()
		"replace_all":
			UIRouter.replace_all(screen_id, params)
		"push":
			UIRouter.push(screen_id, params)
		_:
			pass


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
