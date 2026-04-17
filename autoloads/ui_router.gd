## UIRouter — Screen navigation stack.
## All screen transitions go through here; never navigate directly.
## Screens are registered by id → PackedScene path.
## The stack allows back-navigation with pop().
extends Node

class_name OmniUIRouter

const SCREENS_PATH := "res://ui/screens/"

## screen_id → res:// path to the .tscn file
var _screen_registry: Dictionary = {}

## Navigation stack: Array of {screen_id, params, node}
var _stack: Array[Dictionary] = []

## The root container where screens are instantiated.
var _screen_container: CanvasLayer = null

# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass


## Called after the scene tree is ready. Sets the container node.
func initialize(container: CanvasLayer) -> void:
	_screen_container = container


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

## Registers a screen id with its scene path.
## Called at boot or by mods adding custom screens.
func register_screen(screen_id: String, scene_path: String) -> void:
	_screen_registry[screen_id] = scene_path


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## Pushes a new screen onto the stack.
## params is a free-form Dictionary passed to the screen's initialize() method.
func push(screen_id: String, params: Dictionary = {}) -> void:
	var screen := _instantiate_screen(screen_id)
	if screen == null:
		return
	_screen_container.add_child(screen)
	if screen.has_method("initialize"):
		screen.initialize(params)
	_stack.append({
		"screen_id": screen_id,
		"params": params.duplicate(true),
		"node": screen,
	})
	GameEvents.screen_pushed.emit(screen_id)
	GameEvents.ui_screen_pushed.emit(screen_id)


## Pops the top screen and returns to the previous one.
func pop() -> void:
	if _stack.is_empty():
		return
	var screen_id := current_screen_id()
	_teardown_top()
	GameEvents.screen_popped.emit(screen_id)
	GameEvents.ui_screen_popped.emit(screen_id)


## Replaces the entire stack with a single screen (e.g. main menu).
func replace_all(screen_id: String, params: Dictionary = {}) -> void:
	while not _stack.is_empty():
		_teardown_top()
	var screen := _instantiate_screen(screen_id)
	if screen == null:
		return
	_screen_container.add_child(screen)
	if screen.has_method("initialize"):
		screen.initialize(params)
	_stack.append({
		"screen_id": screen_id,
		"params": params.duplicate(true),
		"node": screen,
	})
	GameEvents.screen_pushed.emit(screen_id)
	GameEvents.ui_screen_pushed.emit(screen_id)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the screen_id of the currently visible screen, or "" if empty.
func current_screen_id() -> String:
	if _stack.is_empty():
		return ""
	return _stack.back()["screen_id"]


## Returns true if any screen is active.
func has_screen() -> bool:
	return not _stack.is_empty()


func stack_depth() -> int:
	return _stack.size()


## Returns true if the given screen_id is registered.
func is_registered(screen_id: String) -> bool:
	return _screen_registry.has(screen_id)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _teardown_top() -> void:
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var node: Node = entry.get("node", null)
	if node and is_instance_valid(node):
		node.queue_free()


func _instantiate_screen(screen_id: String) -> Control:
	if not _screen_registry.has(screen_id):
		push_error("UIRouter: unknown screen '%s'" % screen_id)
		return null
	var path: String = _screen_registry[screen_id]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("UIRouter: could not load scene at '%s'" % path)
		return null
	return packed.instantiate()
