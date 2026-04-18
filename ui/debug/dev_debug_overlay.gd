extends CanvasLayer

class_name OmniDevDebugOverlay

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const PANEL_WIDTH := 560.0
const PANEL_HEIGHT := 560.0
const REFRESH_INTERVAL := 0.25
const MAX_VISIBLE_EVENTS := 12

var _overlay_visible: bool = false

var _panel: PanelContainer = null
var _body_label: RichTextLabel = null
var _refresh_timer: Timer = null


func initialize_overlay() -> void:
	return


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_INTERVAL
	_refresh_timer.one_shot = false
	_refresh_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_timer.timeout.connect(_refresh_text)
	add_child(_refresh_timer)
	_refresh_timer.start()
	_set_overlay_visible(false)
	_refresh_text()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_set_overlay_visible(not _overlay_visible)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -PANEL_WIDTH - 16.0
	_panel.offset_top = 16.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = PANEL_HEIGHT
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	var title := Label.new()
	title.text = "Omni Dev Overlay"
	column.add_child(title)

	var hint := Label.new()
	hint.text = "F3 toggles this panel."
	column.add_child(hint)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = false
	_body_label.fit_content = false
	_body_label.scroll_following = false
	_body_label.custom_minimum_size = Vector2(PANEL_WIDTH - 44.0, PANEL_HEIGHT - 84.0)
	column.add_child(_body_label)


func _set_overlay_visible(is_visible: bool) -> void:
	_overlay_visible = is_visible
	visible = is_visible
	if _panel:
		_panel.visible = is_visible
	_refresh_text()


