## UIRouter — Screen navigation stack.
## All screen transitions go through here; never navigate directly.
## Screens are registered by id → PackedScene path.
## The stack allows back-navigation with pop().
extends Node

class_name OmniUIRouter

const SCREENS_PATH := "res://ui/screens/"
const MAX_DEBUG_ERRORS := 20

## screen_id → res:// path to the .tscn file
var _screen_registry: Dictionary = {}

## Navigation stack: Array of {screen_id, params, node}
var _stack: Array[Dictionary] = []

## The root container where screens are instantiated.
var _screen_container: CanvasLayer = null
var _screen_theme: Theme = null
var _recent_errors: Array[String] = []

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass


## Called after the scene tree is ready. Sets the container node.
func initialize(container: CanvasLayer) -> void:
	if container == null:
		_record_error("initialize() requires a valid CanvasLayer container.")
		return
	_screen_container = container
	_reattach_stack_to_container()


func set_screen_theme(screen_theme: Theme) -> void:
	_screen_theme = screen_theme
	for entry in _stack:
		var node_data: Variant = entry.get("node", null)
		var screen := node_data as Control
		if screen != null:
			screen.theme = _screen_theme


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

## Registers a screen id with its scene path.
## Called at boot or by mods adding custom screens.
func register_screen(screen_id: String, scene_path: String) -> void:
	if screen_id.is_empty():
		_record_error("register_screen() requires a non-empty screen_id.")
		return
	if scene_path.is_empty():
		_record_error("register_screen('%s') requires a non-empty scene_path." % screen_id)
		return
	_screen_registry[screen_id] = scene_path


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## Pushes a new screen onto the stack.
## params is a free-form Dictionary passed to the screen's initialize() method.
func push(screen_id: String, params: Dictionary = {}) -> void:
	if not _can_navigate("push", screen_id):
		return
	var screen := _instantiate_screen(screen_id)
	if screen == null:
		return
	var previous_screen := _get_top_screen_node()
	if previous_screen != null:
		_set_screen_active(previous_screen, false)
	_screen_container.add_child(screen)
	_initialize_screen(screen, params)
	_stack.append(_create_stack_entry(screen_id, params, screen))
	_emit_screen_pushed(screen_id)


## Pops the top screen and returns to the previous one.
func pop() -> void:
	if _stack.is_empty():
		return
	_teardown_top(true)
	var next_screen := _get_top_screen_node()
	if next_screen != null:
		_set_screen_active(next_screen, true)


## Replaces the entire stack with a single screen (e.g. main menu).
func replace_all(screen_id: String, params: Dictionary = {}) -> void:
	if not _can_navigate("replace_all", screen_id):
		return
	var screen := _instantiate_screen(screen_id)
	if screen == null:
		return
	while not _stack.is_empty():
		_teardown_top(true)
	_screen_container.add_child(screen)
	_initialize_screen(screen, params)
	_stack.append(_create_stack_entry(screen_id, params, screen))
	_emit_screen_pushed(screen_id)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the screen_id of the currently visible screen, or "" if empty.
func current_screen_id() -> String:
	if _stack.is_empty():
		return ""
	var entry: Dictionary = _stack.back()
	return _get_stack_entry_screen_id(entry)


func current_screen_params() -> Dictionary:
	if _stack.is_empty():
		return {}
	var entry: Dictionary = _stack.back()
	return _get_stack_entry_params(entry)


## Returns true if any screen is active.
func has_screen() -> bool:
	return not _stack.is_empty()


func stack_depth() -> int:
	return _stack.size()


## Returns true if the given screen_id is registered.
func is_registered(screen_id: String) -> bool:
	return _screen_registry.has(screen_id)


func get_registered_screens() -> Dictionary:
	return _screen_registry.duplicate(true)


func get_stack_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry in _stack:
		var node := _get_stack_entry_node(entry)
		snapshot.append({
			"screen_id": _get_stack_entry_screen_id(entry),
			"params": _get_stack_entry_params(entry),
			"node_name": _get_node_name(node),
			"visible": node != null and node.visible,
			"in_tree": node != null and node.is_inside_tree(),
		})
	return snapshot


