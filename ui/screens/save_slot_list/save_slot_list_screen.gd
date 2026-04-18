extends Control

const SCREEN_LOCATION_VIEW := "location_view"
const SCREEN_MAIN_MENU := "main_menu"
const MODE_LOAD := "load"
const MODE_SAVE := "save"

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SubtitleLabel
@onready var _slots_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/ScrollContainer/SlotsContainer
@onready var _back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonRow/BackButton
@onready var _status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel

var _mode: String = MODE_LOAD
var _close_on_save: bool = true


func initialize(params: Dictionary = {}) -> void:
	var mode_value: Variant = params.get("mode", MODE_LOAD)
	_mode = _normalize_mode(str(mode_value))
	var close_on_save_value: Variant = params.get("close_on_save", true)
	_close_on_save = bool(close_on_save_value)
	_refresh()


func _ready() -> void:
	_refresh()


func on_route_revealed() -> void:
	_refresh()


func _refresh() -> void:
	_title_label.text = "Load Game" if _mode == MODE_LOAD else "Save Game"
	_subtitle_label.text = (
		"Choose a save slot to restore the current session."
		if _mode == MODE_LOAD
		else "Choose a save slot for the current runtime state."
	)
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()

	for slot in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var slot_info := SaveManager.get_slot_info(slot)
		var slot_entry := _build_slot_entry(slot, slot_info)
		_slots_container.add_child(slot_entry)

	_back_button.text = "Back"
	if _mode == MODE_LOAD and _first_available_slot() < 0:
		_status_label.text = "No save slots are currently available."
	elif _mode == MODE_SAVE:
		_status_label.text = "Saving will overwrite any existing slot you choose."
	else:
		_status_label.text = "Select a slot."


func _build_slot_entry(slot: int, slot_info: Dictionary) -> Control:
	var is_occupied := not slot_info.is_empty()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var slot_button := Button.new()
	slot_button.text = _get_slot_button_label(slot, is_occupied)
	slot_button.disabled = _mode == MODE_LOAD and not is_occupied
	slot_button.pressed.connect(func() -> void:
		_on_slot_selected(slot)
	)
	content.add_child(slot_button)

	var details_label := Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.text = _build_slot_summary(slot, slot_info)
	content.add_child(details_label)

	return panel


func _get_slot_button_label(slot: int, is_occupied: bool) -> String:
	if _mode == MODE_SAVE:
		if is_occupied:
			return "Overwrite Slot %d" % slot
		return "Save to Slot %d" % slot
	if is_occupied:
		return "Load Slot %d" % slot
	return "Slot %d Empty" % slot


func _build_slot_summary(slot: int, slot_info: Dictionary) -> String:
	if slot_info.is_empty():
		return "Slot %d is empty." % slot

	var display_name := str(slot_info.get("display_name", "Saved Game"))
	var day := int(slot_info.get("day", 0))
	var tick := int(slot_info.get("tick", 0))
	var updated_at := str(slot_info.get("updated_at", ""))
	var metadata_lines: Array[String] = [
		display_name,
		"Day %d, Tick %d" % [day, tick],
	]
	if not updated_at.is_empty():
		metadata_lines.append("Updated: %s" % updated_at)
	return "\n".join(metadata_lines)


func _normalize_mode(mode: String) -> String:
	if mode == MODE_SAVE:
		return MODE_SAVE
	return MODE_LOAD


func _first_available_slot() -> int:
	for slot in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		if SaveManager.slot_exists(slot):
			return slot
	return -1


func _on_slot_selected(slot: int) -> void:
	if _mode == MODE_SAVE:
		_save_to_slot(slot)
		return
	_load_from_slot(slot)


func _save_to_slot(slot: int) -> void:
	SaveManager.save_game(slot)
	var summary: Dictionary = SaveManager.last_operation_summary
	if str(summary.get("status", "")) != "ok":
		_status_label.text = str(summary.get("reason", "Unable to save slot %d." % slot))
		return
	_status_label.text = "Saved to slot %d." % slot
	_refresh()
	if _close_on_save and UIRouter.stack_depth() > 1:
		UIRouter.pop()


func _load_from_slot(slot: int) -> void:
	if not SaveManager.load_game(slot):
		var summary: Dictionary = SaveManager.last_operation_summary
		_status_label.text = str(summary.get("reason", "Unable to load slot %d." % slot))
		return
	_status_label.text = "Loaded slot %d." % slot
	UIRouter.replace_all(SCREEN_LOCATION_VIEW, {
		"location_id": GameState.current_location_id,
	})


func _on_back_button_pressed() -> void:
	if UIRouter.stack_depth() > 1:
		UIRouter.pop()
		return
	UIRouter.replace_all(SCREEN_MAIN_MENU)
