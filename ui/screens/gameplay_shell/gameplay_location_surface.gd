## GameplayLocationSurface — shell-owned action surface for the active location.
extends Control

class_name GameplayLocationSurface

const UI_ROUTE_CATALOG := preload("res://ui/ui_route_catalog.gd")
const GLOBAL_SHELL_SURFACE_IDS := {
	"entity_sheet": true,
	"quest_log": true,
	"faction_rep": true,
	"achievement_list": true,
	"event_log": true,
	"world_map": true,
}

@onready var _interactions_container: VBoxContainer = $MarginContainer/VBoxContainer/MainColumns/InteractionsPanel/MarginContainer/VBoxContainer/InteractionsScroll/InteractionsContainer
@onready var _entities_container: VBoxContainer = $MarginContainer/VBoxContainer/MainColumns/EntitiesPanel/MarginContainer/VBoxContainer/EntitiesScroll/EntitiesContainer
@onready var _travel_container: VBoxContainer = $MarginContainer/VBoxContainer/MainColumns/TravelPanel/MarginContainer/VBoxContainer/TravelScroll/TravelContainer
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _location_id: String = ""
var _location_template: Dictionary = {}
var _last_view_model: Dictionary = {}


func initialize(params: Dictionary = {}) -> void:
	_location_id = str(params.get("location_id", ""))
	if _location_id.is_empty():
		_location_id = GameState.current_location_id
	_load_location()


func _ready() -> void:
	GameEvents.location_changed.connect(_on_location_changed)
	if _location_id.is_empty():
		_location_id = GameState.current_location_id
	_load_location()


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)


func _load_location() -> void:
	if _location_id.is_empty():
		_location_id = GameState.current_location_id
	if _location_id.is_empty():
		_show_error("No active location.")
		return
	_location_template = LocationGraph.get_location(_location_id)
	if _location_template.is_empty():
		_show_error("Location '%s' not found." % _location_id)
		return
	_render_location_actions()


func _render_location_actions() -> void:
	_clear_container(_interactions_container)
	_clear_container(_entities_container)
	_clear_container(_travel_container)

	var interaction_entries: Array[Dictionary] = []
	var screens: Variant = _location_template.get("screens", [])
	if screens is Array and not screens.is_empty():
		for screen_entry in screens:
			if not screen_entry is Dictionary:
				continue
			var entry: Dictionary = (screen_entry as Dictionary).duplicate(true)
			if _is_global_shell_surface(entry):
				continue
			interaction_entries.append(entry)
			_add_interaction_button(entry)
	if interaction_entries.is_empty():
		_add_empty_label(_interactions_container, "No local interactions are available here right now.")

	var entity_entries := _render_entity_presence()
	var travel_entries := _render_travel_actions()
	_status_label.text = ""
	_last_view_model = {
		"surface_id": "location_surface",
		"location_id": _location_id,
		"interactions": interaction_entries,
		"entities": entity_entries,
		"travel": travel_entries,
		"status_text": "",
	}


func _is_global_shell_surface(screen_entry: Dictionary) -> bool:
	var backend_class: String = str(screen_entry.get("backend_class", ""))
	var screen_id: String = UI_ROUTE_CATALOG.get_screen_id_for_backend(backend_class)
	return GLOBAL_SHELL_SURFACE_IDS.has(screen_id)


func _add_interaction_button(screen_entry: Dictionary) -> void:
	var display_name: String = str(screen_entry.get("display_name", "Unnamed Interaction"))
	var description: String = str(screen_entry.get("description", ""))
	var backend_class: String = str(screen_entry.get("backend_class", ""))
	var screen_id: String = UI_ROUTE_CATALOG.get_screen_id_for_backend(backend_class)

	var button := Button.new()
	button.text = display_name
	button.tooltip_text = description
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 48)

	if screen_id.is_empty():
		button.disabled = true
		button.tooltip_text += "\n[backend '%s' not mapped]" % backend_class
	elif not UIRouter.is_registered(screen_id):
		button.disabled = true
		button.tooltip_text += "\n[screen '%s' not yet built]" % screen_id
	else:
		var push_params: Dictionary = screen_entry.duplicate(true)
		push_params["opened_from_gameplay_shell"] = true
		button.pressed.connect(_on_screen_button_pressed.bind(screen_id, push_params))

	_interactions_container.add_child(button)


func _render_travel_actions() -> Array[Dictionary]:
	var rendered_connections: Array[Dictionary] = []
	var connections: Dictionary = LocationGraph.get_connections(_location_id)
	if connections.is_empty():
		_add_empty_label(_travel_container, "No travel connections are available from this location.")
		return rendered_connections

	for dest_id_value in connections.keys():
		var dest_id: String = str(dest_id_value)
		var travel_cost: int = int(connections[dest_id_value])
		var dest_template: Dictionary = LocationGraph.get_location(dest_id)
		var dest_name: String = str(dest_template.get("display_name", dest_id))

		rendered_connections.append({
			"destination_id": dest_id,
			"destination_name": dest_name,
			"travel_cost": travel_cost,
		})

		var button := Button.new()
		button.text = "%s (%d)" % [dest_name, travel_cost]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_travel_button_pressed.bind(dest_id, travel_cost))
		_travel_container.add_child(button)
	return rendered_connections