func get_debug_snapshot() -> Dictionary:
	var registered_screen_ids: Array[String] = []
	for screen_id_value in _screen_registry.keys():
		registered_screen_ids.append(str(screen_id_value))
	registered_screen_ids.sort()
	return {
		"has_container": _screen_container != null,
		"container_valid": _screen_container != null and is_instance_valid(_screen_container),
		"container_path": _get_container_path(),
		"registered_screen_count": _screen_registry.size(),
		"registered_screen_ids": registered_screen_ids,
		"current_screen_id": current_screen_id(),
		"current_screen_params": current_screen_params(),
		"stack_depth": _stack.size(),
		"stack": get_stack_snapshot(),
		"theme_assigned": _screen_theme != null,
		"recent_errors": _recent_errors.duplicate(),
	}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _teardown_top(emit_events: bool) -> void:
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var screen_id := _get_stack_entry_screen_id(entry)
	var node := _get_stack_entry_node(entry)
	if node != null and is_instance_valid(node):
		node.queue_free()
	if emit_events and not screen_id.is_empty():
		_emit_screen_popped(screen_id)


func _instantiate_screen(screen_id: String) -> Control:
	if not _screen_registry.has(screen_id):
		_record_error("Unknown screen '%s'." % screen_id)
		return null
	var path_value: Variant = _screen_registry.get(screen_id, "")
	var path := str(path_value)
	if path.is_empty():
		_record_error("Screen '%s' is registered without a scene path." % screen_id)
		return null
	var packed_value: Variant = load(path)
	if not packed_value is PackedScene:
		_record_error("Could not load PackedScene for '%s' at '%s'." % [screen_id, path])
		return null
	var packed: PackedScene = packed_value
	var screen_value: Variant = packed.instantiate()
	var screen_node := screen_value as Node
	var screen := screen_value as Control
	if screen == null:
		if screen_node != null and is_instance_valid(screen_node):
			screen_node.free()
		_record_error("Scene '%s' at '%s' must inherit Control." % [screen_id, path])
		return null
	if _screen_theme != null:
		screen.theme = _screen_theme
	return screen


func _can_navigate(operation: String, screen_id: String) -> bool:
	if screen_id.is_empty():
		_record_error("%s() requires a non-empty screen_id." % operation)
		return false
	if _screen_container == null or not is_instance_valid(_screen_container):
		_record_error("%s('%s') called before initialize() set a valid screen container." % [operation, screen_id])
		return false
	return true


func _create_stack_entry(screen_id: String, params: Dictionary, screen: Control) -> Dictionary:
	return {
		"screen_id": screen_id,
		"params": params.duplicate(true),
		"node": screen,
	}


func _initialize_screen(screen: Control, params: Dictionary) -> void:
	if screen.has_method("initialize"):
		screen.call("initialize", params.duplicate(true))
	_set_screen_active(screen, true)


func _emit_screen_pushed(screen_id: String) -> void:
	GameEvents.screen_pushed.emit(screen_id)
	GameEvents.ui_screen_pushed.emit(screen_id)


func _emit_screen_popped(screen_id: String) -> void:
	GameEvents.screen_popped.emit(screen_id)
	GameEvents.ui_screen_popped.emit(screen_id)


func _set_screen_active(screen: Control, is_active: bool) -> void:
	screen.visible = is_active
	if is_active:
		if screen.has_method("on_route_revealed"):
			screen.call("on_route_revealed")
	else:
		if screen.has_method("on_route_hidden"):
			screen.call("on_route_hidden")


func _get_top_screen_node() -> Control:
	if _stack.is_empty():
		return null
	var entry: Dictionary = _stack.back()
	return _get_stack_entry_node(entry)


func _get_stack_entry_screen_id(entry: Dictionary) -> String:
	var screen_id_value: Variant = entry.get("screen_id", "")
	return str(screen_id_value)


func _get_stack_entry_params(entry: Dictionary) -> Dictionary:
	var params_value: Variant = entry.get("params", {})
	if params_value is Dictionary:
		var params: Dictionary = params_value
		return params.duplicate(true)
	return {}


func _get_stack_entry_node(entry: Dictionary) -> Control:
	var node_value: Variant = entry.get("node", null)
	return node_value as Control


func _get_container_path() -> String:
	if _screen_container == null or not is_instance_valid(_screen_container):
		return ""
	return str(_screen_container.get_path())


func _get_node_name(node: Control) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	return node.name


func _reattach_stack_to_container() -> void:
	if _screen_container == null or not is_instance_valid(_screen_container):
		return
	for entry in _stack:
		var node := _get_stack_entry_node(entry)
		if node == null or not is_instance_valid(node):
			continue
		var current_parent := node.get_parent()
		if current_parent == _screen_container:
			continue
		if current_parent != null:
			current_parent.remove_child(node)
		_screen_container.add_child(node)


func _record_error(message: String) -> void:
	var full_message := "UIRouter: %s" % message
	push_error(full_message)
	_recent_errors.append(full_message)
	if _recent_errors.size() > MAX_DEBUG_ERRORS:
		_recent_errors.pop_front()
