extends RefCounted

class_name OmniGameplayShellPresenter


func build_view_model(status_message: String) -> Dictionary:
	var base_view_model := {
		"screen_id": "gameplay_shell",
		"title": "Gameplay Shell",
		"subtitle": "Engine-owned hub for exploration, saves, and session-level actions.",
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

	var player_template := player.get_template()
	var player_name := str(player_template.get("display_name", player.entity_id))
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
	base_view_model["player"] = {
		"entity_id": player.entity_id,
		"display_name": player_name,
		"portrait": _build_player_portrait_view_model(player, player_template, player_name),
		"currencies": _build_currency_view_models(player),
		"stat_sheet": _build_stat_sheet_view_model(player),
		"inventory_summary": _build_inventory_summary(player),
		"equipped_parts": _build_equipped_part_view_models(player, _get_part_default_sprite_paths()),
	}
	base_view_model["time_text"] = "Time: %s" % TimeKeeper.get_time_string()
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
	base_view_model["location"] = {
		"title_text": "No Active Session",
		"description_text": "Start or load a game to enter the shell.",
		"meta_text": "",
	}
	base_view_model["player"] = {
		"portrait": {
			"display_name": "No Active Session",
			"description": "Start or load a game to render the current runtime profile.",
			"stat_preview": [],
		},
		"currencies": [],
		"stat_sheet": {
			"title": "Player Stats",
			"groups": {},
		},
		"inventory_summary": "",
		"equipped_parts": [],
	}
	base_view_model["time_text"] = ""
	base_view_model["autosave_summary"] = ""


func _build_player_portrait_view_model(player: EntityInstance, player_template: Dictionary, player_name: String) -> Dictionary:
	return {
		"display_name": player_name,
		"description": str(player_template.get("description", "No player description is available.")),
		"emblem_path": _resolve_entity_emblem_path(player_template),
		"faction_badge": {"label": "Runtime Profile"},
		"stat_preview": _build_priority_stat_preview(player),
	}


func _build_currency_view_models(player: EntityInstance) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if player.currencies.is_empty():
		return results
	var currency_symbol := str(DataManager.get_config_value("ui.currency_symbol", "$"))
	var keys: Array = player.currencies.keys()
	keys.sort()
	for key_value in keys:
		var currency_key := str(key_value)
		results.append({
			"currency_id": currency_key,
			"label": _humanize_id(currency_key),
			"amount": float(player.currencies.get(currency_key, 0.0)),
			"symbol": currency_symbol,
			"color_token": "primary",
		})
	return results


func _build_stat_sheet_view_model(player: EntityInstance) -> Dictionary:
	var groups: Dictionary = {}
	var added_stat_ids: Dictionary = {}
	var stat_definitions: Array = DataManager.get_definitions("stats")
	for stat_definition_value in stat_definitions:
		if not stat_definition_value is Dictionary:
			continue
		var stat_definition: Dictionary = stat_definition_value
		var stat_id := str(stat_definition.get("id", ""))
		if stat_id.is_empty():
			continue
		var kind := str(stat_definition.get("kind", "flat"))
		if kind == "capacity":
			continue
		var line := _build_stat_line(player, stat_definition)
		if line.is_empty():
			continue
		var group_name := str(stat_definition.get("ui_group", "other"))
		if not groups.has(group_name):
			groups[group_name] = []
		var group_lines_value: Variant = groups.get(group_name, [])
		if group_lines_value is Array:
			var group_lines: Array = group_lines_value
			group_lines.append(line)
			groups[group_name] = group_lines
		added_stat_ids[stat_id] = true

	var extra_keys: Array = player.stats.keys()
	extra_keys.sort()
	for stat_key_value in extra_keys:
		var stat_key := str(stat_key_value)
		if stat_key.ends_with("_max") or added_stat_ids.has(stat_key):
			continue
		if not groups.has("other"):
			groups["other"] = []
		var extra_line := {
			"stat_id": stat_key,
			"label": _humanize_id(stat_key),
			"value": float(player.stats.get(stat_key, 0.0)),
			"color_token": "info",
		}
		var other_group_value: Variant = groups.get("other", [])
		if other_group_value is Array:
			var other_group: Array = other_group_value
			other_group.append(extra_line)
			groups["other"] = other_group

	return {
		"title": "Player Stats",
		"groups": groups,
	}


func _build_stat_line(player: EntityInstance, stat_definition: Dictionary) -> Dictionary:
	var stat_id := str(stat_definition.get("id", ""))
	if stat_id.is_empty() or not player.stats.has(stat_id):
		return {}
	var kind := str(stat_definition.get("kind", "flat"))
	var color_token := _color_token_for_group(str(stat_definition.get("ui_group", "other")))
	if kind == "resource":
		var capacity_id := str(stat_definition.get("paired_capacity_id", ""))
		return {
			"stat_id": stat_id,
			"label": _humanize_id(stat_id),
			"value": float(player.stats.get(stat_id, 0.0)),
			"max_value": float(player.stats.get(capacity_id, 0.0)),
			"color_token": color_token,
		}
	return {
		"stat_id": stat_id,
		"label": _humanize_id(stat_id),
		"value": float(player.stats.get(stat_id, 0.0)),
		"color_token": color_token,
	}


func _build_priority_stat_preview(player: EntityInstance) -> Array[Dictionary]:
	var preview_lines: Array[Dictionary] = []
	var stat_definitions: Array = DataManager.get_definitions("stats")
	for stat_definition_value in stat_definitions:
		if not stat_definition_value is Dictionary:
			continue
		var stat_definition: Dictionary = stat_definition_value
		if str(stat_definition.get("kind", "flat")) != "resource":
			continue
		var line := _build_stat_line(player, stat_definition)
		if line.is_empty():
			continue
		preview_lines.append(line)
		if preview_lines.size() >= 2:
			return preview_lines
	if preview_lines.is_empty():
		var stat_keys: Array = player.stats.keys()
		stat_keys.sort()
		for stat_key_value in stat_keys:
			var stat_key := str(stat_key_value)
			if stat_key.ends_with("_max"):
				continue
			preview_lines.append({
				"stat_id": stat_key,
				"label": _humanize_id(stat_key),
				"value": float(player.stats.get(stat_key, 0.0)),
				"color_token": "info",
			})
			break
	return preview_lines


func _resolve_entity_emblem_path(player_template: Dictionary) -> String:
	var emblem_keys := ["emblem_path", "portrait", "sprite"]
	for emblem_key_value in emblem_keys:
		var emblem_key := str(emblem_key_value)
		var resource_path := str(player_template.get(emblem_key, ""))
		if resource_path.is_empty():
			continue
		if ResourceLoader.exists(resource_path):
			return resource_path
	return ""


func _color_token_for_group(group_name: String) -> String:
	match group_name:
		"combat":
			return "warning"
		"survival":
			return "positive"
		"economy":
			return "primary"
		_:
			return "info"


func _humanize_id(value: String) -> String:
	if value.is_empty():
		return ""
	var words := value.split("_", false)
	var formatted_words: Array[String] = []
	for word_value in words:
		var word := str(word_value)
		if word.is_empty():
			continue
		formatted_words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(formatted_words)


func _build_inventory_summary(player: EntityInstance) -> String:
	return "Inventory\nItems: %d\nDiscovered Locations: %d" % [
		player.inventory.size(),
		player.discovered_locations.size(),
	]


func _build_location_meta(player: EntityInstance) -> String:
	var screens_count := 0
	var location_template := DataManager.get_location(GameState.current_location_id)
	var screens_value: Variant = location_template.get("screens", [])
	if screens_value is Array:
		var screens: Array = screens_value
		screens_count = screens.size()
	return "Interactions: %d\nKnown Locations: %d" % [screens_count, player.discovered_locations.size()]


func _build_autosave_summary() -> String:
	var autosave_info := SaveManager.get_slot_info(SaveManager.AUTOSAVE_SLOT)
	if autosave_info.is_empty():
		return "Autosave\nNo autosave has been written yet."
	var updated_at := str(autosave_info.get("updated_at", ""))
	var day := int(autosave_info.get("day", 0))
	var tick := int(autosave_info.get("tick", 0))
	var location_name := str(autosave_info.get("location_name", ""))
	var lines: Array[String] = [
		"Autosave",
		"Last Update: %s" % updated_at,
		"Day %d, Tick %d" % [day, tick],
	]
	if not location_name.is_empty():
		lines.append("Location: %s" % location_name)
	return "\n".join(lines)


func _build_equipped_part_view_models(player: EntityInstance, default_sprite_paths: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var slots: Array = player.equipped.keys()
	slots.sort()
	for slot_value in slots:
		var slot_id := str(slot_value)
		var equipped_value: Variant = player.equipped.get(slot_id, null)
		var part := equipped_value as PartInstance
		if part == null:
			continue
		var template_value: Variant = part.get_template()
		if not template_value is Dictionary:
			continue
		var template_copy_value: Variant = template_value.duplicate(true)
		if not template_copy_value is Dictionary:
			continue
		var template: Dictionary = template_copy_value
		if template.is_empty():
			continue
		results.append({
			"template": template,
			"default_sprite_paths": default_sprite_paths,
			"price_text": "",
			"badges": [
				{"label": _humanize_id(slot_id), "color_token": "primary"},
				{"label": "Equipped", "color_token": "positive"},
			],
			"affordable": true,
		})
	return results


func _get_part_default_sprite_paths() -> Dictionary:
	var sprite_paths_data: Variant = DataManager.get_config_value("ui.default_sprites.parts", {})
	if sprite_paths_data is Dictionary:
		var sprite_paths: Dictionary = sprite_paths_data
		return sprite_paths.duplicate(true)
	return {}


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
