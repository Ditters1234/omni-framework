extends CanvasLayer

class_name OmniDevDebugOverlay

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const PANEL_WIDTH := 620.0
const PANEL_HEIGHT := 700.0
const REFRESH_INTERVAL := 0.25
const MAX_VISIBLE_EVENTS := 40

# Tab indices
const TAB_BOOT := 0
const TAB_REGISTRIES := 1
const TAB_RUNTIME := 2
const TAB_EVENTS := 3
const TAB_ENTITIES := 4

var _overlay_visible: bool = false

var _panel: PanelContainer = null
var _tab_container: TabContainer = null
var _tab_labels: Array[RichTextLabel] = []
var _refresh_timer: Timer = null


func initialize_overlay() -> void:
	pass


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_INTERVAL
	_refresh_timer.one_shot = false
	_refresh_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_timer.timeout.connect(_refresh_active_tab)
	add_child(_refresh_timer)
	_refresh_timer.start()
	_set_overlay_visible(false)
	_refresh_all_tabs()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_set_overlay_visible(not _overlay_visible)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -PANEL_WIDTH - 16.0
	_panel.offset_top = 16.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = PANEL_HEIGHT + 16.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Omni Dev Overlay  [F3]"
	column.add_child(title)

	_tab_container = TabContainer.new()
	_tab_container.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, PANEL_HEIGHT - 48.0)
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tab_container)

	var tab_names := ["Boot", "Registries", "Runtime", "Events", "Entities"]
	for tab_name in tab_names:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(scroll)

		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scroll.add_child(lbl)
		_tab_labels.append(lbl)


func _set_overlay_visible(p_is_visible: bool) -> void:
	_overlay_visible = p_is_visible
	visible = p_is_visible
	if _panel:
		_panel.visible = p_is_visible
	_refresh_all_tabs()


func _refresh_active_tab() -> void:
	if not _overlay_visible or _tab_container == null:
		return
	_refresh_tab(_tab_container.current_tab)


func _refresh_all_tabs() -> void:
	for i in range(_tab_labels.size()):
		_refresh_tab(i)


