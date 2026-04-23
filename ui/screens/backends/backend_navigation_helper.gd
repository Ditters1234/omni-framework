extends RefCounted

class_name OmniBackendNavigationHelper

static func close_surface(fallback_screen_id: String = "", fallback_params: Dictionary = {}) -> void:
	if not fallback_screen_id.is_empty():
		# Opens a new shell surface as a fallback, replacing the current intent of "close"
		# To strictly "pop" or "replace", backends should use navigation action returns.
		UIRouter.open_in_gameplay_shell(fallback_screen_id, fallback_params)
	else:
		UIRouter.close_gameplay_shell_surface()

static func dispatch_action(action: Dictionary) -> void:
	ActionDispatcher.dispatch(action)
