extends Control

const SCREEN_GAMEPLAY_SHELL := "gameplay_shell"
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
var _pending_delete_slot: int = -1


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
		"Choose a save slot to restore the current session. Autosave is engine-owned and appears first when available."
		if _mode == MODE_LOAD
		else "Choose a destination for the current runtime state. Autosave is the quick-recovery slot used by the gameplay shell."
	)
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()

	for slot in SaveManager.get_visible_slots():
		var slot_info := SaveManager.get_slot_info(slot)
		var slot_entry := _build_slot_entry(slot, slot_info)
		_slots_container.add_child(slot_entry)

	_back_button.text = "Back"
	if _pending_delete_slot >= 1:
		_status_label.text = "Press Delete again on slot %d to permanently remove it." % _pending_delete_slot
	elif _mode == MODE_LOAD and _first_available_slot() < 0:
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
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(button_row)

	var slot_button := Button.new()
	slot_button.text = _get_slot_button_label(slot, is_occupied)
	slot_button.disabled = _mode == MODE_LOAD and not is_occupied
	slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_button.pressed.connect(func() -> void:
		_pending_delete_slot = -1
		_on_slot_selected(slot)
	)
	button_row.add_child(slot_button)

	if is_occupied:
		var delete_button := Button.new()
		delete_button.text = _get_delete_button_label(slot)
		delete_button.theme_type_variation = "FlatButton"
		delete_button.pressed.connect(func() -> void:
			_on_delete_pressed(slot)
		)
		button_row.add_child(delete_button)

	var details_label := Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_label.text = _build_slot_summary(slot, slot_info)
	content.add_child(details_label)

	return panel


func _get_slot_button_label(slot: int, is_occupied: bool) -> String:
	if slot == SaveManager.AUTOSAVE_SLOT:
		if _mode == MODE_SAVE:
			return "Write Autosave"
		if is_occupied:
			return "Load Autosave"
		return "Autosave Empty"
	if _mode == MODE_SAVE:
		if is_occupied:
			return "Overwrite Slot %d" % slot
		return "Save to Slot %d" % slot
	if is_occupied:
		return "Load Slot %d" % slot
	return "Slot %d Empty" % slot


func _build_slot_summary(slot: int, slot_info: Dictionary) -> String:
	if slot_info.is_empty():
		if slot == SaveManager.AUTOSAVE_SLOT:
			return "Autosave is empty. Use Quick Autosave from the gameplay shell or write one here."
		return "Slot %d is empty and ready for a new save." % slot

	var display_name := str(slot_info.get("display_name", "Saved Game"))
	var day := int(slot_info.get("day", 0))
	var tick := int(slot_info.get("tick", 0))
	var playtime_seconds := int(slot_info.get("playtime_seconds", 0))
	var created_at := str(slot_info.get("created_at", ""))
	var updated_at := str(slot_info.get("updated_at", ""))
	var location_name := str(slot_info.get("location_name", ""))
	var slot_label := str(slot_info.get("slot_label", SaveManager.get_slot_label(slot)))
	var metadata_lines: Array[String] = [
		"%s - %s" % [slot_label, display_name],
		"Day %d, Tick %d" % [day, tick],
	]
	if not location_name.is_empty():
		metadata_lines.append("Location: %s" % location_name)
	if playtime_seconds > 0:
		metadata_lines.append("Playtime: %s" % _format_playtime(playtime_seconds))
	if not created_at.is_empty():
		metadata_lines.append("Created: %s" % created_at)
	if not updated_at.is_empty():
		metadata_lines.append("Updated: %s" % updated_at)
	return "\n".join(metadata_lines)


func _get_delete_button_label(slot: int) -> String:
	if _pending_delete_slot == slot:
		return "Confirm Delete"
	if slot == SaveManager.AUTOSAVE_SLOT:
		return "Delete Autosave"
	return "Delete"


func _normalize_mode(mode: String) -> String:
	if mode == MODE_SAVE:
		return MODE_SAVE
	return MODE_LOAD


func _first_available_slot() -> int:
	return SaveManager.get_most_recent_loadable_slot()


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
	_refresh()
	_status_label.text = "Saved to %s." % SaveManager.get_slot_label(slot)
	if _close_on_save and UIRouter.stack_depth() > 1:
		UIRouter.pop()


func _load_from_slot(slot: int) -> void:
	if not SaveManager.load_game(slot):
		var summary: Dictionary = SaveManager.last_operation_summary
		_status_label.text = str(summary.get("reason", "Unable to load slot %d." % slot))
		return
	_status_label.text = "Loaded %s." % SaveManager.get_slot_label(slot)
	UIRouter.replace_all(SCREEN_GAMEPLAY_SHELL)


func _on_delete_pressed(slot: int) -> void:
	if _pending_delete_slot != slot:
		_pending_delete_slot = slot
		_refresh()
		return
	if not SaveManager.delete_game(slot):
		var summary: Dictionary = SaveManager.last_operation_summary
		_pending_delete_slot = -1
		_refresh()
		_status_label.text = str(summary.get("reason", "Unable to delete slot %d." % slot))
		return
	_pending_delete_slot = -1
	_refresh()
	_status_label.text = "Deleted %s." % SaveManager.get_slot_label(slot)


func _format_playtime(playtime_seconds: int) -> String:
	var total_seconds := maxi(playtime_seconds, 0)
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


func _on_back_button_pressed() -> void:
	if UIRouter.stack_depth() > 1:
		UIRouter.pop()
		return
	UIRouter.replace_all(SCREEN_MAIN_MENU)
