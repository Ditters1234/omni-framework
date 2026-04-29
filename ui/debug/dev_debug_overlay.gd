extends CanvasLayer

class_name OmniDevDebugOverlay

const BACKEND_CONTRACT_REGISTRY := preload("res://systems/backend_contract_registry.gd")
const PANEL_WIDTH := 720.0
const PANEL_HEIGHT := 760.0
const PANEL_MARGIN := 16.0
const REFRESH_INTERVAL := 0.25
const MAX_VISIBLE_EVENTS := 40
const MAX_VISIBLE_ENTITIES := 30
const MAX_VISIBLE_INVENTORY_ROWS := 12

# Tab indices
const TAB_BOOT := 0
const TAB_REGISTRIES := 1
const TAB_RUNTIME := 2
const TAB_EVENTS := 3
const TAB_ENTITIES := 4
const TAB_AI_SAVE := 5

var _overlay_visible: bool = false
var _auto_refresh_enabled: bool = true

var _panel: PanelContainer = null
var _tab_container: TabContainer = null
var _tab_labels: Array[RichTextLabel] = []
var _refresh_timer: Timer = null
var _status_label: Label = null
var _auto_refresh_button: Button = null
var _event_domain_filter: OptionButton = null
var _event_search_field: LineEdit = null
var _entity_search_field: LineEdit = null
var _last_refreshed_msec: int = 0


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
	get_viewport().size_changed.connect(_update_panel_bounds)
	_update_panel_bounds()
	_set_overlay_visible(false)
	_refresh_all_tabs()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_set_overlay_visible(not _overlay_visible)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var title := Label.new()
	title.text = "Omni Dev Overlay"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status_label)

	_auto_refresh_button = Button.new()
	_auto_refresh_button.text = "Auto"
	_auto_refresh_button.toggle_mode = true
	_auto_refresh_button.button_pressed = true
	_auto_refresh_button.tooltip_text = "Toggle automatic refresh."
	_auto_refresh_button.pressed.connect(_on_auto_refresh_pressed)
	header.add_child(_auto_refresh_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.tooltip_text = "Refresh all debug panels now."
	refresh_button.pressed.connect(_refresh_all_tabs)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Hide the overlay. F3 toggles it again."
	close_button.pressed.connect(func() -> void: _set_overlay_visible(false))
	header.add_child(close_button)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	column.add_child(filter_row)

	_event_domain_filter = OptionButton.new()
	_event_domain_filter.name = "EventDomainFilter"
	_event_domain_filter.tooltip_text = "Filter the Events tab by GameEvents domain."
	_event_domain_filter.add_item("all domains")
	for domain in ["boot", "data", "ui", "time", "quest", "task", "entity", "location", "economy", "ai", "save", "audio"]:
		_event_domain_filter.add_item(domain)
	_event_domain_filter.item_selected.connect(func(_index: int) -> void: _refresh_tab(TAB_EVENTS))
	filter_row.add_child(_event_domain_filter)

	_event_search_field = LineEdit.new()
	_event_search_field.name = "EventSearchField"
	_event_search_field.placeholder_text = "event search"
	_event_search_field.tooltip_text = "Filter visible events by signal, domain, or argument text."
	_event_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_search_field.text_changed.connect(func(_new_text: String) -> void: _refresh_tab(TAB_EVENTS))
	filter_row.add_child(_event_search_field)

	_entity_search_field = LineEdit.new()
	_entity_search_field.name = "EntitySearchField"
	_entity_search_field.placeholder_text = "entity search"
	_entity_search_field.tooltip_text = "Filter the Entities tab by entity id, template id, or location."
	_entity_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entity_search_field.text_changed.connect(func(_new_text: String) -> void: _refresh_tab(TAB_ENTITIES))
	filter_row.add_child(_entity_search_field)

	_tab_container = TabContainer.new()
	_tab_container.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, PANEL_HEIGHT - 48.0)
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tab_container)

	var tab_names := ["Boot", "Registries", "Runtime", "Events", "Entities", "AI / Save"]
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
	if p_is_visible:
		_update_panel_bounds()
	_refresh_all_tabs()


func _refresh_active_tab() -> void:
	if not _overlay_visible or not _auto_refresh_enabled or _tab_container == null:
		return
	_refresh_tab(_tab_container.current_tab)


func _refresh_all_tabs() -> void:
	_update_status_label()
	for i in range(_tab_labels.size()):
		_refresh_tab(i)
	_last_refreshed_msec = Time.get_ticks_msec()


