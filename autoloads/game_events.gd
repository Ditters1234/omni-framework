## GameEvents — Global signal bus.
## All cross-system communication flows through here.
## No system should hold a direct reference to another system.
@warning_ignore_start("unused_signal")
extends Node

class_name OmniGameEvents

const MAX_EVENT_HISTORY := 200
const SIGNAL_CATALOG := {
	"boot": [
		{"name": "mod_loaded", "args": ["mod_id"]},
		{"name": "mod_load_error", "args": ["mod_id", "message"]},
		{"name": "all_mods_loaded", "args": []},
	],
	"time": [
		{"name": "tick_advanced", "args": ["tick"]},
		{"name": "day_advanced", "args": ["day"]},
	],
	"game_state": [
		{"name": "game_started", "args": []},
		{"name": "game_paused", "args": []},
		{"name": "game_resumed", "args": []},
		{"name": "game_over", "args": []},
		{"name": "location_changed", "args": ["old_id", "new_id"]},
		{"name": "player_stat_changed", "args": ["stat_key", "old_value", "new_value"]},
		{"name": "entity_stat_changed", "args": ["entity_id", "stat_key", "old_value", "new_value"]},
		{"name": "entity_reputation_changed", "args": ["entity_id", "faction_id", "old_value", "new_value"]},
		{"name": "flag_changed", "args": ["entity_id", "flag_id", "value"]},
	],
	"inventory": [
		{"name": "part_acquired", "args": ["entity_id", "part_id"]},
		{"name": "part_removed", "args": ["entity_id", "part_id"]},
		{"name": "part_equipped", "args": ["entity_id", "part_id", "slot"]},
		{"name": "part_unequipped", "args": ["entity_id", "part_id", "slot"]},
		{"name": "part_custom_value_changed", "args": ["entity_id", "part_id", "field_id", "value"]},
	],
	"economy": [
		{"name": "currency_changed", "args": ["currency_key", "old_amount", "new_amount"], "deprecated": true},
		{"name": "entity_currency_changed", "args": ["entity_id", "currency_key", "old_amount", "new_amount"]},
		{"name": "transaction_completed", "args": ["buyer_id", "seller_id", "part_id", "price"]},
	],
	"quests_tasks": [
		{"name": "quest_started", "args": ["quest_id"]},
		{"name": "quest_stage_advanced", "args": ["quest_id", "stage_index"]},
		{"name": "quest_completed", "args": ["quest_id"]},
		{"name": "quest_failed", "args": ["quest_id"]},
		{"name": "task_started", "args": ["task_id", "entity_id"]},
		{"name": "task_completed", "args": ["task_id", "entity_id"]},
		{"name": "dialogue_started", "args": ["entity_id", "dialogue_resource"]},
		{"name": "dialogue_ended", "args": ["entity_id", "dialogue_resource"]},
	],
	"achievements": [
		{"name": "achievement_unlocked", "args": ["achievement_id", "unlock_vfx"]},
	],
	"ui": [
		{"name": "screen_pushed", "args": ["screen_id"], "deprecated": true},
		{"name": "screen_popped", "args": ["screen_id"], "deprecated": true},
		{"name": "notification_requested", "args": ["message", "level"], "deprecated": true},
		{"name": "ui_screen_pushed", "args": ["screen_id"]},
		{"name": "ui_screen_popped", "args": ["screen_id"]},
		{"name": "ui_notification_requested", "args": ["message", "level"]},
	],
	"ai": [
		{"name": "ai_response_received", "args": ["context_id", "response"]},
		{"name": "ai_token_received", "args": ["context_id", "token"]},
		{"name": "ai_error", "args": ["context_id", "error"]},
	],
	"save_load": [
		{"name": "save_started", "args": ["slot"]},
		{"name": "save_completed", "args": ["slot"]},
		{"name": "load_started", "args": ["slot"]},
		{"name": "load_completed", "args": ["slot"]},
		{"name": "save_failed", "args": ["slot", "reason"]},
		{"name": "load_failed", "args": ["slot", "reason"]},
	],
}

var _initialized: bool = false
var _signal_metadata: Dictionary = {}
var _signal_names: Array[String] = []
var _event_history: Array[Dictionary] = []
var _event_sequence: int = 0

# ---------------------------------------------------------------------------
# Mod / Data loading
# ---------------------------------------------------------------------------
signal mod_loaded(mod_id: String)
signal mod_load_error(mod_id: String, message: String)
signal all_mods_loaded()

# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------
signal tick_advanced(tick: int)
signal day_advanced(day: int)

# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over()

