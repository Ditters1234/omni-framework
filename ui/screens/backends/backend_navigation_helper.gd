extends RefCounted

class_name OmniBackendNavigationHelper

static func open_screen(screen_id: String, params: Dictionary = {}, prefer_gameplay_shell: bool = false) -> void:
	if prefer_gameplay_shell and UIRouter.open_in_gameplay_shell(screen_id, params):
		return
	UIRouter.push(screen_id, params)


static func go_back(opened_from_gameplay_shell: bool = false) -> void:
	if opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_surface()
		return
	UIRouter.pop()


static func close_surface(fallback_screen_id: String = "", fallback_params: Dictionary = {}) -> void:
	if not fallback_screen_id.is_empty():
		# Opens a new shell surface as a fallback, replacing the current intent of "close"
		# To strictly "pop" or "replace", backends should use navigation action returns.
		UIRouter.open_in_gameplay_shell(fallback_screen_id, fallback_params)
	else:
		UIRouter.close_gameplay_shell_surface()


static func execute_navigation_action(
	action: Dictionary,
	opened_from_gameplay_shell: bool = false,
	shell_pop_fallback_screen_id: String = "",
	shell_pop_fallback_params: Dictionary = {}
) -> bool:
	var action_type := str(action.get("type", ""))
	var screen_id := str(action.get("screen_id", ""))
	var params := _read_dictionary(action.get("params", {}))
	match action_type:
		"pop":
			if opened_from_gameplay_shell:
				if not shell_pop_fallback_screen_id.is_empty():
					UIRouter.replace_all(shell_pop_fallback_screen_id, shell_pop_fallback_params)
				else:
					UIRouter.close_gameplay_shell_surface()
			else:
				UIRouter.pop()
			return true
		"replace_all":
			if screen_id.is_empty():
				return false
			if opened_from_gameplay_shell and UIRouter.open_in_gameplay_shell(screen_id, params):
				return true
			UIRouter.replace_all(screen_id, params)
			return true
		"push":
			if screen_id.is_empty():
				return false
			if opened_from_gameplay_shell and UIRouter.open_in_gameplay_shell(screen_id, params):
				return true
			UIRouter.push(screen_id, params)
			return true
		_:
			return false


static func dispatch_action(action: Dictionary) -> void:
	ActionDispatcher.dispatch(action)


static func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
