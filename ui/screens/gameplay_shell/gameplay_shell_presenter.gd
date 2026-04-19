extends RefCounted

class_name OmniGameplayShellPresenter


func build_view_model(status_message: String) -> Dictionary:
	var base_view_model := {
		"screen_id": "gameplay_shell",
		"title": "Gameplay",
		"subtitle": "Explore the current location and open interaction surfaces.",
		"time_button_specs": get_time_button_specs(),
	}
	if GameState.player == null:
		_apply_inactive_session_state(
			base_view_model,
			"The gameplay shell becomes available once a runtime session exists."
		)
		return base_view_model

	var player_object: Variant = GameState.player
	var player := player_object as EntityInstance
	if player == null:
		_apply_inactive_session_state(
			base_view_model,
			"The gameplay shell could not resolve the active player entity."
		)
		return base_view_model

	var location_template := DataManager.get_location(GameState.current_location_id)
	var location_name := str(location_template.get("display_name", GameState.current_location_id))
	var location_description := str(location_template.get("description", ""))
	base_view_model["has_session"] = true
	base_view_model["status_text"] = status_message
	base_view_model["buttons_enabled"] = true
	base_view_model["location"] = {
		"id": GameState.current_location_id,
		"title_text": location_name,
		"description_text": location_description if not location_description.is_empty() else "No location description is available yet.",
		"meta_text": _build_location_meta(player),
	}
	base_view_model["session"] = {
		"time_text": "Time: %s" % TimeKeeper.get_time_string(),
		"day_text": _build_day_text(),
	}
	return base_view_model


func get_time_button_specs() -> Array[Dictionary]:
	var configured_value: Variant = DataManager.get_config_value("ui.time_advance_buttons", ["1 hour", "1 day"])
	var specs: Array[Dictionary] = []
	if configured_value is Array:
		var configured_buttons: Array = configured_value
		for button_value in configured_buttons:
			var spec := _parse_time_advance_spec(str(button_value))
			if spec.is_empty():
				continue
			specs.append(spec)
	if specs.is_empty():
		specs.append({"label": "1 Hour", "ticks": _get_ticks_per_hour()})
		specs.append({"label": "1 Day", "ticks": TimeKeeper.get_ticks_per_day()})
	return specs


func _apply_inactive_session_state(base_view_model: Dictionary, status_text: String) -> void:
	base_view_model["has_session"] = false
	base_view_model["status_text"] = status_text
	base_view_model["buttons_enabled"] = false
	base_view_model["location"] = {
		"title_text": "No Active Session",
		"description_text": "Start or load a game to enter the shell.",
		"meta_text": "",
	}
	base_view_model["session"] = {
		"time_text": "",
		"day_text": "",
	}


func _build_location_meta(player: EntityInstance) -> String:
	var screens_count := 0
	var location_template := DataManager.get_location(GameState.current_location_id)
	var screens_value: Variant = location_template.get("screens", [])
	if screens_value is Array:
		var screens: Array = screens_value
		screens_count = screens.size()
	return "Interactions: %d | Known Locations: %d" % [screens_count, player.discovered_locations.size()]


func _build_day_text() -> String:
	var current_day := 0
	if TimeKeeper.has_method("get_current_day"):
		current_day = int(TimeKeeper.call("get_current_day"))
		return "Day %d" % current_day
	var debug_snapshot_value: Variant = {}
	if TimeKeeper.has_method("get_debug_snapshot"):
		debug_snapshot_value = TimeKeeper.call("get_debug_snapshot")
	if debug_snapshot_value is Dictionary:
		var debug_snapshot: Dictionary = debug_snapshot_value
		current_day = int(debug_snapshot.get("day", 0))
	return "Day %d" % current_day


func _parse_time_advance_spec(label: String) -> Dictionary:
	var normalized := label.strip_edges()
	if normalized.is_empty():
		return {}
	var parts := normalized.to_lower().split(" ", false)
	if parts.is_empty():
		return {}
	var quantity := 1
	if parts[0].is_valid_int():
		quantity = maxi(int(parts[0]), 1)
	var unit := parts[parts.size() - 1]
	match unit:
		"tick", "ticks":
			return {"label": normalized.capitalize(), "ticks": quantity}
		"hour", "hours":
			return {"label": normalized.capitalize(), "ticks": quantity * _get_ticks_per_hour()}
		"day", "days":
			return {"label": normalized.capitalize(), "ticks": quantity * TimeKeeper.get_ticks_per_day()}
		_:
			return {}


func _get_ticks_per_hour() -> int:
	var configured_value: Variant = DataManager.get_config_value("game.ticks_per_hour", 0)
	var configured_ticks := int(configured_value)
	if configured_ticks > 0:
		return configured_ticks
	var ticks_per_day := maxi(TimeKeeper.get_ticks_per_day(), 1)
	return maxi(int(round(float(ticks_per_day) / 24.0)), 1)