signal location_changed(old_id: String, new_id: String)
signal player_stat_changed(stat_key: String, old_value: float, new_value: float)
signal entity_stat_changed(entity_id: String, stat_key: String, old_value: float, new_value: float)
signal entity_reputation_changed(entity_id: String, faction_id: String, old_value: float, new_value: float)
signal flag_changed(entity_id: String, flag_id: String, value: Variant)

# ---------------------------------------------------------------------------
# Inventory / Parts
# ---------------------------------------------------------------------------
signal part_acquired(entity_id: String, part_id: String)
signal part_removed(entity_id: String, part_id: String)
signal part_equipped(entity_id: String, part_id: String, slot: String)
signal part_unequipped(entity_id: String, part_id: String, slot: String)
signal part_custom_value_changed(entity_id: String, part_id: String, field_id: String, value: Variant)

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------
signal currency_changed(currency_key: String, old_amount: float, new_amount: float)
signal entity_currency_changed(entity_id: String, currency_key: String, old_amount: float, new_amount: float)
signal transaction_completed(buyer_id: String, seller_id: String, part_id: String, price: float)

# ---------------------------------------------------------------------------
# Quests / Tasks
# ---------------------------------------------------------------------------
signal quest_started(quest_id: String)
signal quest_stage_advanced(quest_id: String, stage_index: int)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal task_started(task_id: String, entity_id: String)
signal task_completed(task_id: String, entity_id: String)
signal dialogue_started(entity_id: String, dialogue_resource: String)
signal dialogue_ended(entity_id: String, dialogue_resource: String)

# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------
signal achievement_unlocked(achievement_id: String, unlock_vfx: String)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
signal screen_pushed(screen_id: String)
signal screen_popped(screen_id: String)
signal notification_requested(message: String, level: String)
signal ui_screen_pushed(screen_id: String)
signal ui_screen_popped(screen_id: String)
signal ui_notification_requested(message: String, level: String)

# ---------------------------------------------------------------------------
# AI
# ---------------------------------------------------------------------------
signal ai_response_received(context_id: String, response: String)
signal ai_token_received(context_id: String, token: String)
signal ai_error(context_id: String, error: String)

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------
signal save_started(slot: int)
signal save_completed(slot: int)
signal load_started(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)


func _enter_tree() -> void:
	if _initialized:
		return
	_initialized = true
	_build_signal_metadata()
	_connect_debug_recorders()
	_validate_signal_catalog()


func get_registered_signal_names(domain: String = "", include_deprecated: bool = true) -> Array[String]:
	var result: Array[String] = []
	for signal_name in _signal_names:
		var metadata := get_signal_metadata(signal_name)
		if metadata.is_empty():
			continue
		if not domain.is_empty() and str(metadata.get("domain", "")) != domain:
			continue
		if not include_deprecated and bool(metadata.get("deprecated", false)):
			continue
		result.append(signal_name)
	return result


func get_signal_metadata(signal_name: String) -> Dictionary:
	var metadata_value: Variant = _signal_metadata.get(signal_name, {})
	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value
		return metadata.duplicate(true)
	return {}


func get_signal_domain(signal_name: String) -> String:
	var metadata := get_signal_metadata(signal_name)
	return str(metadata.get("domain", ""))


func get_signal_arg_names(signal_name: String) -> Array[String]:
	var metadata := get_signal_metadata(signal_name)
	return _variant_to_string_array(metadata.get("args", []))


func is_deprecated_signal(signal_name: String) -> bool:
	var metadata := get_signal_metadata(signal_name)
	return bool(metadata.get("deprecated", false))


func emit_dynamic(signal_name: String, args: Array = []) -> bool:
	if signal_name.is_empty():
		push_warning("GameEvents: emit_dynamic called with an empty signal name.")
		return false
	if not _signal_metadata.has(signal_name):
		push_warning("GameEvents: unknown signal '%s'." % signal_name)
		return false
	var expected_args := get_signal_arg_names(signal_name)
	if expected_args.size() != args.size():
		push_warning(
			"GameEvents: signal '%s' expected %d args but received %d." % [
				signal_name,
				expected_args.size(),
				args.size()
			]
		)
		return false
	callv("emit_signal", [signal_name] + args)
	return true


func get_event_history(limit: int = 50, domain: String = "", signal_name: String = "") -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event_entry in _event_history:
		if not event_entry is Dictionary:
			continue
		var entry: Dictionary = event_entry
		if not domain.is_empty() and str(entry.get("domain", "")) != domain:
			continue
		if not signal_name.is_empty() and str(entry.get("signal_name", "")) != signal_name:
			continue
		filtered.append(entry.duplicate(true))

	if limit <= 0 or filtered.size() <= limit:
		return filtered
	return filtered.slice(filtered.size() - limit, filtered.size())


func clear_event_history() -> void:
	_event_history.clear()
	_event_sequence = 0