func _refresh_tab(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= _tab_labels.size():
		return
	var lbl := _tab_labels[tab_index]
	match tab_index:
		TAB_BOOT:
			lbl.text = _build_boot_text()
		TAB_REGISTRIES:
			lbl.text = _build_registries_text()
		TAB_RUNTIME:
			lbl.text = _build_runtime_text()
		TAB_EVENTS:
			lbl.text = _build_events_text()
		TAB_ENTITIES:
			lbl.text = _build_entities_text()


# ---------------------------------------------------------------------------
# Tab content builders
# ---------------------------------------------------------------------------

func _build_boot_text() -> String:
	var b := PackedStringArray()
	var mod_snapshot := ModLoader.get_debug_snapshot()
	var is_loaded := bool(mod_snapshot.get("is_loaded", false))
	var error_count := int(mod_snapshot.get("error_count", 0))
	var fatal_count := int(mod_snapshot.get("fatal_error_count", 0))

	_bb_section(b, "ModLoader")
	_bb_kv(b, "status", str(mod_snapshot.get("status", "")), not is_loaded)
	_bb_kv(b, "loaded", str(is_loaded), not is_loaded)
	_bb_kv(b, "mods", "%d discovered=%d" % [
		int(mod_snapshot.get("loaded_mod_count", 0)),
		int(mod_snapshot.get("discovered_mod_count", 0))
	])
	_bb_kv(b, "timings", "additions=%sms  patches=%sms  hooks=%sms  total=%sms" % [
		str(mod_snapshot.get("phase_one_ms", 0)),
		str(mod_snapshot.get("phase_two_ms", 0)),
		str(mod_snapshot.get("script_hook_preload_ms", 0)),
		str(mod_snapshot.get("total_ms", 0))
	])
	if error_count > 0:
		_bb_kv(b, "errors", "total=%d  fatal=%d  nonfatal=%d" % [
			error_count, fatal_count, int(mod_snapshot.get("nonfatal_error_count", 0))
		], true)
	else:
		_bb_kv(b, "errors", "none")

	if not ModLoader.loaded_mods.is_empty():
		b.append("  [color=gray]load order:[/color]")
		for manifest in ModLoader.loaded_mods:
			b.append("    [color=aqua]%s[/color] [color=gray]%s[/color]" % [
				str(manifest.get("id", "")),
				str(manifest.get("version", ""))
			])

	b.append("")
	_bb_section(b, "AI")
	var ai_snapshot := AIManager.get_debug_snapshot()
	var ai_available := bool(ai_snapshot.get("available", false))
	_bb_kv(b, "provider", AIManager.get_provider_name())
	_bb_kv(b, "enabled", str(bool(ai_snapshot.get("enabled", false))))
	_bb_kv(b, "available", str(ai_available), not ai_available)
	var ai_last_error := str(ai_snapshot.get("last_error", ""))
	if not ai_last_error.is_empty():
		_bb_kv(b, "last error", ai_last_error, true)
	var ai_last_request_value: Variant = ai_snapshot.get("last_request", {})
	if ai_last_request_value is Dictionary:
		var ai_last_request: Dictionary = ai_last_request_value
		if not ai_last_request.is_empty():
			_bb_kv(b, "last request", "%s  status=%s" % [
				str(ai_last_request.get("request_id", "")),
				str(ai_last_request.get("status", ""))
			])

	b.append("")
	_bb_section(b, "GameEvents")
	var events_snapshot := GameEvents.get_debug_snapshot()
	_bb_kv(b, "signals", str(int(events_snapshot.get("signal_count", 0))))
	_bb_kv(b, "history", str(int(events_snapshot.get("history_count", 0))))

	b.append("")
	_bb_section(b, "Engine")
	_bb_kv(b, "ImGuiRoot", str(has_node("/root/ImGuiRoot")))

	return "\n".join(b)


func _build_registries_text() -> String:
	var b := PackedStringArray()
	var registry_counts := DataManager.get_registry_counts()
	var data_snapshot := DataManager.get_debug_snapshot()
	var issue_count := int(data_snapshot.get("issue_count", 0))

	_bb_section(b, "DataManager")
	_bb_kv(b, "status", str(data_snapshot.get("status", "")))
	_bb_kv(b, "loaded", str(bool(data_snapshot.get("is_loaded", false))))
	_bb_kv(b, "files", "processed=%d  invalid=%d" % [
		int(data_snapshot.get("processed_file_count", 0)),
		int(data_snapshot.get("invalid_file_count", 0))
	])
	_bb_kv(b, "issues", str(issue_count), issue_count > 0)

	b.append("")
	_bb_section(b, "Counts")
	var count_keys := ["stats", "currencies", "parts", "entities", "locations", "factions", "quests", "tasks", "achievements"]
	for key in count_keys:
		_bb_kv(b, key, str(int(registry_counts.get(key, 0))))

	var recent_issues_value: Variant = data_snapshot.get("recent_issues", [])
	if recent_issues_value is Array:
		var recent_issues: Array = recent_issues_value
		if not recent_issues.is_empty():
			b.append("")
			_bb_section(b, "Recent Issues")
			for issue_value in recent_issues:
				if not issue_value is Dictionary:
					continue
				var issue: Dictionary = issue_value
				b.append("  [color=orange][%s][/color] %s" % [
					str(issue.get("phase", "")),
					str(issue.get("message", ""))
				])

	return "\n".join(b)


func _build_runtime_text() -> String:
	var b := PackedStringArray()
	var recent_issues_value: Variant = DataManager.get_debug_snapshot().get("recent_issues", [])

	_bb_section(b, "UIRouter")
	var router_snapshot := UIRouter.get_debug_snapshot()
	_bb_kv(b, "screen", str(router_snapshot.get("current_screen_id", "")))
	_bb_kv(b, "depth", str(int(router_snapshot.get("stack_depth", 0))))
	_bb_kv(b, "container", str(bool(router_snapshot.get("container_valid", false))))
	var router_stack_value: Variant = router_snapshot.get("stack", [])
	if router_stack_value is Array:
		var router_stack: Array = router_stack_value
		if not router_stack.is_empty():
			b.append("  [color=gray]stack:[/color]")
			for stack_entry_value in router_stack:
				if not stack_entry_value is Dictionary:
					continue
				var stack_entry: Dictionary = stack_entry_value
				var is_vis := bool(stack_entry.get("visible", false))
				b.append("    [color=%s]%s[/color] visible=%s" % [
					"white" if is_vis else "gray",
					str(stack_entry.get("screen_id", "")),
					str(is_vis)
				])
	var router_errors_value: Variant = router_snapshot.get("recent_errors", [])
	if router_errors_value is Array:
		var router_errors: Array = router_errors_value
		for error_value in router_errors:
			b.append("  [color=red]error:[/color] %s" % str(error_value))
	_bb_kv(b, "params", _format_variant(router_snapshot.get("current_screen_params", {})))

	var current_screen_snapshot := UIRouter.get_current_screen_debug_snapshot()
	if not current_screen_snapshot.is_empty():
		b.append("")
		_bb_section(b, "Current Screen")
		for snapshot_line in _format_multiline_variant(current_screen_snapshot):
			b.append("  %s" % snapshot_line)
		var ai_service_value: Variant = current_screen_snapshot.get("ai_service", {})
		if ai_service_value is Dictionary:
			var ai_service_snapshot: Dictionary = ai_service_value
			if not ai_service_snapshot.is_empty():
				b.append("")
				_bb_section(b, "AI Chat")
				_bb_kv(b, "persona", str(ai_service_snapshot.get("persona_id", "")))
				_bb_kv(b, "configured", str(bool(ai_service_snapshot.get("configured", false))))
				_bb_kv(b, "last response", str(ai_service_snapshot.get("last_response", "")))
				_bb_kv(b, "validation", _format_variant(ai_service_snapshot.get("last_validation", {})))
				var history_value: Variant = ai_service_snapshot.get("history", [])
				if history_value is Array:
					var history: Array = history_value
					b.append("  [color=gray]history (%d entries, last 3):[/color]" % history.size())
					for history_index in range(maxi(history.size() - 3, 0), history.size()):
						var history_entry_value: Variant = history[history_index]
						if not history_entry_value is Dictionary:
							continue
						var history_entry: Dictionary = history_entry_value
						var role := str(history_entry.get("role", ""))
						var role_color := "aqua" if role == "user" else "green"
						b.append("    [color=%s]%s:[/color] %s" % [
							role_color, role,
							str(history_entry.get("content", ""))
						])

	b.append("")
	_bb_section(b, "Backend Contracts")
	var backend_classes := BACKEND_CONTRACT_REGISTRY.get_registered_backend_classes()
	if backend_classes.is_empty():
		b.append("  [color=gray]<none>[/color]")
	else:
		for bc in backend_classes:
			b.append("  [color=aqua]%s[/color]" % str(bc))
	var backend_contract_issues := _extract_backend_contract_issues(recent_issues_value)
	if not backend_contract_issues.is_empty():
		b.append("  [color=red]contract issues:[/color]")
		for issue_text in backend_contract_issues:
			b.append("    [color=red]- %s[/color]" % issue_text)

	b.append("")
	_bb_section(b, "World State")
	_bb_kv(b, "location", GameState.current_location_id)
	_bb_kv(b, "day/tick", "day=%d  tick=%d" % [GameState.current_day, GameState.current_tick])
	var time_snapshot := TimeKeeper.get_debug_snapshot()
	_bb_kv(b, "time running", str(bool(time_snapshot.get("is_running", false))))
	_bb_kv(b, "tick rate", "%.2f" % float(time_snapshot.get("tick_rate", 0.0)))
	_bb_kv(b, "tick in day", "%d/%d" % [
		int(time_snapshot.get("ticks_into_day", 0)),
		int(time_snapshot.get("ticks_per_day", 0))
	])
	_bb_kv(b, "consistent", str(bool(time_snapshot.get("is_time_consistent", false))))
	_bb_kv(b, "active tasks", str(int(time_snapshot.get("active_task_count", 0))))
	_bb_kv(b, "flags", str(GameState.flags.size()))
	_bb_kv(b, "achievements", str(GameState.unlocked_achievements.size()))

	b.append("")
	_bb_section(b, "Player")
	var player: EntityInstance = GameState.player
	if player:
		_bb_kv(b, "entity_id", player.entity_id)
		_bb_kv(b, "template_id", player.template_id)
		_bb_kv(b, "currencies", _format_dictionary(player.currencies))
		b.append("  [color=gray]stats:[/color]")
		var stat_keys := player.stats.keys()
		stat_keys.sort()
		for stat_key in stat_keys:
			b.append("    [color=gray]%s[/color] = [color=white]%s[/color]" % [
				str(stat_key), str(player.stats[stat_key])
			])
	else:
		b.append("  [color=gray]<none>[/color]")

	b.append("")
	_bb_section(b, "Persistence")
	var save_snapshot := SaveManager.get_debug_snapshot()
	if save_snapshot.is_empty():
		b.append("  [color=gray]<no save data>[/color]")
	else:
		_bb_kv(b, "kind", str(save_snapshot.get("kind", "")))
		_bb_kv(b, "slot", str(save_snapshot.get("slot", "")))
		_bb_kv(b, "status", str(save_snapshot.get("status", "")))
		_bb_kv(b, "schema", str(save_snapshot.get("schema_version", "")))
		var reason := str(save_snapshot.get("reason", ""))
		if not reason.is_empty():
			_bb_kv(b, "reason", reason, true)

	return "\n".join(b)


func _build_events_text() -> String:
	var b := PackedStringArray()
	_bb_section(b, "Recent Events  (newest first)")
	var event_history := GameEvents.get_event_history(MAX_VISIBLE_EVENTS)
	if event_history.is_empty():
		b.append("  [color=gray]<none>[/color]")
	else:
		for i in range(event_history.size() - 1, -1, -1):
			var event_entry: Dictionary = event_history[i]
			b.append("  %s" % _format_event_entry_bb(event_entry))
	return "\n".join(b)


func _build_entities_text() -> String:
	var b := PackedStringArray()

	var player_entity := GameState.player as EntityInstance
	var all_instances: Array[EntityInstance] = []
	for entity_data in GameState.entity_instances.values():
		var entity := entity_data as EntityInstance
		if entity != null:
			all_instances.append(entity)

	# Sort: player first, then alphabetically by entity_id
	all_instances.sort_custom(func(a: EntityInstance, b_ent: EntityInstance) -> bool:
		var a_is_player := player_entity != null and a.entity_id == player_entity.entity_id
		var b_is_player := player_entity != null and b_ent.entity_id == player_entity.entity_id
		if a_is_player:
			return true
		if b_is_player:
			return false
		return a.entity_id < b_ent.entity_id
	)

	# --- Roster summary ---
	_bb_section(b, "Roster  (%d entities)" % all_instances.size())
	if all_instances.is_empty():
		b.append("  [color=gray]<none — game not started>[/color]")
	else:
		for entity in all_instances:
			var is_player := player_entity != null and entity.entity_id == player_entity.entity_id
			var tag := " [color=yellow][PLAYER][/color]" if is_player else ""
			var loc := entity.location_id if not entity.location_id.is_empty() else "?"
			var eq_count := entity.equipped.size()
			var inv_count := entity.inventory.size()
			b.append("  [color=aqua]%s[/color]%s  [color=gray]@ %s  eq=%d  inv=%d[/color]" % [
				entity.entity_id, tag, loc, eq_count, inv_count
			])

	# --- Per-entity detail blocks ---
	for entity in all_instances:
		var is_player := player_entity != null and entity.entity_id == player_entity.entity_id
		b.append("")
		var header_color := "yellow" if is_player else "aqua"
		var player_label := "  [color=yellow][PLAYER][/color]" if is_player else ""
		b.append("[b][color=%s]%s[/color][/b]%s" % [header_color, entity.entity_id, player_label])
		_bb_kv(b, "template", entity.template_id)
		_bb_kv(b, "location", entity.location_id if not entity.location_id.is_empty() else "<none>")

		# Stats — group resource pairs (health / health_max) on one line
		if not entity.stats.is_empty():
			b.append("  [color=gray]stats:[/color]")
			var stat_keys: Array = entity.stats.keys()
			stat_keys.sort()
			var shown: Dictionary = {}
			for stat_key_value in stat_keys:
				var stat_key := str(stat_key_value)
				if shown.has(stat_key):
					continue
				var cap_key := stat_key + "_max"
				if entity.stats.has(cap_key):
					var cur := entity.stats[stat_key]
					var cap := entity.stats[cap_key]
					var ratio := float(cur) / maxf(float(cap), 1.0)
					var bar_color := "green" if ratio > 0.5 else ("orange" if ratio > 0.2 else "red")
					b.append("    [color=gray]%s[/color] [color=%s]%.0f[/color][color=gray]/%.0f[/color]" % [
						stat_key, bar_color, float(cur), float(cap)
					])
					shown[stat_key] = true
					shown[cap_key] = true
				elif not stat_key.ends_with("_max"):
					b.append("    [color=gray]%s[/color] = [color=white]%s[/color]" % [
						stat_key, str(entity.stats[stat_key])
					])
					shown[stat_key] = true

		# Currencies
		if not entity.currencies.is_empty():
			b.append("  [color=gray]currencies:[/color]")
			var cur_keys: Array = entity.currencies.keys()
			cur_keys.sort()
			for cur_key_value in cur_keys:
				var cur_key := str(cur_key_value)
				b.append("    [color=gray]%s[/color] = [color=white]%s[/color]" % [
					cur_key, str(entity.currencies[cur_key_value])
				])

		# Equipped parts
		if not entity.equipped.is_empty():
			b.append("  [color=gray]equipped:[/color]")
			var slot_keys: Array = entity.equipped.keys()
			slot_keys.sort()
			for slot_value in slot_keys:
				var slot := str(slot_value)
				var part := entity.equipped.get(slot_value, null) as PartInstance
				if part != null:
					b.append("    [color=gray]%s[/color] → [color=white]%s[/color]" % [slot, part.template_id])

		# Inventory (compact — just template ids)
		if not entity.inventory.is_empty():
			var inv_parts: Array[String] = []
			for part_data in entity.inventory:
				var part := part_data as PartInstance
				if part != null:
					inv_parts.append(part.template_id)
			inv_parts.sort()
			b.append("  [color=gray]inventory (%d):[/color]" % inv_parts.size())
			for tmpl_id in inv_parts:
				b.append("    [color=gray]- [/color][color=white]%s[/color]" % tmpl_id)

		# Reputation
		if not entity.reputation.is_empty():
			b.append("  [color=gray]reputation:[/color]")
			var rep_keys: Array = entity.reputation.keys()
			rep_keys.sort()
			for rep_key_value in rep_keys:
				var rep_val := float(entity.reputation[rep_key_value])
				var rep_color := "green" if rep_val >= 0.0 else "red"
				b.append("    [color=gray]%s[/color] = [color=%s]%.0f[/color]" % [
					str(rep_key_value), rep_color, rep_val
				])

		# Flags (non-empty only)
		if not entity.flags.is_empty():
			b.append("  [color=gray]flags (%d):[/color]" % entity.flags.size())
			var flag_keys: Array = entity.flags.keys()
			flag_keys.sort()
			for flag_key_value in flag_keys:
				b.append("    [color=gray]%s[/color] = [color=white]%s[/color]" % [
					str(flag_key_value), str(entity.flags[flag_key_value])
				])

	return "\n".join(b)


# ---------------------------------------------------------------------------
# BBCode helpers
# ---------------------------------------------------------------------------

func _bb_section(b: PackedStringArray, title: String) -> void:
	b.append("[b][color=yellow]%s[/color][/b]" % title)


func _bb_kv(b: PackedStringArray, key: String, value: String, is_error: bool = false) -> void:
	var val_color := "red" if is_error else "white"
	b.append("  [color=gray]%s[/color] = [color=%s]%s[/color]" % [key, val_color, value])


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

func _format_dictionary(values: Dictionary) -> String:
	if values.is_empty():
		return "{}"
	var keys := values.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%s" % [str(key), str(values[key])])
	return "{%s}" % ", ".join(parts)


func _format_event_entry_bb(event_entry: Dictionary) -> String:
	var timestamp := str(event_entry.get("timestamp", ""))
	var signal_name := str(event_entry.get("signal_name", ""))
	var domain := str(event_entry.get("domain", ""))
	var args_text := ""
	var args_value: Variant = event_entry.get("args", [])
	if args_value is Array:
		var args: Array = args_value
		if not args.is_empty():
			var rendered_args: Array[String] = []
			for arg in args:
				rendered_args.append(str(arg))
			args_text = "  [color=gray]| %s[/color]" % " | ".join(rendered_args)
	return "[color=gray]%s[/color]  [color=aqua][%s][/color]  [color=white]%s[/color]%s" % [
		timestamp, domain, signal_name, args_text
	]


func _format_variant(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)


func _format_multiline_variant(value: Variant) -> Array[String]:
	var rendered := _format_variant(value)
	if rendered.is_empty():
		return ["<empty>"]
	var lines := rendered.split("\n", false)
	var result: Array[String] = []
	for line_value in lines:
		result.append(str(line_value))
	return result


func _extract_backend_contract_issues(recent_issues_value: Variant) -> Array[String]:
	var backend_issues: Array[String] = []
	if not recent_issues_value is Array:
		return backend_issues
	var recent_issues: Array = recent_issues_value
	for issue_value in recent_issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		var field_path := str(issue.get("field_path", ""))
		var message := str(issue.get("message", ""))
		if (
			field_path.contains("backend_class")
			or field_path.contains("action_payload.screen_id")
			or message.contains("backend_class")
			or message.contains("routed screen")
		):
			backend_issues.append(message)
	return backend_issues