func _refresh_text() -> void:
	if _body_label == null:
		return

	var lines: Array[String] = []
	var mod_snapshot := ModLoader.get_debug_snapshot()
	lines.append("Boot")
	lines.append("  Loader status: %s loaded=%s" % [
		str(mod_snapshot.get("status", "")),
		str(mod_snapshot.get("is_loaded", false))
	])
	lines.append("  Loaded mods: %d discovered=%d" % [
		int(mod_snapshot.get("loaded_mod_count", 0)),
		int(mod_snapshot.get("discovered_mod_count", 0))
	])
	lines.append("  Phase timings: additions=%sms patches=%sms hooks=%sms total=%sms" % [
		str(mod_snapshot.get("phase_one_ms", 0)),
		str(mod_snapshot.get("phase_two_ms", 0)),
		str(mod_snapshot.get("script_hook_preload_ms", 0)),
		str(mod_snapshot.get("total_ms", 0))
	])
	lines.append("  Load report errors: %d fatal=%d nonfatal=%d" % [
		int(mod_snapshot.get("error_count", 0)),
		int(mod_snapshot.get("fatal_error_count", 0)),
		int(mod_snapshot.get("nonfatal_error_count", 0))
	])
	lines.append("  ImGuiRoot present: %s" % str(has_node("/root/ImGuiRoot")))
	var ai_snapshot := AIManager.get_debug_snapshot()
	lines.append("  AI provider: %s enabled=%s available=%s" % [
		AIManager.get_provider_name(),
		str(bool(ai_snapshot.get("enabled", false))),
		str(bool(ai_snapshot.get("available", false)))
	])
	var ai_last_error := str(ai_snapshot.get("last_error", ""))
	if not ai_last_error.is_empty():
		lines.append("  AI last error: %s" % ai_last_error)
	var ai_last_request_value: Variant = ai_snapshot.get("last_request", {})
	if ai_last_request_value is Dictionary:
		var ai_last_request: Dictionary = ai_last_request_value
		if not ai_last_request.is_empty():
			lines.append("  AI last request: %s status=%s" % [
				str(ai_last_request.get("request_id", "")),
				str(ai_last_request.get("status", ""))
			])
	var events_snapshot := GameEvents.get_debug_snapshot()
	lines.append("  GameEvents signals=%d history=%d" % [
		int(events_snapshot.get("signal_count", 0)),
		int(events_snapshot.get("history_count", 0))
	])

	if not ModLoader.loaded_mods.is_empty():
		lines.append("  Load order:")
		for manifest in ModLoader.loaded_mods:
			lines.append("    - %s (%s)" % [str(manifest.get("id", "")), str(manifest.get("version", ""))])

	var registry_counts := DataManager.get_registry_counts()
	var data_snapshot := DataManager.get_debug_snapshot()
	lines.append("")
	lines.append("Registries")
	lines.append("  DataManager: %s loaded=%s issues=%d files=%d invalid=%d" % [
		str(data_snapshot.get("status", "")),
		str(data_snapshot.get("is_loaded", false)),
		int(data_snapshot.get("issue_count", 0)),
		int(data_snapshot.get("processed_file_count", 0)),
		int(data_snapshot.get("invalid_file_count", 0))
	])
	lines.append("  stats=%d currencies=%d" % [int(registry_counts.get("stats", 0)), int(registry_counts.get("currencies", 0))])
	lines.append("  parts=%d entities=%d locations=%d" % [int(registry_counts.get("parts", 0)), int(registry_counts.get("entities", 0)), int(registry_counts.get("locations", 0))])
	lines.append("  factions=%d quests=%d tasks=%d achievements=%d" % [int(registry_counts.get("factions", 0)), int(registry_counts.get("quests", 0)), int(registry_counts.get("tasks", 0)), int(registry_counts.get("achievements", 0))])
	var recent_issues_value: Variant = data_snapshot.get("recent_issues", [])
	if recent_issues_value is Array:
		var recent_issues: Array = recent_issues_value
		if not recent_issues.is_empty():
			lines.append("  Recent data issues:")
			for issue_value in recent_issues:
				if not issue_value is Dictionary:
					continue
				var issue: Dictionary = issue_value
				lines.append("    - [%s] %s" % [str(issue.get("phase", "")), str(issue.get("message", ""))])

	lines.append("")
	lines.append("Runtime")
	var router_snapshot := UIRouter.get_debug_snapshot()
	lines.append("  router screen=%s depth=%d container_valid=%s" % [
		str(router_snapshot.get("current_screen_id", "")),
		int(router_snapshot.get("stack_depth", 0)),
		str(router_snapshot.get("container_valid", false))
	])
	var router_stack_value: Variant = router_snapshot.get("stack", [])
	if router_stack_value is Array:
		var router_stack: Array = router_stack_value
		if not router_stack.is_empty():
			lines.append("  stack:")
			for stack_entry_value in router_stack:
				if not stack_entry_value is Dictionary:
					continue
				var stack_entry: Dictionary = stack_entry_value
				lines.append("    - %s visible=%s" % [
					str(stack_entry.get("screen_id", "")),
					str(stack_entry.get("visible", false))
				])
	var router_errors_value: Variant = router_snapshot.get("recent_errors", [])
	if router_errors_value is Array:
		var router_errors: Array = router_errors_value
		if not router_errors.is_empty():
			lines.append("  router errors:")
			for error_value in router_errors:
				lines.append("    - %s" % str(error_value))
	lines.append("  current params=%s" % _format_variant(router_snapshot.get("current_screen_params", {})))
	var current_screen_snapshot := UIRouter.get_current_screen_debug_snapshot()
	if not current_screen_snapshot.is_empty():
		lines.append("  current screen snapshot:")
		for snapshot_line in _format_multiline_variant(current_screen_snapshot):
			lines.append("    %s" % snapshot_line)
	var backend_classes := BACKEND_CONTRACT_REGISTRY.get_registered_backend_classes()
	if backend_classes.is_empty():
		lines.append("  backend contracts=<none>")
	else:
		lines.append("  backend contracts=%s" % ", ".join(backend_classes))
	var backend_contract_issues := _extract_backend_contract_issues(recent_issues_value)
	if backend_contract_issues.is_empty():
		lines.append("  backend contract issues: none")
	else:
		lines.append("  backend contract issues:")
		for issue_text in backend_contract_issues:
			lines.append("    - %s" % issue_text)
	lines.append("  location=%s day=%d tick=%d" % [GameState.current_location_id, GameState.current_day, GameState.current_tick])
	var time_snapshot := TimeKeeper.get_debug_snapshot()
	lines.append("  time_running=%s tick_rate=%.2f tick_in_day=%d/%d" % [
		str(time_snapshot.get("is_running", false)),
		float(time_snapshot.get("tick_rate", 0.0)),
		int(time_snapshot.get("ticks_into_day", 0)),
		int(time_snapshot.get("ticks_per_day", 0))
	])
	lines.append("  time_consistent=%s active_tasks=%d" % [
		str(time_snapshot.get("is_time_consistent", false)),
		int(time_snapshot.get("active_task_count", 0))
	])
	lines.append("  flags=%d unlocked_achievements=%d" % [GameState.flags.size(), GameState.unlocked_achievements.size()])

	var player: EntityInstance = GameState.player
	if player:
		lines.append("  player=%s template=%s" % [player.entity_id, player.template_id])
		lines.append("  player currencies: %s" % _format_dictionary(player.currencies))
		lines.append("  player stats: %s" % _format_dictionary(player.stats))
	else:
		lines.append("  player=<none>")

	var save_snapshot := SaveManager.get_debug_snapshot()
	if not save_snapshot.is_empty():
		lines.append("")
		lines.append("Persistence")
		lines.append("  %s slot=%s status=%s schema=%s" % [
			str(save_snapshot.get("kind", "")),
			str(save_snapshot.get("slot", "")),
			str(save_snapshot.get("status", "")),
			str(save_snapshot.get("schema_version", ""))
		])
		var reason := str(save_snapshot.get("reason", ""))
		if not reason.is_empty():
			lines.append("  reason=%s" % reason)

	lines.append("")
	lines.append("Recent Events")
	var event_history := GameEvents.get_event_history(MAX_VISIBLE_EVENTS)
	if event_history.is_empty():
		lines.append("  <none>")
	else:
		for i in range(event_history.size() - 1, -1, -1):
			var event_entry: Dictionary = event_history[i]
			lines.append("  %s" % _format_event_entry(event_entry))

	_body_label.text = "\n".join(lines)


func _format_dictionary(values: Dictionary) -> String:
	if values.is_empty():
		return "{}"
	var keys := values.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%s" % [str(key), str(values[key])])
	return "{%s}" % ", ".join(parts)


func _format_event_entry(event_entry: Dictionary) -> String:
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
			args_text = " " + " | ".join(rendered_args)
	return "%s [%s] %s%s" % [timestamp, domain, signal_name, args_text]


func _format_variant(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return str(value)


func _format_multiline_variant(value: Variant) -> Array[String]:
	var rendered := _format_variant(value)
	if rendered.is_empty():
		return ["<empty>"]
	return rendered.split("\n", false)


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
