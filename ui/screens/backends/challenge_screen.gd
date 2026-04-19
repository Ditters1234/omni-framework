extends Control

const CHALLENGE_BACKEND := preload("res://ui/screens/backends/challenge_backend.gd")
const ENTITY_PORTRAIT_SCENE := preload("res://ui/components/entity_portrait.tscn")
const STAT_BAR_SCENE := preload("res://ui/components/stat_bar.tscn")
const BACKEND_NAVIGATION_HELPER := preload("res://ui/screens/backends/backend_navigation_helper.gd")

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var _portrait_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/PortraitHost
@onready var _stat_host: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/MainContent/StatHost
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _confirm_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/ConfirmButton
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton

var _backend: OmniChallengeBackend = CHALLENGE_BACKEND.new()
var _pending_params: Dictionary = {}
var _backend_initialized: bool = false
var _portrait: Control = null
var _stat_bar: Control = null
var _requirement_label: Label = null
var _last_view_model: Dictionary = {}

func initialize(params: Dictionary = {}) -> void:
	_pending_params = params.duplicate(true)
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
	var view_model: Dictionary = _backend.build_view_model()
	_last_view_model = view_model.duplicate(true)
	_title_label.text = str(view_model.get("title", "Challenge"))
	_description_label.text = str(view_model.get("description", ""))
	_status_label.text = str(view_model.get("status_text", ""))
	_confirm_button.text = str(view_model.get("confirm_label", "Attempt"))
	_back_button.text = str(view_model.get("cancel_label", "Back"))
	_confirm_button.disabled = not bool(view_model.get("confirm_enabled", false))
	_render_portrait(_read_dictionary(view_model.get("portrait", {})))
	_render_stat_line(_read_dictionary(view_model.get("stat_line", {})), float(view_model.get("required_value", 0.0)))

func _render_portrait(view_model: Dictionary) -> void:
	if _portrait == null:
		var portrait_value: Variant = ENTITY_PORTRAIT_SCENE.instantiate()
		if portrait_value is Control:
			_portrait = portrait_value
			_portrait_host.add_child(_portrait)
	if _portrait != null:
		_portrait.call("render", view_model)

func _render_stat_line(view_model: Dictionary, required_value: float) -> void:
	if _stat_bar == null:
		var stat_bar_value: Variant = STAT_BAR_SCENE.instantiate()
		if stat_bar_value is Control:
			_stat_bar = stat_bar_value
			_stat_host.add_child(_stat_bar)
	if _requirement_label == null:
		_requirement_label = Label.new()
		_requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stat_host.add_child(_requirement_label)
	if _stat_bar != null:
		_stat_bar.call("render", view_model)
	if _requirement_label != null:
		_requirement_label.text = "Required Value: %s" % str(int(roundf(required_value)))

func _on_confirm_button_pressed() -> void:
	var action: Dictionary = _backend.confirm()
	BACKEND_NAVIGATION_HELPER.dispatch_action(action)
	_refresh_state()

func _on_back_button_pressed() -> void:
	BACKEND_NAVIGATION_HELPER.close_surface()

func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return {}
