extends RefCounted

class_name GameplayLocationActionService

const LOCATION_ACCESS_SERVICE := preload("res://systems/location_access_service.gd")


static func is_screen_available(screen_id: String) -> bool:
	return not screen_id.is_empty() and UIRouter.is_registered(screen_id)


static func open_surface(screen_id: String, params: Dictionary) -> bool:
	if screen_id.is_empty():
		return false
	return UIRouter.open_in_gameplay_shell(screen_id, params)


static func travel_to(destination_location_id: String, travel_cost: int) -> Dictionary:
	var access_status := LOCATION_ACCESS_SERVICE.get_entry_status(destination_location_id)
	if not bool(access_status.get("can_enter", false)):
		return {
			"ok": false,
			"message": str(access_status.get("message", "You cannot enter this location right now.")),
			"location_id": GameState.current_location_id,
		}
	GameState.travel_to(destination_location_id, maxi(travel_cost, 0))
	return {
		"ok": true,
		"message": "",
		"location_id": destination_location_id,
	}
