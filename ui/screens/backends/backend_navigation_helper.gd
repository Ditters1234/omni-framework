extends RefCounted

class_name OmniBackendNavigationHelper

static func close_surface(cancel_screen_id: String = "", cancel_params: Dictionary = {}) -> void:
	if not cancel_screen_id.is_empty():
		UIRouter.open_in_gameplay_shell(cancel_screen_id, cancel_params)
	else:
		UIRouter.close_gameplay_shell_surface()

static func dispatch_action(action: Dictionary) -> void:
	ActionDispatcher.dispatch(action)
