extends RefCounted

class_name OmniBackendNavigationHelper

static func close_surface(cancel_screen_id: String = "", cancel_params: Dictionary = {}) -> void:
	UIRouter.close_shell_surface(cancel_screen_id, cancel_params)

static func dispatch_action(action: Dictionary) -> void:
	UIRouter.dispatch_shell_action(action)
