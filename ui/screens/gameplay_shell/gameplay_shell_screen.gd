extends Control

const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_LOCATION_VIEW := "location_view"

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _location_label: Label = $MarginContainer/VBoxContainer/LocationLabel
@onready var _tick_label: Label = $MarginContainer/VBoxContainer/TickLabel
@onready var _currencies_label: Label = $MarginContainer/VBoxContainer/CurrenciesLabel
@onready var _stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var _equipped_label: Label = $MarginContainer/VBoxContainer/EquippedLabel
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


func initialize(_params: Dictionary = {}) -> void:
	_refresh()


func _ready() -> void:
	GameEvents.tick_advanced.connect(_on_tick_advanced)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.location_changed.connect(_on_location_changed)
	GameEvents.entity_stat_changed.connect(_on_entity_stat_changed)
	GameEvents.entity_currency_changed.connect(_on_entity_currency_changed)
	GameEvents.part_equipped.connect(_on_part_equipped)
	GameEvents.part_unequipped.connect(_on_part_unequipped)
	_refresh()


func _refresh() -> void:
	_title_label.text = "Gameplay Shell"
	if GameState.player == null:
		_location_label.text = "No active player."
		_tick_label.text = ""
		_currencies_label.text = ""
		_stats_label.text = ""
		_equipped_label.text = ""
		return

	var player: EntityInstance = GameState.player
	_location_label.text = "Location: %s" % GameState.current_location_id
	_tick_label.text = "Day %d, Tick %d" % [GameState.current_day, GameState.current_tick]
	_currencies_label.text = "Currencies: %s" % _format_dictionary(player.currencies)
	_stats_label.text = "Stats: %s" % _format_dictionary(player.stats)
	_equipped_label.text = "Equipped: %s" % _format_equipped(player)


func _format_dictionary(values: Dictionary) -> String:
	if values.is_empty():
		return "{}"
	var keys := values.keys()
	keys.sort()
	var items: Array[String] = []
	for key in keys:
		items.append("%s=%s" % [str(key), str(values[key])])
	return "{%s}" % ", ".join(items)


func _format_equipped(player: EntityInstance) -> String:
	if player.equipped.is_empty():
		return "{}"
	var slots := player.equipped.keys()
	slots.sort()
	var items: Array[String] = []
	for slot in slots:
		var part: PartInstance = player.equipped[slot]
		var template := part.get_template()
		var display_name := str(template.get("display_name", part.template_id))
		items.append("%s=%s" % [str(slot), display_name])
	return "{%s}" % ", ".join(items)


func _on_advance_tick_button_pressed() -> void:
	TimeKeeper.advance_tick()
	_status_label.text = "Advanced one tick."


func _on_save_button_pressed() -> void:
	SaveManager.save_game(1)
	_status_label.text = "Saved to slot 1."


func _on_explore_location_button_pressed() -> void:
	UIRouter.push(SCREEN_LOCATION_VIEW)


func _on_main_menu_button_pressed() -> void:
	UIRouter.replace_all(SCREEN_MAIN_MENU)


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_day_advanced(_day: int) -> void:
	_refresh()


func _on_location_changed(_old_id: String, _new_id: String) -> void:
	_refresh()


func _on_entity_stat_changed(entity_id: String, _stat_key: String, _old_value: float, _new_value: float) -> void:
	if GameState.player and entity_id == GameState.player.entity_id:
		_refresh()


func _on_entity_currency_changed(entity_id: String, _currency_key: String, _old_amount: float, _new_amount: float) -> void:
	if GameState.player and entity_id == GameState.player.entity_id:
		_refresh()


func _on_part_equipped(entity_id: String, _part_id: String, _slot: String) -> void:
	if GameState.player and entity_id == GameState.player.entity_id:
		_refresh()


func _on_part_unequipped(entity_id: String, _part_id: String, _slot: String) -> void:
	if GameState.player and entity_id == GameState.player.entity_id:
		_refresh()