func get_debug_snapshot() -> Dictionary:
	var counts_by_domain: Dictionary = {}
	for signal_name in _signal_names:
		var domain := get_signal_domain(signal_name)
		var current_count := int(counts_by_domain.get(domain, 0))
		counts_by_domain[domain] = current_count + 1
	return {
		"signal_count": _signal_names.size(),
		"history_count": _event_history.size(),
		"domains": counts_by_domain,
		"deprecated_signal_count": _signal_names.size() - get_registered_signal_names("", false).size(),
	}


func _build_signal_metadata() -> void:
	_signal_metadata.clear()
	_signal_names.clear()
	for domain_value in SIGNAL_CATALOG.keys():
		var domain := str(domain_value)
		var entries_value: Variant = SIGNAL_CATALOG.get(domain_value, [])
		if not entries_value is Array:
			continue
		var entries: Array = entries_value
		for entry_value in entries:
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			var signal_name := str(entry.get("name", ""))
			if signal_name.is_empty():
				continue
			var metadata := entry.duplicate(true)
			metadata["domain"] = domain
			_signal_metadata[signal_name] = metadata
			_signal_names.append(signal_name)
	_signal_names.sort()


func _connect_debug_recorders() -> void:
	for signal_name in _signal_names:
		var arg_count := get_signal_arg_names(signal_name).size()
		match arg_count:
			0:
				_connect_signal_recorder(signal_name, Callable(self, "_record_signal_0").bind(signal_name))
			1:
				_connect_signal_recorder(signal_name, Callable(self, "_record_signal_1").bind(signal_name))
			2:
				_connect_signal_recorder(signal_name, Callable(self, "_record_signal_2").bind(signal_name))
			3:
				_connect_signal_recorder(signal_name, Callable(self, "_record_signal_3").bind(signal_name))
			4:
				_connect_signal_recorder(signal_name, Callable(self, "_record_signal_4").bind(signal_name))
			_:
				push_warning("GameEvents: signal '%s' has unsupported recorder arity %d." % [signal_name, arg_count])


func _connect_signal_recorder(signal_name: String, recorder: Callable) -> void:
	if is_connected(signal_name, recorder):
		return
	connect(signal_name, recorder)


func _validate_signal_catalog() -> void:
	var declared_signals := _get_declared_signal_names()
	for signal_name in _signal_names:
		if not has_signal(signal_name):
			push_error("GameEvents: SIGNAL_CATALOG references missing runtime signal '%s'." % signal_name)
			continue
		if not declared_signals.has(signal_name):
			push_error("GameEvents: SIGNAL_CATALOG references undeclared signal '%s'." % signal_name)
	for signal_name in declared_signals:
		if not _signal_metadata.has(signal_name):
			push_error("GameEvents: declared signal '%s' is missing from SIGNAL_CATALOG." % signal_name)


func _get_declared_signal_names() -> Array[String]:
	var result: Array[String] = []
	var script_value: Variant = get_script()
	if not script_value is Script:
		return result
	var script_resource: Script = script_value
	for signal_info_value in script_resource.get_script_signal_list():
		if not signal_info_value is Dictionary:
			continue
		var signal_info: Dictionary = signal_info_value
		var signal_name := str(signal_info.get("name", ""))
		if signal_name.is_empty():
			continue
		result.append(signal_name)
	result.sort()
	return result


func _record_signal_0(signal_name: String) -> void:
	_append_event(signal_name, [])


func _record_signal_1(arg0: Variant, signal_name: String) -> void:
	_append_event(signal_name, [arg0])


func _record_signal_2(arg0: Variant, arg1: Variant, signal_name: String) -> void:
	_append_event(signal_name, [arg0, arg1])


func _record_signal_3(arg0: Variant, arg1: Variant, arg2: Variant, signal_name: String) -> void:
	_append_event(signal_name, [arg0, arg1, arg2])


func _record_signal_4(arg0: Variant, arg1: Variant, arg2: Variant, arg3: Variant, signal_name: String) -> void:
	_append_event(signal_name, [arg0, arg1, arg2, arg3])


func _append_event(signal_name: String, args: Array) -> void:
	_event_sequence += 1
	var sanitized_args: Array = []
	for arg in args:
		sanitized_args.append(_sanitize_event_value(arg))
	_event_history.append({
		"sequence": _event_sequence,
		"signal_name": signal_name,
		"domain": get_signal_domain(signal_name),
		"args": sanitized_args,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"deprecated": is_deprecated_signal(signal_name),
	})
	if _event_history.size() > MAX_EVENT_HISTORY:
		_event_history.pop_front()


func _sanitize_event_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	return value


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value
	for entry in values:
		result.append(str(entry))
	return result