func _refresh_tab(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= _tab_labels.size():
		return
	_update_status_label()
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
		TAB_AI_SAVE:
			lbl.text = _build_ai_save_text()
	_last_refreshed_msec = Time.get_ticks_msec()


func get_debug_snapshot() -> Dictionary:
	return {
		"visible": _overlay_visible,
		"auto_refresh_enabled": _auto_refresh_enabled,
		"current_tab": -1 if _tab_container == null else _tab_container.current_tab,
		"event_domain_filter": _get_selected_event_domain(),
		"event_search": "" if _event_search_field == null else _event_search_field.text,
		"entity_search": "" if _entity_search_field == null else _entity_search_field.text,
		"last_refreshed_msec": _last_refreshed_msec,
	}


func _on_auto_refresh_pressed() -> void:
	_auto_refresh_enabled = _auto_refresh_button == null or _auto_refresh_button.button_pressed
	_refresh_all_tabs()


func _update_status_label() -> void:
	if _status_label == null:
		return
	var mod_snapshot := ModLoader.get_debug_snapshot()
	var data_snapshot := DataManager.get_debug_snapshot()
	var problem_count := int(mod_snapshot.get("error_count", 0)) + int(data_snapshot.get("issue_count", 0))
	var status_color := "OK" if problem_count == 0 else "%d issues" % problem_count
	_status_label.text = "%s | F3 | %s" % [
		status_color,
		"live" if _auto_refresh_enabled else "paused"
	]


func _update_panel_bounds() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(PANEL_WIDTH, maxf(viewport_size.x - PANEL_MARGIN * 2.0, 360.0))
	var height := minf(PANEL_HEIGHT, maxf(viewport_size.y - PANEL_MARGIN * 2.0, 360.0))
	_panel.offset_left = -width - PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN
	_panel.offset_right = -PANEL_MARGIN
	_panel.offset_bottom = height + PANEL_MARGIN
	if _tab_container != null:
		_tab_container.custom_minimum_size = Vector2(maxf(width - 24.0, 320.0), maxf(height - 92.0, 240.0))


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
	_bb_kv(b, "validation", "%sms" % str(mod_snapshot.get("data_validation_ms", 0)))
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
	var count_keys := [
		"stats",
		"currencies",
		"parts",
		"entities",
		"locations",
		"factions",
		"quests",
		"tasks",
		"recipes",
		"achievements",
		"ai_personas",
		"ai_templates",
	]
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

	var recent_files_value: Variant = data_snapshot.get("recent_files", [])
	if recent_files_value is Array:
		var recent_files: Array = recent_files_value
		if not recent_files.is_empty():
			b.append("")
			_bb_section(b, "Recent Files")
			for file_value in recent_files:
				if not file_value is Dictionary:
					continue
				var file_entry: Dictionary = file_value
				var status := str(file_entry.get("status", ""))
				var status_color := "red" if status == "invalid" else ("gray" if status == "missing" else "green")
				b.append("  [color=%s]%s[/color] [color=gray]%s[/color]" % [
					status_color,
					status,
					str(file_entry.get("file_path", ""))
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


func _build_ai_save_text() -> String:
	var b := PackedStringArray()

	_bb_section(b, "AI Manager")
	var ai_snapshot := AIManager.get_debug_snapshot()
	var ai_available := bool(ai_snapshot.get("available", false))
	_bb_kv(b, "provider", str(ai_snapshot.get("provider_name", AIManager.get_provider_name())))
	_bb_kv(b, "enabled", str(bool(ai_snapshot.get("enabled", false))))
	_bb_kv(b, "available", str(ai_available), not ai_available)
	_bb_kv(b, "provider node", str(bool(ai_snapshot.get("has_provider_node", false))))
	_bb_kv(b, "active requests", str(int(ai_snapshot.get("active_request_count", 0))))
	_bb_kv(b, "request count", str(int(ai_snapshot.get("request_count", 0))))
	var ai_last_error := str(ai_snapshot.get("last_error", ""))
	if not ai_last_error.is_empty():
		_bb_kv(b, "last error", ai_last_error, true)

	var provider_debug_value: Variant = ai_snapshot.get("provider_debug", {})
	if provider_debug_value is Dictionary:
		var provider_debug: Dictionary = provider_debug_value
		if not provider_debug.is_empty():
			b.append("")
			_bb_section(b, "Provider")
			for line in _format_dictionary_lines(provider_debug):
				b.append("  %s" % line)

	var recent_requests_value: Variant = ai_snapshot.get("recent_requests", [])
	if recent_requests_value is Array:
		var recent_requests: Array = recent_requests_value
		if not recent_requests.is_empty():
			b.append("")
			_bb_section(b, "Recent AI Requests")
			var start_index := maxi(recent_requests.size() - 8, 0)
			for request_index in range(recent_requests.size() - 1, start_index - 1, -1):
				var request_value: Variant = recent_requests[request_index]
				if not request_value is Dictionary:
					continue
				var request: Dictionary = request_value
				var status := str(request.get("status", ""))
				var status_color := "green" if status == "completed" else ("red" if status == "failed" else "gray")
				b.append("  [color=%s]%s[/color] [color=aqua]%s[/color] [color=gray]%s[/color]" % [
					status_color,
					status,
					str(request.get("request_id", "")),
					str(request.get("prompt_preview", ""))
				])
				var request_error := str(request.get("error", ""))
				if not request_error.is_empty():
					b.append("    [color=red]%s[/color]" % request_error)

	b.append("")
	_bb_section(b, "Save Manager")
	var save_snapshot := SaveManager.get_debug_snapshot()
	if save_snapshot.is_empty():
		b.append("  [color=gray]<no save operation recorded>[/color]")
	else:
		for line in _format_dictionary_lines(save_snapshot):
			b.append("  %s" % line)

	var validation_value: Variant = save_snapshot.get("validation_issues", [])
	if validation_value is Array:
		var validation_issues: Array = validation_value
		if not validation_issues.is_empty():
			b.append("")
			_bb_section(b, "Save Validation")
			for issue_value in validation_issues:
				b.append("  [color=red]- %s[/color]" % str(issue_value))

	b.append("")
	_bb_section(b, "Clock")
	var time_snapshot := TimeKeeper.get_debug_snapshot()
	for line in _format_dictionary_lines(time_snapshot):
		b.append("  %s" % line)

	return "\n".join(b)


func _build_events_text() -> String:
	var b := PackedStringArray()
	var selected_domain := _get_selected_event_domain()
	var search_text := _get_event_search_text()
	_bb_section(b, "Recent Events  (newest first)")
	_bb_kv(b, "domain", "all" if selected_domain.is_empty() else selected_domain)
	_bb_kv(b, "search", "<empty>" if search_text.is_empty() else search_text)
	var event_history := GameEvents.get_event_history(200, selected_domain)
	var visible_events: Array[Dictionary] = []
	for event_entry_value in event_history:
		if not event_entry_value is Dictionary:
			continue
		var event_entry: Dictionary = event_entry_value
		if not _event_matches_search(event_entry, search_text):
			continue
		visible_events.append(event_entry)
	if visible_events.is_empty():
		b.append("  [color=gray]<none>[/color]")
	else:
		var rendered_count := mini(visible_events.size(), MAX_VISIBLE_EVENTS)
		_bb_kv(b, "showing", "%d/%d" % [rendered_count, visible_events.size()])
		for i in range(visible_events.size() - 1, maxi(visible_events.size() - rendered_count, 0) - 1, -1):
			var event_entry: Dictionary = visible_events[i]
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
					var cur: float = float(entity.stats[stat_key])
					var cap: float = float(entity.stats[cap_key])
					var ratio: float = cur / maxf(cap, 1.0)
					var bar_color: String = "green" if ratio > 0.5 else ("orange" if ratio > 0.2 else "red")
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


func _format_dictionary_lines(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if values.is_empty():
		return result
	var keys := values.keys()
	keys.sort()
	for key_value in keys:
		var key := str(key_value)
		var value: Variant = values.get(key_value)
		result.append("[color=gray]%s[/color] = [color=white]%s[/color]" % [
			key,
			_format_variant(value)
		])
	return result


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


func _get_selected_event_domain() -> String:
	if _event_domain_filter == null:
		return ""
	var selected_index := _event_domain_filter.selected
	if selected_index <= 0:
		return ""
	return _event_domain_filter.get_item_text(selected_index)


func _get_event_search_text() -> String:
	if _event_search_field == null:
		return ""
	return _event_search_field.text.strip_edges().to_lower()


func _get_entity_search_text() -> String:
	if _entity_search_field == null:
		return ""
	return _entity_search_field.text.strip_edges().to_lower()


func _event_matches_search(event_entry: Dictionary, search_text: String) -> bool:
	if search_text.is_empty():
		return true
	var haystack := "%s %s %s" % [
		str(event_entry.get("timestamp", "")),
		str(event_entry.get("domain", "")),
		str(event_entry.get("signal_name", "")),
	]
	var args_value: Variant = event_entry.get("args", [])
	if args_value is Array:
		for arg in args_value:
			haystack += " " + str(arg)
	return haystack.to_lower().contains(search_text)


func _entity_matches_search(entity: EntityInstance, search_text: String) -> bool:
	if search_text.is_empty():
		return true
	var haystack := "%s %s %s" % [
		entity.entity_id,
		entity.template_id,
		entity.location_id,
	]
	return haystack.to_lower().contains(search_text)


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
