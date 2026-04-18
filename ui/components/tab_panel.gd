## TabPanel view model contract:
## {
##   "tabs": Array[{id, label, content_scene}],
##   "selected_id": String
## }
extends PanelContainer

class_name TabPanel

@onready var _buttons_container: HFlowContainer = $MarginContainer/VBoxContainer/ButtonsContainer
@onready var _content_container: MarginContainer = $MarginContainer/VBoxContainer/ContentContainer

var _pending_view_model: Dictionary = {}
var _tabs: Array[Dictionary] = []
var _selected_tab_id: String = ""
var _active_content: Control = null


func _ready() -> void:
	if not _pending_view_model.is_empty():
		_apply_view_model(_pending_view_model)


func render(view_model: Dictionary) -> void:
	_pending_view_model = view_model
	if not is_node_ready():
		return
	_apply_view_model(_pending_view_model)


func select_tab(tab_id: String) -> void:
	if tab_id.is_empty():
		return
	for tab in _tabs:
		if str(tab.get("id", "")) != tab_id:
			continue
		_selected_tab_id = tab_id
		_refresh_buttons()
		_render_tab_content(tab)
		return


func _apply_view_model(view_model: Dictionary) -> void:
	_tabs.clear()
	var tabs_value: Variant = view_model.get("tabs", [])
	if tabs_value is Array:
		var tabs: Array = tabs_value
		for tab_value in tabs:
			if not tab_value is Dictionary:
				continue
			var tab: Dictionary = tab_value
			_tabs.append(tab.duplicate(true))
	_selected_tab_id = str(view_model.get("selected_id", ""))
	if _selected_tab_id.is_empty() and not _tabs.is_empty():
		_selected_tab_id = str(_tabs[0].get("id", ""))
	_refresh_buttons()
	if _tabs.is_empty():
		_clear_content()
		var empty_label := Label.new()
		empty_label.text = "No tabs available."
		_content_container.add_child(empty_label)
		return
	select_tab(_selected_tab_id)


func _refresh_buttons() -> void:
	for child in _buttons_container.get_children():
		_buttons_container.remove_child(child)
		child.queue_free()
	for tab in _tabs:
		var button := Button.new()
		var tab_id := str(tab.get("id", ""))
		button.text = str(tab.get("label", tab_id))
		button.toggle_mode = true
		button.button_pressed = tab_id == _selected_tab_id
		button.disabled = tab_id == _selected_tab_id
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))
		_buttons_container.add_child(button)


func _on_tab_button_pressed(tab_id: String) -> void:
	select_tab(tab_id)


func _render_tab_content(tab: Dictionary) -> void:
	_clear_content()
	var content_scene_value: Variant = tab.get("content_scene", null)
	var content_control := _instantiate_content(content_scene_value)
	if content_control == null:
		var fallback_label := Label.new()
		fallback_label.text = "Tab content is unavailable."
		_content_container.add_child(fallback_label)
		return
	_active_content = content_control
	_content_container.add_child(_active_content)

	var content_view_model_value: Variant = tab.get("content_view_model", null)
	if content_view_model_value is Dictionary and _active_content.has_method("render"):
		var content_view_model: Dictionary = content_view_model_value
		_active_content.call("render", content_view_model)
	var content_params_value: Variant = tab.get("content_params", null)
	if content_params_value is Dictionary and _active_content.has_method("initialize"):
		var content_params: Dictionary = content_params_value
		_active_content.call("initialize", content_params)


func _instantiate_content(content_scene_value: Variant) -> Control:
	if content_scene_value is PackedScene:
		var packed_scene: PackedScene = content_scene_value
		var instance_value: Variant = packed_scene.instantiate()
		if instance_value is Control:
			return instance_value
		return null
	if content_scene_value is Control:
		return content_scene_value
	var content_scene_path := str(content_scene_value)
	if content_scene_path.is_empty() or not ResourceLoader.exists(content_scene_path):
		return null
	var loaded_scene := load(content_scene_path)
	if not loaded_scene is PackedScene:
		return null
	var scene: PackedScene = loaded_scene
	var scene_instance_value: Variant = scene.instantiate()
	if scene_instance_value is Control:
		return scene_instance_value
	return null


func _clear_content() -> void:
	for child in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
	_active_content = null
