extends Control

const ENCOUNTER_BACKEND := preload("res://ui/screens/backends/encounter_backend.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _round_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HeaderRow/RoundLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _player_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/PlayerScroll/PlayerHost
@onready var _center_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/CenterScroll/CenterHost
@onready var _opponent_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/OpponentScroll/OpponentHost
@onready var _action_row: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/ActionRow
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _continue_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ContinueButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniEncounterBackend = ENCOUNTER_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _opened_from_gameplay_shell: bool = false
var _player_portrait: Control = null
var _opponent_portrait: Control = null
var _last_view_model: Dictionary = {}


func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
	_opened_from_gameplay_shell = bool(params.get("opened_from_gameplay_shell", false))
	_initialize_backend()
	if is_node_ready():
		_refresh_state()


func _ready() -> void:
	_initialize_backend()
	_refresh_state()


func get_debug_snapshot() -> Dictionary:
	return _last_view_model.duplicate(true)


func _initialize_backend() -> void:
	if _backend_initialized and _pending_params.is_empty():
		return
	_backend.initialize(_pending_params)
	_pending_params = {}
	_backend_initialized = true


func _refresh_state() -> void:
	if not _backend_initialized:
		return
	var view_model := _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_title_label.text = str(view_model.get("title", "Encounter"))
	_round_label.text = "Round %d" % int(view_model.get("round", 1))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	var resolved := bool(view_model.get("resolved", false))
	_continue_button.visible = resolved
	_continue_button.text = str(view_model.get("continue_label", "Continue"))
	_action_row.visible = not resolved
	_render_portrait("player", _read_dictionary(view_model.get("player", {})))
	_render_portrait("opponent", _read_dictionary(view_model.get("opponent", {})))
	_render_center(view_model)
	_render_actions(view_model.get("actions", []))


func _render_portrait(role: String, view_model: Dictionary) -> void:
	var host := _player_host if role == "player" else _opponent_host
	var portrait := _player_portrait if role == "player" else _opponent_portrait
	if portrait == null:
		var portrait_value: Variant = ENTITY_PORTRAIT_SCENE.instantiate()
		if portrait_value is Control:
			portrait = portrait_value
			host.add_child(portrait)
			if role == "player":
				_player_portrait = portrait
			else:
				_opponent_portrait = portrait
	if portrait != null:
		portrait.call("render", view_model)


func _render_center(view_model: Dictionary) -> void:
	for child in _center_host.get_children():
		_center_host.remove_child(child)
		child.queue_free()
	var stat_lines_value: Variant = view_model.get("encounter_stats", [])
	if stat_lines_value is Array:
		var stat_lines: Array = stat_lines_value
		for stat_line_value in stat_lines:
			if not stat_line_value is Dictionary:
				continue
			var stat_bar_value: Variant = STAT_BAR_SCENE.instantiate()
			if stat_bar_value is Control:
				var stat_bar: Control = stat_bar_value
				_center_host.add_child(stat_bar)
				stat_bar.call("render", stat_line_value)
	if bool(view_model.get("resolved", false)):
		_render_resolution_summary(view_model)
	var log_title := Label.new()
	log_title.text = "Log"
	_center_host.add_child(log_title)
	var log_value: Variant = view_model.get("log", [])
	if log_value is Array:
		var log_entries: Array = log_value
		var start_index := maxi(0, log_entries.size() - 8)
		for index in range(start_index, log_entries.size()):
			var entry_value: Variant = log_entries[index]
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			var line := Label.new()
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.text = "[%d] %s" % [int(entry.get("round", 0)), str(entry.get("text", ""))]
			_center_host.add_child(line)


func _render_resolution_summary(view_model: Dictionary) -> void:
	var outcome_title := Label.new()
	outcome_title.text = "Outcome"
	_center_host.add_child(outcome_title)
	var outcome_text := Label.new()
	outcome_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_text.text = str(view_model.get("resolved_screen_text", view_model.get("status_text", "Encounter resolved.")))
	_center_host.add_child(outcome_text)

	var reward_title := Label.new()
	reward_title.text = "Rewards"
	_center_host.add_child(reward_title)
	var reward_lines_value: Variant = view_model.get("reward_lines", [])
	var reward_lines: Array = []
	if reward_lines_value is Array:
		reward_lines = reward_lines_value
	if reward_lines.is_empty():
		var empty_reward_label := Label.new()
		empty_reward_label.text = "You received no rewards."
		_center_host.add_child(empty_reward_label)
		return
	for reward_line_value in reward_lines:
		var reward_line := str(reward_line_value)
		if reward_line.is_empty():
			continue
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "You received %s." % reward_line
		_center_host.add_child(line)


func _render_actions(actions_value: Variant) -> void:
	for child in _action_row.get_children():
		_action_row.remove_child(child)
		child.queue_free()
	if not actions_value is Array:
		return
	var actions: Array = actions_value
	for action_value in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value
		var button := Button.new()
		var action_id := str(action.get("action_id", ""))
		button.text = str(action.get("label", action_id))
		button.disabled = not bool(action.get("available", false))
		button.tooltip_text = str(action.get("description", ""))
		var unavailable_text := str(action.get("tooltip", ""))
		if button.disabled and not unavailable_text.is_empty():
			button.tooltip_text = unavailable_text
		button.pressed.connect(Callable(self, "_on_action_pressed").bind(action_id))
		_action_row.add_child(button)


func _on_action_pressed(action_id: String) -> void:
	var navigation := _backend.select_action(action_id)
	_execute_navigation_action(navigation)
	_refresh_state()


func _on_continue_button_pressed() -> void:
	var navigation := _backend.continue_after_resolution()
	_execute_navigation_action(navigation)
	_refresh_state()


func _on_back_button_pressed() -> void:
	var navigation := _backend.cancel()
	if navigation.is_empty():
		_navigate_back()
		return
	_execute_navigation_action(navigation)


func _navigate_back() -> void:
	if _opened_from_gameplay_shell:
		UIRouter.close_gameplay_shell_screen()
		return
	UIRouter.pop()


func _execute_navigation_action(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	var screen_id := str(action.get("screen_id", ""))
	var params := _read_dictionary(action.get("params", {}))
	if _opened_from_gameplay_shell:
		match action_type:
			"pop":
				UIRouter.close_gameplay_shell_screen()
			"replace_all", "push":
				if not screen_id.is_empty() and UIRouter.open_screen_in_gameplay_shell(screen_id, params):
					return
				if action_type == "replace_all":
					UIRouter.replace_all(screen_id, params)
				else:
					UIRouter.push(screen_id, params)
			_:
				pass
		return
	match action_type:
		"pop":
			UIRouter.pop()
		"replace_all":
			UIRouter.replace_all(screen_id, params)
		"push":
			UIRouter.push(screen_id, params)
		_:
			pass


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