func _render_entity_presence() -> Array[Dictionary]:
	var rendered_entities: Array[Dictionary] = []
	var entity_ids := _get_present_entity_ids()
	for entity_id in entity_ids:
		var entity_template := _get_entity_template_for_presence(entity_id)
		if entity_template.is_empty():
			continue
		var display_name := str(entity_template.get("display_name", entity_id))
		var description := str(entity_template.get("description", ""))
		var interactions := _read_entity_interactions(entity_template)
		rendered_entities.append({
			"entity_id": entity_id,
			"display_name": display_name,
			"description": description,
			"interactions": interactions,
		})
		_add_entity_presence(entity_id, display_name, description, interactions)
	if rendered_entities.is_empty():
		_add_empty_label(_entities_container, "No other entities are visible here right now.")
	return rendered_entities

func _get_present_entity_ids() -> Array[String]:
	var entity_ids: Array[String] = []

	# static list
	var listed_entities_value: Variant = _location_template.get("entities_present", [])
	if listed_entities_value is Array:
		for entity_id_value in listed_entities_value:
			var id := str(entity_id_value)
			if not entity_ids.has(id) and id != "player":
				entity_ids.append(id)

	# runtime instances (NEW SOURCE OF TRUTH)
	var runtime_entities: Array[EntityInstance] = GameState.get_entity_instances_at_location(_location_id)
	for entity in runtime_entities:
		if not entity_ids.has(entity.entity_id):
			entity_ids.append(entity.entity_id)

	return entity_ids


func _append_present_entity_id(entity_ids: Array[String], entity_id: String) -> void:
	if entity_id.is_empty() or entity_id == "player" or entity_ids.has(entity_id):
		return
	entity_ids.append(entity_id)


func _get_entity_template_for_presence(entity_id: String) -> Dictionary:
	var runtime_entity := GameState.get_entity_instance(entity_id)
	if runtime_entity != null:
		var runtime_template := runtime_entity.get_template()
		if not runtime_template.is_empty():
			return runtime_template
	return DataManager.get_entity(entity_id)


func _read_entity_interactions(entity_template: Dictionary) -> Array[Dictionary]:
	var interactions: Array[Dictionary] = []
	var interactions_value: Variant = entity_template.get("interactions", [])
	if not interactions_value is Array:
		return interactions
	var raw_interactions: Array = interactions_value
	for interaction_value in raw_interactions:
		if interaction_value is Dictionary:
			var interaction: Dictionary = interaction_value
			interactions.append(interaction.duplicate(true))
	return interactions


func _add_entity_presence(entity_id: String, display_name: String, description: String, interactions: Array[Dictionary]) -> void:
	var name_label := Label.new()
	name_label.text = display_name
	name_label.tooltip_text = description
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entities_container.add_child(name_label)

	if not description.is_empty():
		var description_label := Label.new()
		description_label.text = description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entities_container.add_child(description_label)

	if interactions.is_empty():
		_add_empty_label(_entities_container, "No interactions are available for %s." % display_name)
		return

	for interaction in interactions:
		_add_entity_interaction_button(entity_id, interaction)


func _add_entity_interaction_button(entity_id: String, interaction: Dictionary) -> void:
	var label := str(interaction.get("label", interaction.get("display_name", "Interact")))
	var description := str(interaction.get("description", ""))
	var backend_class := str(interaction.get("backend_class", ""))
	var screen_id := UI_ROUTE_CATALOG.get_screen_id_for_backend(backend_class)

	var button := Button.new()
	button.text = label
	button.tooltip_text = description
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 40)

	if screen_id.is_empty():
		button.disabled = true
		button.tooltip_text += "\n[backend '%s' not mapped]" % backend_class
	elif not UIRouter.is_registered(screen_id):
		button.disabled = true
		button.tooltip_text += "\n[screen '%s' not yet built]" % screen_id
	else:
		var push_params := interaction.duplicate(true)
		push_params["source_entity_id"] = entity_id
		var speaker_entity_value: Variant = push_params.get("speaker_entity_id", "")
		if backend_class == "DialogueBackend" and str(speaker_entity_value).is_empty():
			push_params["speaker_entity_id"] = entity_id
		push_params["opened_from_gameplay_shell"] = true
		button.pressed.connect(_on_screen_button_pressed.bind(screen_id, push_params))

	_entities_container.add_child(button)


func _add_empty_label(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	container.add_child(label)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _show_error(message: String) -> void:
	_clear_container(_interactions_container)
	_clear_container(_entities_container)
	_clear_container(_travel_container)
	_add_empty_label(_interactions_container, message)
	_status_label.text = message
	_last_view_model = {
		"surface_id": "location_surface",
		"location_id": _location_id,
		"interactions": [],
		"entities": [],
		"travel": [],
		"status_text": message,
	}


func _on_screen_button_pressed(screen_id: String, params: Dictionary) -> void:
	UIRouter.open_in_gameplay_shell(screen_id, params)


func _on_travel_button_pressed(dest_location_id: String, travel_cost: int) -> void:
	GameState.travel_to(dest_location_id, maxi(travel_cost, 0))
	_location_id = dest_location_id
	_load_location()


func _on_location_changed(_old_id: String, new_id: String) -> void:
	if new_id != _location_id:
		_location_id = new_id
		_load_location()
