extends CanvasLayer

class_name OmniDevDebugOverlay

const PANEL_WIDTH := 560.0
const PANEL_HEIGHT := 560.0
const REFRESH_INTERVAL := 0.25
const MAX_EVENT_HISTORY := 40
const MAX_VISIBLE_EVENTS := 12

var _events_connected: bool = false
var _overlay_visible: bool = false
var _event_history: Array[String] = []

var _panel: PanelContainer = null
var _body_label: RichTextLabel = null
var _refresh_timer: Timer = null


func initialize_overlay() -> void:
	if _events_connected:
		return
	_events_connected = true
	_connect_events()
	_record_event("debug.overlay.initialized")


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


func _connect_events() -> void:
	GameEvents.mod_loaded.connect(_on_mod_loaded)
	GameEvents.all_mods_loaded.connect(_on_all_mods_loaded)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.location_changed.connect(_on_location_changed)
	GameEvents.entity_stat_changed.connect(_on_entity_stat_changed)
	GameEvents.entity_currency_changed.connect(_on_entity_currency_changed)
	GameEvents.save_completed.connect(_on_save_completed)
	GameEvents.save_failed.connect(_on_save_failed)
	GameEvents.load_completed.connect(_on_load_completed)
	GameEvents.load_failed.connect(_on_load_failed)
	GameEvents.achievement_unlocked.connect(_on_achievement_unlocked)
	GameEvents.ui_screen_pushed.connect(_on_ui_screen_pushed)
	GameEvents.ui_screen_popped.connect(_on_ui_screen_popped)


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
	lines.append("Boot")
	lines.append("  Mods loaded: %s" % str(ModLoader.is_loaded))
	lines.append("  Loaded mods: %d" % ModLoader.loaded_mods.size())
	lines.append("  ImGuiRoot present: %s" % str(has_node("/root/ImGuiRoot")))
	lines.append("  AI provider: %s" % AIManager.get_provider_type())

	if not ModLoader.loaded_mods.is_empty():
		lines.append("  Load order:")
		for manifest in ModLoader.loaded_mods:
			lines.append("    - %s (%s)" % [str(manifest.get("id", "")), str(manifest.get("version", ""))])

	lines.append("")
	lines.append("Registries")
	lines.append("  stats=%d currencies=%d" % [DataManager.get_definitions("stats").size(), DataManager.get_definitions("currencies").size()])
	lines.append("  parts=%d entities=%d locations=%d" % [DataManager.parts.size(), DataManager.entities.size(), DataManager.locations.size()])
	lines.append("  factions=%d quests=%d tasks=%d achievements=%d" % [DataManager.factions.size(), DataManager.quests.size(), DataManager.tasks.size(), DataManager.achievements.size()])

	lines.append("")
	lines.append("Runtime")
	lines.append("  screen=%s depth=%d" % [UIRouter.current_screen_id(), UIRouter.stack_depth()])
	lines.append("  location=%s day=%d tick=%d" % [GameState.current_location_id, GameState.current_day, GameState.current_tick])
	lines.append("  time_running=%s tick_rate=%.2f" % [str(TimeKeeper.is_running), TimeKeeper.tick_rate])
	lines.append("  flags=%d unlocked_achievements=%d" % [GameState.flags.size(), GameState.unlocked_achievements.size()])

	var player: EntityInstance = GameState.player
	if player:
		lines.append("  player=%s template=%s" % [player.entity_id, player.template_id])
		lines.append("  player currencies: %s" % _format_dictionary(player.currencies))
		lines.append("  player stats: %s" % _format_dictionary(player.stats))
	else:
		lines.append("  player=<none>")

	lines.append("")
	lines.append("Recent Events")
	if _event_history.is_empty():
		lines.append("  <none>")
	else:
		var start_index := maxi(_event_history.size() - MAX_VISIBLE_EVENTS, 0)
		for i in range(_event_history.size() - 1, start_index - 1, -1):
			lines.append("  %s" % _event_history[i])

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


func _record_event(message: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	_event_history.append("%s  %s" % [timestamp, message])
	if _event_history.size() > MAX_EVENT_HISTORY:
		_event_history.pop_front()


func _on_mod_loaded(mod_id: String) -> void:
	_record_event("mod.loaded %s" % mod_id)


func _on_all_mods_loaded() -> void:
	_record_event("mods.loaded_all")


func _on_game_started() -> void:
	_record_event("game.started")


func _on_location_changed(old_id: String, new_id: String) -> void:
	_record_event("game.location_changed %s -> %s" % [old_id, new_id])


func _on_entity_stat_changed(entity_id: String, stat_key: String, old_value: float, new_value: float) -> void:
	_record_event("entity.stat %s %s %s -> %s" % [entity_id, stat_key, str(old_value), str(new_value)])


func _on_entity_currency_changed(entity_id: String, currency_key: String, old_amount: float, new_amount: float) -> void:
	_record_event("entity.currency %s %s %s -> %s" % [entity_id, currency_key, str(old_amount), str(new_amount)])


func _on_save_completed(slot: int) -> void:
	_record_event("save.completed slot=%d" % slot)


func _on_save_failed(slot: int, reason: String) -> void:
	_record_event("save.failed slot=%d reason=%s" % [slot, reason])


func _on_load_completed(slot: int) -> void:
	_record_event("load.completed slot=%d" % slot)


func _on_load_failed(slot: int, reason: String) -> void:
	_record_event("load.failed slot=%d reason=%s" % [slot, reason])


func _on_achievement_unlocked(achievement_id: String) -> void:
	_record_event("achievement.unlocked %s" % achievement_id)


func _on_ui_screen_pushed(screen_id: String) -> void:
	_record_event("ui.screen_pushed %s" % screen_id)


func _on_ui_screen_popped(screen_id: String) -> void:
	_record_event("ui.screen_popped %s" % screen_id)
