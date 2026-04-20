extends RefCounted

class_name OmniGameplayShellPresenter

const BACKEND_HELPERS := preload("res://ui/screens/backends/backend_helpers.gd")

func build_view_model(status_message: String) -> Dictionary:
	var base_view_model := {
		"screen_id": "gameplay_shell",
		"title": "Gameplay",
		"subtitle": "Persistent session frame for local interactions and global menus.",
		"time_button_specs": get_time_button_specs(),
	}
	if GameState.player == null:
		_apply_inactive_session_state(base_view_model, "The gameplay shell becomes available once a runtime session exists.")
		return base_view_model

	var player_object: Variant = GameState.player
	var player := player_object as EntityInstance
	if player == null:
		_apply_inactive_session_state(base_view_model, "The gameplay shell could not resolve the active player entity.")
		return base_view_model

	var location_template := DataManager.get_location(GameState.current_location_id)
	var location_name := str(location_template.get("display_name", GameState.current_location_id))
	var location_description := str(location_template.get("description", ""))
	base_view_model["has_session"] = true
	base_view_model["status_text"] = status_message
	base_view_model["buttons_enabled"] = true
	base_view_model["player"] = _build_player_view_model(player)
	base_view_model["location"] = {
		"id": GameState.current_location_id,
		"title_text": location_name,
		"description_text": location_description if not location_description.is_empty() else "No location description is available yet.",
		"meta_text": _build_location_meta(player),
	}
	var session := _build_session_view_model()
	base_view_model["session"] = session
	base_view_model["time_text"] = str(session.get("time_text", ""))
	base_view_model["session_day_text"] = str(session.get("day_text", ""))
	base_view_model["autosave_summary"] = _build_autosave_summary()
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
	base_view_model["player"] = _build_player_view_model(null)
	base_view_model["location"] = {
		"title_text": "No Active Session",
		"description_text": "Start or load a game to enter the shell.",
		"meta_text": "",
	}
	base_view_model["time_text"] = ""
	base_view_model["session_day_text"] = ""
	base_view_model["session"] = {
		"time_text": "",
		"day_text": "",
	}
	base_view_model["autosave_summary"] = ""


func _build_location_meta(player: EntityInstance) -> String:
	var screens_count := 0
	var location_template := DataManager.get_location(GameState.current_location_id)
	var screens_value: Variant = location_template.get("screens", [])
	if screens_value is Array:
		var screens: Array = screens_value
		screens_count = screens.size()
	return "Interactions: %d | Known Locations: %d" % [screens_count, player.discovered_locations.size()]


func _build_player_view_model(player: EntityInstance) -> Dictionary:
	if player == null:
		return {
			"entity_id": "",
			"display_name": "",
			"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(null, "", "No active player."),
			"stat_sheet": BACKEND_HELPERS.build_stat_sheet_view_model(null, "Player Stats"),
			"equipped_parts": [],
		}
	var display_name := BACKEND_HELPERS.get_entity_display_name(player, player.entity_id)
	return {
		"entity_id": player.entity_id,
		"display_name": display_name,
		"portrait": BACKEND_HELPERS.build_entity_portrait_view_model(player, display_name),
		"stat_sheet": BACKEND_HELPERS.build_stat_sheet_view_model(player, "Player Stats"),
		"equipped_parts": _build_equipped_parts(player),
	}


func _build_equipped_parts(player: EntityInstance) -> Array[Dictionary]:
	var equipped_parts: Array[Dictionary] = []
	var slot_ids: Array = player.equipped.keys()
	slot_ids.sort()
	for slot_id_value in slot_ids:
		var slot_id := str(slot_id_value)
		var part := player.get_equipped(slot_id)
		if part == null:
			continue
		var template := DataManager.get_part(part.template_id)
		equipped_parts.append({
			"slot_id": slot_id,
			"instance_id": part.instance_id,
			"template_id": part.template_id,
			"display_name": str(template.get("display_name", BACKEND_HELPERS.humanize_id(part.template_id))),
		})
	return equipped_parts


func _build_session_view_model() -> Dictionary:
	var time_text := "Time: %s" % TimeKeeper.get_time_string()
	var day_text := _build_session_day_text()
	return {
		"time_text": time_text,
		"day_text": day_text,
	}


func _build_session_day_text() -> String:
	var current_day := 0
	if TimeKeeper.has_method("get_current_day"):
		current_day = int(TimeKeeper.call("get_current_day"))
	else:
		var snapshot: Dictionary = SaveManager.get_slot_info(SaveManager.AUTOSAVE_SLOT)
		current_day = int(snapshot.get("day", 0))
	return "Day: %d" % current_day


func _build_autosave_summary() -> String:
	var slot_label := SaveManager.get_slot_label(SaveManager.AUTOSAVE_SLOT)
	var slot_info := SaveManager.get_slot_info(SaveManager.AUTOSAVE_SLOT)
	if slot_info.is_empty():
		return "%s: empty" % slot_label
	return "%s: Day %d" % [slot_label, int(slot_info.get("day", 0))]


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
